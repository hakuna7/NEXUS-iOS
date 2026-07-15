import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                systemPanel
                quickActions
                recentMemory
            }
            .padding(16)
        }
        .navigationTitle("NEXUS")
        .navigationBarTitleDisplayMode(.large)
        .nexusScreen()
    }

    private var header: some View {
        NexusPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("视觉智能控制中心")
                            .font(.title3.weight(.bold))
                        Text("读懂屏幕，记住内容，连接设备")
                            .font(.subheadline)
                            .foregroundStyle(NexusTheme.muted)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(NexusTheme.line, lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: state.hasAPIKey ? 0.86 : 0.34)
                            .stroke(NexusTheme.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "sparkles")
                            .foregroundStyle(NexusTheme.primary)
                    }
                    .frame(width: 54, height: 54)
                }
                HStack(spacing: 8) {
                    StatusPill(title: state.hasAPIKey ? "AI 已配置" : "等待配置", active: state.hasAPIKey)
                    StatusPill(title: "本地 OCR", active: true)
                    StatusPill(title: "记忆 \(state.memories.count)", active: !state.memories.isEmpty)
                }
            }
        }
    }

    private var systemPanel: some View {
        NexusPanel {
            VStack(spacing: 14) {
                SectionHeader(title: "实时状态", trailing: state.screenStatus)
                HStack(spacing: 12) {
                    metric(title: "屏幕文字", value: state.latestScreenText.isEmpty ? "待机" : "已读取", icon: "text.viewfinder")
                    metric(title: "悬浮窗", value: state.pipManager.isActive ? "运行" : "关闭", icon: "pip")
                    metric(title: "电脑", value: state.remoteClient.isMotionActive ? "已控" : "离线", icon: "desktopcomputer")
                }
            }
        }
    }

    private var quickActions: some View {
        NexusPanel {
            VStack(spacing: 16) {
                SectionHeader(title: "快捷入口")
                Button { state.selectedTab = .lens } label: {
                    FeatureRow(icon: "character.bubble", title: "实时看屏翻译", detail: "读取其他 App 页面并显示悬浮译文")
                }
                Divider().overlay(NexusTheme.line)
                Button { state.selectedTab = .vision } label: {
                    FeatureRow(icon: "camera.metering.matrix", title: "AR 视觉扫描", detail: "识别文字、物体类别和中心距离", color: NexusTheme.secondary)
                }
                Divider().overlay(NexusTheme.line)
                Button { state.selectedTab = .ai } label: {
                    FeatureRow(icon: "brain.head.profile", title: "AI 长期记忆", detail: "结合已看页面继续提问，聊天与执行分开", color: NexusTheme.warning)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var recentMemory: some View {
        NexusPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "最近记忆", trailing: "本地保存")
                if let memory = state.memories.first {
                    Text(memory.sourceText)
                        .font(.subheadline)
                        .lineLimit(3)
                    Text(memory.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(NexusTheme.muted)
                } else {
                    Text("启动看屏后，识别过的内容会出现在这里。")
                        .font(.subheadline)
                        .foregroundStyle(NexusTheme.muted)
                }
            }
        }
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(NexusTheme.primary)
                .frame(height: 22)
            Text(value)
                .font(.subheadline.weight(.bold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(NexusTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(NexusTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
