import ReplayKit
import SwiftUI

struct LiveLensView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                modePicker
                controlPanel
                sourcePanel
                resultPanel
            }
            .padding(16)
        }
        .navigationTitle("实时看屏")
        .navigationBarTitleDisplayMode(.large)
        .nexusHomeButton { state.selectedTab = .home }
        .onChange(of: state.screenMode) { _, mode in
            state.overlayState.title = "NEXUS · \(mode.title)"
        }
        .nexusScreen()
    }

    private var modePicker: some View {
        Picker("模式", selection: $state.screenMode) {
            ForEach(ScreenMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var controlPanel: some View {
        NexusPanel {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("屏幕读取")
                            .font(.headline)
                        Text("先开启悬浮窗，再启动系统屏幕广播")
                            .font(.caption)
                            .foregroundStyle(NexusTheme.muted)
                    }
                    Spacer()
                    StatusPill(title: state.pipManager.isActive ? "悬浮中" : "待启动", active: state.pipManager.isActive)
                }

                HStack(spacing: 12) {
                    Button {
                        state.pipManager.isActive ? state.pipManager.stop() : state.pipManager.start()
                    } label: {
                        Label(state.pipManager.isActive ? "关闭悬浮窗" : "开启悬浮窗", systemImage: "pip")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(NexusTheme.primary)
                            .foregroundStyle(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    BroadcastPicker()
                        .frame(width: 52, height: 48)
                        .background(NexusTheme.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                PiPAnchorView(manager: state.pipManager)
                    .frame(height: 1)
                    .opacity(0.01)

                Toggle("页面变化后自动处理", isOn: $state.settings.autoProcess)
                    .onChange(of: state.settings.autoProcess) { _, _ in state.saveSettings() }
            }
        }
    }

    private var sourcePanel: some View {
        NexusPanel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "当前页面", trailing: state.screenStatus)
                Text(state.latestScreenText.isEmpty ? "尚未收到屏幕文字。点击右侧录屏按钮，在系统弹窗中选择 NEXUS 屏幕识别。" : state.latestScreenText)
                    .font(.subheadline)
                    .foregroundStyle(state.latestScreenText.isEmpty ? NexusTheme.muted : .white)
                    .lineLimit(9)
                    .textSelection(.enabled)
            }
        }
    }

    private var resultPanel: some View {
        NexusPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: state.screenMode.title + "结果")
                Text(state.screenResult)
                    .font(.body)
                    .textSelection(.enabled)
                Button {
                    Task { await state.processCurrentScreen() }
                } label: {
                    HStack {
                        if state.isProcessingScreen { ProgressView().tint(.black) }
                        Text(state.isProcessingScreen ? "处理中" : "立即处理当前页面")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(NexusTheme.secondary)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .disabled(state.latestScreenText.isEmpty || state.isProcessingScreen)
            }
        }
    }
}

private struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 52, height: 48))
        picker.preferredExtension = "com.hakuna7.NEXUS.Broadcast"
        picker.showsMicrophoneButton = false
        if let button = picker.subviews.compactMap({ $0 as? UIButton }).first {
            button.tintColor = UIColor(NexusTheme.primary)
            button.imageView?.contentMode = .scaleAspectFit
        }
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
