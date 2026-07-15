import SwiftUI

struct RemoteView: View {
    @EnvironmentObject private var state: AppState
    @State private var clipboardText = ""
    @State private var lastDrag = CGSize.zero

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                connectionPanel
                motionPanel
                controlsPanel
                clipboardPanel
            }
            .padding(16)
        }
        .navigationTitle("空间遥控")
        .navigationBarTitleDisplayMode(.inline)
        .nexusScreen()
    }

    private var connectionPanel: some View {
        NexusPanel {
            VStack(spacing: 12) {
                HStack {
                    SectionHeader(title: "Windows 连接")
                    StatusPill(title: state.remoteClient.status, active: state.remoteClient.status == "电脑在线" || state.remoteClient.isMotionActive)
                }
                TextField("电脑 IP，例如 192.168.1.8", text: $state.settings.remoteHost)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                SecureField("配对码", text: $state.settings.remoteToken)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("保存") { state.saveSettings() }
                        .buttonStyle(.bordered)
                    Button("测试连接") {
                        state.saveSettings()
                        Task { await state.remoteClient.test(host: state.settings.remoteHost, token: state.settings.remoteToken) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var motionPanel: some View {
        NexusPanel {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("体感鼠标")
                            .font(.headline)
                        Text("转动手机即可移动电脑光标")
                            .font(.caption)
                            .foregroundStyle(NexusTheme.muted)
                    }
                    Spacer()
                    Button {
                        if state.remoteClient.isMotionActive {
                            state.remoteClient.stopMotion()
                        } else {
                            state.remoteClient.startMotion(host: state.settings.remoteHost, token: state.settings.remoteToken)
                        }
                    } label: {
                        Image(systemName: state.remoteClient.isMotionActive ? "stop.fill" : "gyroscope")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(state.remoteClient.isMotionActive ? NexusTheme.warning : NexusTheme.primary)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }

                ZStack {
                    NexusTheme.surfaceRaised
                    VStack(spacing: 8) {
                        Image(systemName: "hand.draw")
                            .font(.largeTitle)
                            .foregroundStyle(NexusTheme.primary)
                        Text("也可以在这里滑动控制")
                            .font(.caption)
                            .foregroundStyle(NexusTheme.muted)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let dx = value.translation.width - lastDrag.width
                            let dy = value.translation.height - lastDrag.height
                            lastDrag = value.translation
                            state.remoteClient.sendPointerDelta(
                                host: state.settings.remoteHost,
                                token: state.settings.remoteToken,
                                dx: dx * 1.8,
                                dy: dy * 1.8
                            )
                        }
                        .onEnded { _ in lastDrag = .zero }
                )
            }
        }
    }

    private var controlsPanel: some View {
        NexusPanel {
            VStack(spacing: 12) {
                SectionHeader(title: "电脑控制")
                HStack(spacing: 10) {
                    remoteButton("播放", icon: "playpause", action: "play_pause")
                    remoteButton("锁定", icon: "lock.fill", action: "lock")
                    remoteButton("桌面", icon: "rectangle.on.rectangle", action: "show_desktop")
                }
            }
        }
    }

    private var clipboardPanel: some View {
        NexusPanel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "发送到电脑剪贴板")
                TextField("输入要发送的文字", text: $clipboardText, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                Button("发送文字") {
                    Task {
                        try? await state.remoteClient.sendAction(
                            host: state.settings.remoteHost,
                            token: state.settings.remoteToken,
                            action: "clipboard",
                            value: clipboardText
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(clipboardText.isEmpty)
            }
        }
    }

    private func remoteButton(_ title: String, icon: String, action: String) -> some View {
        Button {
            Task {
                try? await state.remoteClient.sendAction(
                    host: state.settings.remoteHost,
                    token: state.settings.remoteToken,
                    action: action,
                    value: nil
                )
            }
        } label: {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(NexusTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}
