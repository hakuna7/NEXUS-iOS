import Foundation

enum NexusTab: String, CaseIterable, Identifiable {
    case home
    case lens
    case ai
    case vision
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "总览"
        case .lens: "看屏"
        case .ai: "AI"
        case .vision: "视觉"
        case .more: "更多"
        }
    }

    var icon: String {
        switch self {
        case .home: "square.grid.2x2"
        case .lens: "viewfinder"
        case .ai: "sparkles"
        case .vision: "camera.viewfinder"
        case .more: "slider.horizontal.3"
        }
    }
}

enum ScreenMode: String, CaseIterable, Codable, Identifiable {
    case translate
    case explain
    case summarize
    case risk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .translate: "翻译"
        case .explain: "解释"
        case .summarize: "总结"
        case .risk: "风险"
        }
    }

    var systemPrompt: String {
        switch self {
        case .translate:
            "将屏幕文字准确翻译成简体中文。只输出译文，保留段落，不添加解释。"
        case .explain:
            "你是手机操作助手。用简短中文解释当前页面是什么、重要选项含义和建议的下一步。不要声称已经点击。"
        case .summarize:
            "用简体中文提炼当前屏幕内容，最多五条，优先保留时间、金额、地址和待办事项。"
        case .risk:
            "检查当前屏幕是否包含诈骗、钓鱼、恶意下载、诱导转账或危险授权。给出低/中/高风险和具体理由。"
        }
    }
}

struct ScreenSnapshot: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    let sourceText: String
    let resultText: String
    let mode: ScreenMode

    init(id: UUID = UUID(), createdAt: Date = Date(), sourceText: String, resultText: String, mode: ScreenMode) {
        self.id = id
        self.createdAt = createdAt
        self.sourceText = sourceText
        self.resultText = resultText
        self.mode = mode
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    let content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct DeviceCommand: Identifiable, Codable {
    let id: UUID
    let action: String
    let value: String?
    let confirmation: String

    init(id: UUID = UUID(), action: String, value: String?, confirmation: String) {
        self.id = id
        self.action = action
        self.value = value
        self.confirmation = confirmation
    }

    enum CodingKeys: String, CodingKey {
        case action, value, confirmation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        action = try container.decode(String.self, forKey: .action)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        confirmation = try container.decode(String.self, forKey: .confirmation)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encode(confirmation, forKey: .confirmation)
    }
}

struct AppSettings: Codable, Equatable {
    var endpoint = "https://lucen.cc/v1"
    var model = "gpt-5.4"
    var autoProcess = true
    var rememberScreens = true
    var remoteHost = ""
    var remoteToken = ""
}

struct OCRPayload: Codable {
    let text: String
    let timestamp: TimeInterval
}

struct RemoteAction: Codable {
    let token: String
    let action: String
    let value: String?
}
