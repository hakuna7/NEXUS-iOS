import AVFoundation
import AVKit
import SwiftUI
import UIKit

@MainActor
final class OverlayState: ObservableObject {
    @Published var title = "NEXUS 已待命"
    @Published var text = "启动屏幕读取后，译文会显示在这里。"
    @Published var isWorking = false
}

@MainActor
final class PiPManager: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    let sourceView = UIView()
    @Published var isActive = false

    private let contentController = AVPictureInPictureVideoCallViewController()
    private var controller: AVPictureInPictureController?
    private let overlayState: OverlayState

    init(overlayState: OverlayState) {
        self.overlayState = overlayState
        super.init()
        configure()
    }

    func start() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        controller?.startPictureInPicture()
    }

    func stop() {
        controller?.stopPictureInPicture()
    }

    private func configure() {
        sourceView.backgroundColor = .clear
        contentController.preferredContentSize = CGSize(width: 540, height: 240)
        let host = UIHostingController(rootView: OverlayContentView(state: overlayState))
        host.view.backgroundColor = .clear
        contentController.addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        contentController.view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: contentController.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: contentController.view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: contentController.view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: contentController.view.bottomAnchor)
        ])
        host.didMove(toParent: contentController)

        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: contentController
        )
        controller = AVPictureInPictureController(contentSource: source)
        controller?.delegate = self
        controller?.canStartPictureInPictureAutomaticallyFromInline = false
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in isActive = true }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in isActive = false }
    }
}

private struct OverlayContentView: View {
    @ObservedObject var state: OverlayState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(state.isWorking ? NexusTheme.secondary : NexusTheme.primary)
                    .frame(width: 8, height: 8)
                Text(state.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NexusTheme.primary)
                Spacer()
                Text("NEXUS")
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(NexusTheme.muted)
            }
            Text(state.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(NexusTheme.background)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(NexusTheme.primary)
                .frame(width: 3)
        }
    }
}

struct PiPAnchorView: UIViewRepresentable {
    let manager: PiPManager

    func makeUIView(context: Context) -> UIView {
        manager.sourceView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
