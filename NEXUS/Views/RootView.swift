import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        TabView(selection: $state.selectedTab) {
            NavigationStack { DashboardView() }
                .tabItem { Label(NexusTab.home.title, systemImage: NexusTab.home.icon) }
                .tag(NexusTab.home)

            NavigationStack { LiveLensView() }
                .tabItem { Label(NexusTab.lens.title, systemImage: NexusTab.lens.icon) }
                .tag(NexusTab.lens)

            NavigationStack { AIConsoleView() }
                .tabItem { Label(NexusTab.ai.title, systemImage: NexusTab.ai.icon) }
                .tag(NexusTab.ai)

            NavigationStack { ARScannerScreen() }
                .tabItem { Label(NexusTab.vision.title, systemImage: NexusTab.vision.icon) }
                .tag(NexusTab.vision)

            NavigationStack { MoreView() }
                .tabItem { Label(NexusTab.more.title, systemImage: NexusTab.more.icon) }
                .tag(NexusTab.more)
        }
        .toolbarBackground(NexusTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(NexusTheme.primary)
        .alert("NEXUS", isPresented: Binding(
            get: { state.alertMessage != nil },
            set: { if !$0 { state.alertMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { state.alertMessage = nil }
        } message: {
            Text(state.alertMessage ?? "")
        }
        .confirmationDialog(
            state.pendingCommand?.confirmation ?? "确认执行？",
            isPresented: Binding(
                get: { state.pendingCommand != nil },
                set: { if !$0 { state.pendingCommand = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("确认执行") {
                Task { await state.executePendingCommand() }
            }
            Button("取消", role: .cancel) { state.pendingCommand = nil }
        }
    }
}
