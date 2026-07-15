import Foundation
import UIKit

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: NexusTab = .home
    @Published var screenMode: ScreenMode = .translate
    @Published var settings: AppSettings
    @Published var latestScreenText = ""
    @Published var screenResult = "等待读取屏幕内容"
    @Published var screenStatus = "未启动"
    @Published var isProcessingScreen = false
    @Published var memories: [ScreenSnapshot] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var isChatting = false
    @Published var pendingCommand: DeviceCommand?
    @Published var alertMessage: String?

    let overlayState: OverlayState
    let pipManager: PiPManager
    let remoteClient = RemoteClient()

    private let aiClient = AIClient()
    private let memoryStore = MemoryStore()
    private let loopback = LoopbackServer()
    private var screenTask: Task<Void, Never>?
    private var lastProcessedText = ""

    init() {
        let overlay = OverlayState()
        overlayState = overlay
        pipManager = PiPManager(overlayState: overlay)
        settings = SettingsStore.load()
        loopback.onText = { [weak self] text in
            Task { @MainActor in
                self?.ingestScreenText(text)
            }
        }
        loopback.start()
        Task {
            memories = await memoryStore.load()
        }
    }

    deinit {
        loopback.stop()
    }

    var hasAPIKey: Bool {
        !SecureStore.get("api-key").isEmpty
    }

    func saveSettings(apiKey: String? = nil) {
        SettingsStore.save(settings)
        if let apiKey, !apiKey.isEmpty {
            SecureStore.set(apiKey, for: "api-key")
        }
        alertMessage = "设置已保存"
    }

    func ingestScreenText(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 1 else { return }
        latestScreenText = cleaned
        screenStatus = "已读取当前页面"
        overlayState.title = screenMode.title
        if settings.autoProcess, cleaned != lastProcessedText {
            screenTask?.cancel()
            screenTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                await self?.processCurrentScreen()
            }
        }
    }

    func processCurrentScreen() async {
        let source = latestScreenText
        guard !source.isEmpty, !isProcessingScreen else { return }
        isProcessingScreen = true
        screenStatus = "AI 正在\(screenMode.title)"
        overlayState.isWorking = true
        overlayState.title = "正在\(screenMode.title)"
        defer {
            isProcessingScreen = false
            overlayState.isWorking = false
        }
        do {
            let messages = [
                ChatMessage(role: .system, content: screenMode.systemPrompt),
                ChatMessage(role: .user, content: source)
            ]
            let result = try await aiClient.complete(
                settings: settings,
                apiKey: SecureStore.get("api-key"),
                messages: messages
            )
            guard source == latestScreenText else { return }
            lastProcessedText = source
            screenResult = result
            screenStatus = "\(screenMode.title)完成"
            overlayState.title = "NEXUS · \(screenMode.title)"
            overlayState.text = result
            if settings.rememberScreens {
                let snapshot = ScreenSnapshot(sourceText: source, resultText: result, mode: screenMode)
                memories = await memoryStore.append(snapshot)
            }
        } catch {
            let message = error.localizedDescription
            screenResult = message
            screenStatus = "处理失败"
            overlayState.title = "需要处理"
            overlayState.text = message
        }
    }

    func askAI(_ text: String) async {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !isChatting else { return }
        let user = ChatMessage(role: .user, content: cleaned)
        chatMessages.append(user)
        isChatting = true
        defer { isChatting = false }

        let memoryContext = memories.prefix(8).map {
            "[\($0.mode.title)] \($0.sourceText.prefix(220)) -> \($0.resultText.prefix(220))"
        }.joined(separator: "\n")
        let system = ChatMessage(
            role: .system,
            content: "你是 NEXUS 中文手机助手。结合屏幕记忆回答，但不要假装已经执行操作。回答直接、简洁。\n屏幕记忆：\n\(memoryContext)"
        )
        do {
            let recent = Array(chatMessages.suffix(20))
            let result = try await aiClient.complete(
                settings: settings,
                apiKey: SecureStore.get("api-key"),
                messages: [system] + recent,
                temperature: 0.35
            )
            chatMessages.append(ChatMessage(role: .assistant, content: result))
        } catch {
            chatMessages.append(ChatMessage(role: .assistant, content: error.localizedDescription))
        }
    }

    func proposeExecution(_ text: String) async {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !isChatting else { return }
        isChatting = true
        defer { isChatting = false }

        let prompt = """
        将用户命令转换为一个 JSON 对象，只允许以下 action：
        open_settings、open_url、copy_text、remote_lock、remote_play_pause、none。
        格式：{"action":"...","value":"可为空","confirmation":"执行前显示的中文确认语"}
        不要输出 Markdown。无法安全执行时使用 none，并解释原因。
        用户命令：\(cleaned)
        """
        do {
            let result = try await aiClient.complete(
                settings: settings,
                apiKey: SecureStore.get("api-key"),
                messages: [ChatMessage(role: .user, content: prompt)],
                temperature: 0
            )
            guard let data = extractJSONObject(from: result),
                  let command = try? JSONDecoder().decode(DeviceCommand.self, from: data) else {
                alertMessage = "AI没有生成可执行指令"
                return
            }
            if command.action == "none" {
                alertMessage = command.confirmation
            } else {
                pendingCommand = command
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func executePendingCommand() async {
        guard let command = pendingCommand else { return }
        pendingCommand = nil
        switch command.action {
        case "open_settings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        case "open_url":
            if let raw = command.value,
               let url = URL(string: raw),
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                await UIApplication.shared.open(url)
            } else {
                alertMessage = "链接格式不安全，已取消"
            }
        case "copy_text":
            UIPasteboard.general.string = command.value ?? ""
            alertMessage = "已复制"
        case "remote_lock", "remote_play_pause":
            let action = command.action == "remote_lock" ? "lock" : "play_pause"
            do {
                try await remoteClient.sendAction(
                    host: settings.remoteHost,
                    token: settings.remoteToken,
                    action: action,
                    value: nil
                )
                alertMessage = "电脑指令已发送"
            } catch {
                alertMessage = "电脑未连接"
            }
        default:
            alertMessage = "该指令不在安全执行范围内"
        }
    }

    func clearMemory() async {
        await memoryStore.clear()
        memories = []
    }

    private func extractJSONObject(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        return String(text[start...end]).data(using: .utf8)
    }
}
