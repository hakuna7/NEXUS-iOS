import SwiftUI

struct MemoryView: View {
    @EnvironmentObject private var state: AppState
    @State private var search = ""
    @State private var showClear = false

    private var filtered: [ScreenSnapshot] {
        guard !search.isEmpty else { return state.memories }
        return state.memories.filter {
            $0.sourceText.localizedCaseInsensitiveContains(search) ||
            $0.resultText.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            Section {
                Toggle("自动保存识别文字", isOn: $state.settings.rememberScreens)
                    .onChange(of: state.settings.rememberScreens) { _, _ in state.saveSettings() }
            } footer: {
                Text("仅保存识别出的文字和AI结果，不保存原始屏幕图片。")
            }
            Section("时间轴") {
                if filtered.isEmpty {
                    Text("没有找到屏幕记忆")
                        .foregroundStyle(NexusTheme.muted)
                }
                ForEach(filtered) { item in
                    NavigationLink {
                        MemoryDetailView(item: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(item.mode.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(NexusTheme.primary)
                                Spacer()
                                Text(item.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(NexusTheme.muted)
                            }
                            Text(item.sourceText)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                    }
                }
            }
            Section {
                Button("清除全部屏幕记忆", role: .destructive) { showClear = true }
            }
        }
        .searchable(text: $search, prompt: "搜索看过的文字")
        .scrollContentBackground(.hidden)
        .navigationTitle("屏幕记忆")
        .navigationBarTitleDisplayMode(.inline)
        .nexusBackButton()
        .nexusScreen()
        .confirmationDialog("确定清除全部屏幕记忆？", isPresented: $showClear) {
            Button("清除", role: .destructive) { Task { await state.clearMemory() } }
            Button("取消", role: .cancel) {}
        }
    }
}

private struct MemoryDetailView: View {
    let item: ScreenSnapshot

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NexusPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "原始文字", trailing: item.mode.title)
                        Text(item.sourceText).textSelection(.enabled)
                    }
                }
                NexusPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "处理结果")
                        Text(item.resultText).textSelection(.enabled)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(item.createdAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .nexusBackButton()
        .nexusScreen()
    }
}
