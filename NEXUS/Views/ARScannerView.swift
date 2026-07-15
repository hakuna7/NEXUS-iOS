import ARKit
import SwiftUI
import Vision
import simd

@MainActor
final class ARScanModel: ObservableObject {
    @Published var labels: [String] = []
    @Published var recognizedText = ""
    @Published var centerDistance: Float?
    @Published var tracking = "初始化空间定位"
}

struct ARScannerScreen: View {
    @StateObject private var model = ARScanModel()

    var body: some View {
        ZStack {
            ARScannerView(model: model)
                .ignoresSafeArea(edges: .bottom)
            scannerHUD
        }
        .navigationTitle("AR 视觉扫描")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black)
    }

    private var scannerHUD: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("VISION CORE")
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(NexusTheme.primary)
                    Text(model.labels.isEmpty ? "正在分析画面" : model.labels.joined(separator: " · "))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.centerDistance.map { String(format: "%.2f m", $0) } ?? "-- m")
                        .font(.headline.monospacedDigit())
                    Text(model.tracking)
                        .font(.caption2)
                        .foregroundStyle(NexusTheme.muted)
                }
            }
            .padding(14)
            .background(Color.black.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(NexusTheme.primary.opacity(0.75), lineWidth: 1)
                    .frame(width: 150, height: 150)
                Rectangle()
                    .fill(NexusTheme.primary)
                    .frame(width: 18, height: 2)
                Rectangle()
                    .fill(NexusTheme.primary)
                    .frame(width: 2, height: 18)
            }

            Spacer()

            if !model.recognizedText.isEmpty {
                Text(model.recognizedText)
                    .font(.subheadline)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.black.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

private struct ARScannerView: UIViewRepresentable {
    @ObservedObject var model: ARScanModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session.delegate = context.coordinator
        context.coordinator.sceneView = view
        view.automaticallyUpdatesLighting = true
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        let model: ARScanModel
        weak var sceneView: ARSCNView?
        private var lastAnalysis = Date.distantPast
        private let visionQueue = DispatchQueue(label: "nexus.ar.vision", qos: .userInitiated)

        init(model: ARScanModel) {
            self.model = model
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            updateTracking(frame.camera.trackingState)
            updateDistance()
            guard Date().timeIntervalSince(lastAnalysis) > 1 else { return }
            lastAnalysis = Date()
            let pixelBuffer = frame.capturedImage
            visionQueue.async { [weak self] in
                self?.analyze(pixelBuffer)
            }
        }

        private func analyze(_ pixelBuffer: CVPixelBuffer) {
            let classify = VNClassifyImageRequest()
            let text = VNRecognizeTextRequest()
            text.recognitionLevel = .fast
            text.usesLanguageCorrection = true
            do {
                try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([classify, text])
                let labels = (classify.results ?? [])
                    .filter { $0.confidence > 0.15 }
                    .prefix(3)
                    .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
                let lines = (text.results ?? []).prefix(6).compactMap { $0.topCandidates(1).first?.string }
                DispatchQueue.main.async { [weak self] in
                    self?.model.labels = labels
                    self?.model.recognizedText = lines.joined(separator: "\n")
                }
            } catch {
                print("AR analysis failed: \(error)")
            }
        }

        private func updateTracking(_ state: ARCamera.TrackingState) {
            let value: String
            switch state {
            case .normal: value = "空间定位稳定"
            case .notAvailable: value = "定位不可用"
            case .limited: value = "移动手机以建立空间"
            }
            DispatchQueue.main.async { [weak self] in self?.model.tracking = value }
        }

        private func updateDistance() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let view = sceneView else { return }
                let point = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
                guard let query = view.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any),
                      let result = view.session.raycast(query).first else {
                    model.centerDistance = nil
                    return
                }
                let position = result.worldTransform.columns.3
                let camera = view.session.currentFrame?.camera.transform.columns.3 ?? SIMD4<Float>(0, 0, 0, 1)
                let delta = SIMD3<Float>(position.x - camera.x, position.y - camera.y, position.z - camera.z)
                model.centerDistance = simd_length(delta)
            }
        }
    }
}
