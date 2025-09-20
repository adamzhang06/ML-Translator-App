import Foundation
import Vision
import AVFoundation
import Combine

// Simple struct to hold recognized text and its bounding box in normalized coordinates.
// `boundingBox` uses Vision coordinates (origin in bottom-left, values 0..1).
struct RecognizedObservation: Identifiable {
    let id = UUID()
    let string: String
    let boundingBox: CGRect // normalized (0..1) rect in Vision coordinates
}

// Handles feeding CMSampleBuffer frames to Vision OCR and publishing observations.
// This class runs Vision text recognition and publishes an array of RecognizedObservation
// which the UI can observe and overlay. To add face captioning, you can run a
// VNDetectFaceRectanglesRequest or VNDetectFaceLandmarksRequest on the same frames
// and map face regions to captions.
final class TextRecognizer: ObservableObject {
    // Published observations drive the overlay UI.
    @Published var observations: [RecognizedObservation] = []

    private var request: VNRecognizeTextRequest!
    private let sequenceHandler = VNSequenceRequestHandler()
    private var running = false

    init() {
        // Configure the Vision text recognition request.
        request = VNRecognizeTextRequest(completionHandler: self.handle)
        request.recognitionLevel = .accurate
        // Recognize both English and Simplified Chinese by default. Add more if needed.
        request.recognitionLanguages = ["en-US", "zh-Hans"]
        request.usesLanguageCorrection = true
    }

    // Start/stop control so the view can pause recognition when not visible.
    func start() {
        running = true
    }

    func stop() {
        running = false
    }

    // Called by the CameraView coordinator for each captured sample buffer.
    func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard running else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // VNImageRequestHandler can accept CVPixelBuffer directly for performance.
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

        do {
            // Use the sequenceHandler to reuse resources across frames. This call
            // runs on the background queue provided by CameraView.
            try sequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            print("Vision error: \(error)")
        }
    }

    // Vision completion handler: map VNRecognizedTextObservation results to our model.
    private func handle(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNRecognizedTextObservation] else { return }

        // Map observations to our simple struct, taking top candidate text.
        let mapped = results.compactMap { obs -> RecognizedObservation? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            return RecognizedObservation(string: candidate.string, boundingBox: obs.boundingBox)
        }

        // Publish on main thread for UI consumption.
        DispatchQueue.main.async {
            self.observations = mapped
        }
    }
}
