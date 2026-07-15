import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        List {
            Section("数据") {
                NavigationLink { MemoryView() } label: {
                    Label("屏幕记忆", systemImage: "clock.arrow.circlepath")
                }
                NavigationLink { PrivacyView() } label: {
                    Label("隐私打码", systemImage: "eye.slash")
                }
            }
            Section("设备") {
                NavigationLink { RemoteView() } label: {
                    Label("Windows 空间遥控", systemImage: "move.3d")
                }
            }
            Section("系统") {
                NavigationLink { SettingsView() } label: {
                    Label("模型与偏好", systemImage: "gearshape")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("更多能力")
        .nexusScreen()
    }
}
