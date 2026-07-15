import SwiftUI

struct AIConsoleView: View {
    @EnvironmentObject private var state: AppState
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            contextBar
            messages
            composer
        }
        .navigationTitle("AI 控制台")
        .navigationBarTitleDisplayMode(.inline)
        .nexusScreen()
    }

    private var contextBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "memorychip")
                .foregroundStyle(NexusTheme.primary)
            Text("已连接 \(state.memories.count) 条屏幕记忆")
                .font(.caption.weight(.semibold))
            Spacer()
            StatusPill(title: state.hasAPIKey ? state.settings.model : "未配置", active: state.hasAPIKey)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(NexusTheme.surface)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if state.chatMessages.isEmpty {
                        emptyState
                    }
                    ForEach(state.chatMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if state.isChatting {
                        HStack {
                            ProgressView()
                            Text("AI正在处理")
                                .font(.caption)
                                .foregroundStyle(NexusTheme.muted)
                            Spacer()
                        }
                    }
                }
                .padding(16)
            }
            .onChange(of: state.chatMessages.count) { _, _ in
                if let id = state.chatMessages.last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        NexusPanel {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundStyle(NexusTheme.primary)
                Text("聊天和执行已经分开")
                    .font(.headline)
                Text("“问AI”只回答问题；“生成操作”会先显示确认内容，只有你确认后才执行允许的操作。")
                    .font(.subheadline)
                    .foregroundStyle(NexusTheme.muted)
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            TextField("输入问题或操作要求", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .padding(12)
                .background(NexusTheme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            HStack(spacing: 10) {
                Button {
                    let text = input
                    input = ""
                    Task { await state.askAI(text) }
                } label: {
                    Label("问 AI", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(NexusTheme.primary)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                Button {
                    let text = input
                    Task { await state.proposeExecution(text) }
                } label: {
                    Label("生成操作", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(NexusTheme.warning)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
            .font(.subheadline.weight(.semibold))
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isChatting)
        }
        .padding(12)
        .background(NexusTheme.surface)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            Text(message.content)
                .font(.subheadline)
                .padding(12)
                .background(message.role == .user ? NexusTheme.primary : NexusTheme.surfaceRaised)
                .foregroundStyle(message.role == .user ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .textSelection(.enabled)
            if message.role != .user { Spacer(minLength: 48) }
        }
    }
}
