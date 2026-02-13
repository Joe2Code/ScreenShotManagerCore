import Foundation
import Vision
import CoreGraphics

/// OCREngine provides cross-platform text recognition using the Vision framework.
/// Takes CGImage input (works on both iOS and macOS).
public final class OCREngine {

    public init() {}

    // MARK: - Async Recognition

    /// Recognizes text in an image asynchronously.
    public func recognizeText(in cgImage: CGImage) async -> String {
        return await withCheckedContinuation { continuation in
            let text = recognizeTextSync(in: cgImage)
            continuation.resume(returning: text)
        }
    }

    // MARK: - Synchronous Recognition

    /// Recognizes text in an image synchronously.
    public func recognizeTextSync(in cgImage: CGImage) -> String {
        var recognizedText = ""

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            let textPieces = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            recognizedText = textPieces.joined(separator: "\n")
        }

        Self.configureRequest(request)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("OCREngine Error: \(error)")
        }

        return recognizedText
    }

    // MARK: - Configuration

    private static func configureRequest(_ request: VNRecognizeTextRequest) {
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-GB", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-BR"]
        request.minimumTextHeight = 0.01

        if #available(iOS 16.0, macOS 13.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }
    }
}
