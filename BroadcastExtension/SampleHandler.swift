import CoreImage
import Foundation
import ImageIO
import ReplayKit
import Vision

final class SampleHandler: RPBroadcastSampleHandler {
    private var lastScan = Date.distantPast
    private var lastText = ""
    private let interval: TimeInterval = 1.2

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        lastScan = .distantPast
        lastText = ""
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video,
              Date().timeIntervalSince(lastScan) >= interval,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastScan = Date()

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.012
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja-JP", "ko-KR"]

        do {
            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: imageOrientation(from: sampleBuffer),
                options: [:]
            )
            try handler.perform([request])
            let lines = (request.results ?? [])
                .sorted { lhs, rhs in
                    if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.02 {
                        return lhs.boundingBox.midY > rhs.boundingBox.midY
                    }
                    return lhs.boundingBox.minX < rhs.boundingBox.minX
                }
                .compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count > 1, text != lastText else { return }
            lastText = text
            sendToHost(text)
        } catch {
            print("NEXUS OCR failed: \(error)")
        }
    }

    private func sendToHost(_ text: String) {
        guard let url = URL(string: "http://127.0.0.1:8765/ocr") else { return }
        let payload = OCRPayload(text: text, timestamp: Date().timeIntervalSince1970)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        URLSession.shared.dataTask(with: request).resume()
    }

    private func imageOrientation(from sampleBuffer: CMSampleBuffer) -> CGImagePropertyOrientation {
        guard let value = CMGetAttachment(
            sampleBuffer,
            key: RPVideoSampleOrientationKey as CFString,
            attachmentModeOut: nil
        ) as? NSNumber,
              let orientation = CGImagePropertyOrientation(rawValue: value.uint32Value) else {
            return .up
        }
        return orientation
    }
}

private struct OCRPayload: Codable {
    let text: String
    let timestamp: TimeInterval
}
