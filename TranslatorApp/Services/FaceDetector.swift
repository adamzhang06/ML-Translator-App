import Foundation
import Vision
import AVFoundation
import Combine

// Face observation structure to hold detected faces with their characteristics
struct FaceObservation: Identifiable {
    let id = UUID()
    let boundingBox: CGRect // normalized (0..1) rect in Vision coordinates
    let landmarks: VNFaceLandmarks2D?
    let confidence: Float
    let faceID: Int? // Face tracking ID if available
    let age: VNClassificationObservation?
    let gender: VNClassificationObservation?
    let expression: String? // Derived from landmarks analysis
}

// Enhanced face detection service with tracking, landmarks, and analysis
final class FaceDetector: ObservableObject {
    // Published face observations for UI consumption
    @Published var faceObservations: [FaceObservation] = []
    @Published var isDetecting: Bool = false
    @Published var detectionCount: Int = 0
    
    // Vision requests for different face analysis features
    private var faceDetectionRequest: VNDetectFaceRectanglesRequest!
    private var faceLandmarksRequest: VNDetectFaceLandmarksRequest!
    private var faceTrackingRequest: VNTrackObjectRequest?
    
    // Request handler for processing frames
    private let sequenceHandler = VNSequenceRequestHandler()
    
    // Detection configuration
    private var running = false
    private var shouldDetectLandmarks = true
    private var shouldTrackFaces = true
    private var minFaceSize: Float = 0.1 // Minimum face size as fraction of image
    
    // Face tracking state
    private var trackedFaces: [UUID: VNDetectedObjectObservation] = [:]
    
    init() {
        setupFaceDetection()
    }
    
    private func setupFaceDetection() {
        // Configure face detection request
        faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        // Configure face landmarks request
        faceLandmarksRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceLandmarks(request: request, error: error)
        }
        faceLandmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
    }
    
    // Start/stop face detection
    func start() {
        running = true
        isDetecting = true
    }
    
    func stop() {
        running = false
        isDetecting = false
        trackedFaces.removeAll()
    }
    
    // Process camera frame for face detection
    func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard running else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        
        do {
            var requests: [VNRequest] = [faceDetectionRequest]
            
            // Add landmarks detection if enabled
            if shouldDetectLandmarks {
                requests.append(faceLandmarksRequest)
            }
            
            // Perform face detection
            try sequenceHandler.perform(requests, on: pixelBuffer)
            
        } catch {
            print("Face detection error: \(error)")
        }
    }
    
    // Handle face detection results
    private func handleFaceDetection(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNFaceObservation] else { return }
        
        let mappedFaces = results.compactMap { observation -> FaceObservation? in
            // Filter out faces that are too small
            let faceArea = observation.boundingBox.width * observation.boundingBox.height
            guard faceArea >= minFaceSize else { return nil }
            
            return FaceObservation(
                boundingBox: observation.boundingBox,
                landmarks: observation.landmarks,
                confidence: observation.confidence,
                faceID: nil, // Will be set by tracking if enabled
                age: nil,    // Would be set by additional analysis
                gender: nil, // Would be set by additional analysis
                expression: analyzeExpression(from: observation.landmarks)
            )
        }
        
        DispatchQueue.main.async {
            self.faceObservations = mappedFaces
            self.detectionCount += mappedFaces.count
        }
    }
    
    // Handle face landmarks results (called separately if landmarks detection is enabled)
    private func handleFaceLandmarks(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNFaceObservation] else { return }
        
        // Update existing face observations with landmark data
        DispatchQueue.main.async {
            for (index, observation) in results.enumerated() {
                if index < self.faceObservations.count {
                    // Update the existing face observation with landmarks
                    let updatedFace = FaceObservation(
                        boundingBox: self.faceObservations[index].boundingBox,
                        landmarks: observation.landmarks,
                        confidence: observation.confidence,
                        faceID: self.faceObservations[index].faceID,
                        age: self.faceObservations[index].age,
                        gender: self.faceObservations[index].gender,
                        expression: self.analyzeExpression(from: observation.landmarks)
                    )
                    self.faceObservations[index] = updatedFace
                }
            }
        }
    }
    
    // Analyze facial expression from landmarks
    private func analyzeExpression(from landmarks: VNFaceLandmarks2D?) -> String? {
        guard let landmarks = landmarks else { return nil }
        
        // Simplified expression analysis based on landmarks
        // In a full implementation, you'd use more sophisticated analysis
        
        var expressions: [String] = []
        
        // Check for smile based on mouth landmarks
        if let mouth = landmarks.outerLips {
            let mouthPoints = mouth.normalizedPoints
            if mouthPoints.count >= 4 {
                // Simple smile detection based on mouth curve
                let leftCorner = mouthPoints[0]
                let rightCorner = mouthPoints[mouthPoints.count/2]
                let topCenter = mouthPoints[mouthPoints.count/4]
                let bottomCenter = mouthPoints[3*mouthPoints.count/4]
                
                if topCenter.y > bottomCenter.y {
                    expressions.append("smile")
                }
            }
        }
        
        // Check for raised eyebrows
        if let leftEyebrow = landmarks.leftEyebrow,
           let rightEyebrow = landmarks.rightEyebrow {
            // Simple eyebrow position analysis
            let leftPoints = leftEyebrow.normalizedPoints
            let rightPoints = rightEyebrow.normalizedPoints
            
            if !leftPoints.isEmpty && !rightPoints.isEmpty {
                let avgLeftHeight = leftPoints.map { $0.y }.reduce(0, +) / Float(leftPoints.count)
                let avgRightHeight = rightPoints.map { $0.y }.reduce(0, +) / Float(rightPoints.count)
                
                if avgLeftHeight > 0.6 && avgRightHeight > 0.6 {
                    expressions.append("surprised")
                }
            }
        }
        
        return expressions.isEmpty ? "neutral" : expressions.joined(separator: ", ")
    }
    
    // Configuration methods
    func setMinimumFaceSize(_ size: Float) {
        minFaceSize = size
    }
    
    func enableLandmarkDetection(_ enable: Bool) {
        shouldDetectLandmarks = enable
    }
    
    func enableFaceTracking(_ enable: Bool) {
        shouldTrackFaces = enable
    }
    
    // Get face detection statistics
    func getDetectionStats() -> [String: Any] {
        return [
            "isDetecting": isDetecting,
            "totalDetections": detectionCount,
            "currentFaces": faceObservations.count,
            "landmarksEnabled": shouldDetectLandmarks,
            "trackingEnabled": shouldTrackFaces,
            "minFaceSize": minFaceSize
        ]
    }
}

// Extension for advanced face analysis
extension FaceDetector {
    
    // Estimate age group from face characteristics
    func estimateAgeGroup(for faceObservation: FaceObservation) -> String {
        // This would integrate with a trained Core ML model for age estimation
        // For now, return a placeholder
        return "Adult"
    }
    
    // Estimate gender from face characteristics
    func estimateGender(for faceObservation: FaceObservation) -> String {
        // This would integrate with a trained Core ML model for gender classification
        // For now, return a placeholder
        return "Unknown"
    }
    
    // Generate face description for captioning
    func generateFaceDescription(for faceObservation: FaceObservation) -> String {
        var description = "Person"
        
        if let expression = faceObservation.expression, expression != "neutral" {
            description += " (\(expression))"
        }
        
        // Add confidence level
        if faceObservation.confidence > 0.8 {
            description += " [High confidence]"
        } else if faceObservation.confidence > 0.5 {
            description += " [Medium confidence]"
        } else {
            description += " [Low confidence]"
        }
        
        return description
    }
}