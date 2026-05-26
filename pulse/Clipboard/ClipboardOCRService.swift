import AppKit
import Foundation
import Vision

@MainActor
final class ClipboardOCRService {
    func recognizedText(in imageData: Data) async -> String {
        guard
            let image = NSImage(data: imageData),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return ""
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
        } catch {
            return ""
        }

        return request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""
    }
}
