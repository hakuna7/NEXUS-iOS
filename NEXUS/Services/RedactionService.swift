import UIKit
import Vision

enum RedactionService {
    static func redact(_ image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let size = CGSize(width: cgImage.width, height: cgImage.height)

        return try await withCheckedThrowingContinuation { continuation in
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = false
            let faceRequest = VNDetectFaceRectanglesRequest()
            let barcodeRequest = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgOrientation)

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([textRequest, faceRequest, barcodeRequest])
                    var boxes = (faceRequest.results ?? []).map(\.boundingBox)
                    boxes.append(contentsOf: (barcodeRequest.results ?? []).map(\.boundingBox))
                    for observation in textRequest.results ?? [] {
                        let value = observation.topCandidates(1).first?.string ?? ""
                        if isSensitive(value) {
                            boxes.append(observation.boundingBox)
                        }
                    }
                    let output = drawRedactions(on: cgImage, size: size, boxes: boxes, scale: image.scale)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func isSensitive(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: " ", with: "")
        let patterns = [
            #"1[3-9]\d{9}"#,
            #"\d{17}[\dXx]"#,
            #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            #"\b\d{14,19}\b"#
        ]
        return patterns.contains { pattern in
            compact.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func drawRedactions(on image: CGImage, size: CGSize, boxes: [CGRect], scale: CGFloat) -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return UIImage(cgImage: image, scale: scale, orientation: .up) }

        context.draw(image, in: CGRect(origin: .zero, size: size))
        context.setFillColor(UIColor.black.cgColor)
        for box in boxes {
            let rect = CGRect(
                x: box.minX * size.width,
                y: box.minY * size.height,
                width: box.width * size.width,
                height: box.height * size.height
            ).insetBy(dx: -8, dy: -8)
            context.fill(rect)
        }
        guard let output = context.makeImage() else { return UIImage(cgImage: image) }
        return UIImage(cgImage: output, scale: scale, orientation: .up)
    }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
