import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var apiKey = ""
    @State private var showKey = false

    var body: some View {
        Form {
            Section {
                TextField("接口地址", text: $state.settings.endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("模型名称", text: $state.settings.model)
                    .textInputAutocapitalization(.never)
                HStack {
                    Group {
                        if showKey {
                            TextField("API Key", text: $apiKey)
                        } else {
                            SecureField(state.hasAPIKey ? "已保存，留空则不修改" : "API Key", text: $apiKey)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("AI 模型")
            } footer: {
                Text("密钥仅保存在本机钥匙串，不会写入屏幕记忆或公开仓库。")
            }

            Section("看屏行为") {
                Toggle("页面变化后自动处理", isOn: $state.settings.autoProcess)
                Toggle("保存屏幕文字记忆", isOn: $state.settings.rememberScreens)
            }

            Section {
                Button("保存设置") {
                    state.saveSettings(apiKey: apiKey.isEmpty ? nil : apiKey)
                    apiKey = ""
                }
                .frame(maxWidth: .infinity)
            }

            Section("说明") {
                LabeledContent("版本", value: "0.1.0")
                LabeledContent("录屏识别", value: "本地 Vision OCR")
                LabeledContent("安装方式", value: "SideStore 独立安装")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("模型与偏好")
        .navigationBarTitleDisplayMode(.inline)
        .nexusScreen()
    }
}
