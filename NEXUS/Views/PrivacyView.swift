import PhotosUI
import SwiftUI

struct PrivacyView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var resultImage: UIImage?
    @State private var isWorking = false
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NexusPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "自动隐私打码")
                        Text("识别人脸、二维码、手机号、邮箱、身份证和长银行卡号，并在本机完成遮挡。")
                            .font(.subheadline)
                            .foregroundStyle(NexusTheme.muted)
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label("选择图片", systemImage: "photo.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(NexusTheme.primary)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                    }
                }

                if let image = resultImage ?? sourceImage {
                    NexusPanel {
                        VStack(spacing: 12) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            HStack(spacing: 10) {
                                Button {
                                    Task { await redact() }
                                } label: {
                                    Label(isWorking ? "处理中" : "自动打码", systemImage: "eye.slash.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(sourceImage == nil || isWorking)
                                Button {
                                    showShare = true
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .frame(width: 42)
                                }
                                .buttonStyle(.bordered)
                                .disabled(resultImage == nil)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("隐私打码")
        .navigationBarTitleDisplayMode(.inline)
        .nexusBackButton()
        .nexusScreen()
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                sourceImage = image
                resultImage = nil
            }
        }
        .sheet(isPresented: $showShare) {
            if let resultImage {
                ActivityView(items: [resultImage])
            }
        }
    }

    private func redact() async {
        guard let sourceImage else { return }
        isWorking = true
        resultImage = try? await RedactionService.redact(sourceImage)
        isWorking = false
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
