import SwiftUI
import Vision

// Enhanced overlay view that handles both text and face observations
// with different visual styles and improved coordinate handling
struct EnhancedOverlayView: View {
    var textObservations: [RecognizedObservation]
    var textTranslations: [String]
    var faceObservations: [FaceObservation]
    var faceCaptions: [FaceCaption]
    
    // Display options
    @State private var showTextBoxes: Bool = true
    @State private var showFaceBoxes: Bool = true
    @State private var showTextTranslations: Bool = true
    @State private var showFaceCaptions: Bool = true
    @State private var overlayOpacity: Double = 0.8
    
    // Visual styling options
    private let textBoxColor: Color = .green
    private let faceBoxColor: Color = .blue
    private let textLabelColor: Color = .white
    private let faceLabelColor: Color = .yellow
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Text overlays
                if showTextBoxes || showTextTranslations {
                    textOverlayLayer(in: geo.size)
                }
                
                // Face overlays
                if showFaceBoxes || showFaceCaptions {
                    faceOverlayLayer(in: geo.size)
                }
                
                // Control panel (can be toggled)
                controlPanel()
            }
        }
        .allowsHitTesting(false)
        .opacity(overlayOpacity)
    }
    
    // Text overlay layer
    @ViewBuilder
    private func textOverlayLayer(in size: CGSize) -> some View {
        ForEach(Array(textObservations.enumerated()), id: \.element.id) { index, obs in
            let rect = convertRect(obs.boundingBox, in: size)
            
            ZStack {
                // Text bounding box
                if showTextBoxes {
                    Rectangle()
                        .stroke(textBoxColor, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
                
                // Text translation label
                if showTextTranslations {
                    let translation = textTranslations.indices.contains(index) ? textTranslations[index] : obs.string
                    
                    TextOverlayLabel(
                        text: translation,
                        originalText: obs.string,
                        backgroundColor: textBoxColor.opacity(0.8),
                        textColor: textLabelColor
                    )
                    .position(x: rect.minX + 60, y: rect.minY - 18)
                }
            }
        }
    }
    
    // Face overlay layer
    @ViewBuilder
    private func faceOverlayLayer(in size: CGSize) -> some View {
        ForEach(faceObservations) { faceObs in
            let rect = convertRect(faceObs.boundingBox, in: size)
            
            ZStack {
                // Face bounding box
                if showFaceBoxes {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(faceBoxColor, lineWidth: 3)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    
                    // Face landmarks overlay (if available)
                    if let landmarks = faceObs.landmarks {
                        faceLandmarksOverlay(landmarks: landmarks, in: rect)
                    }
                    
                    // Confidence indicator
                    confidenceIndicator(confidence: faceObs.confidence)
                        .position(x: rect.maxX - 15, y: rect.minY + 15)
                }
                
                // Face caption label
                if showFaceCaptions, let caption = getFaceCaption(for: faceObs.id) {
                    FaceCaptionLabel(
                        caption: caption,
                        backgroundColor: faceBoxColor.opacity(0.8),
                        textColor: faceLabelColor
                    )
                    .position(x: rect.midX, y: rect.maxY + 25)
                }
            }
        }
    }
    
    // Face landmarks overlay
    @ViewBuilder
    private func faceLandmarksOverlay(landmarks: VNFaceLandmarks2D, in faceRect: CGRect) -> some View {
        ZStack {
            // Eyes
            if let leftEye = landmarks.leftEye {
                landmarkPoints(points: leftEye.normalizedPoints, in: faceRect, color: .cyan, size: 2)
            }
            if let rightEye = landmarks.rightEye {
                landmarkPoints(points: rightEye.normalizedPoints, in: faceRect, color: .cyan, size: 2)
            }
            
            // Mouth
            if let outerLips = landmarks.outerLips {
                landmarkPoints(points: outerLips.normalizedPoints, in: faceRect, color: .red, size: 1.5)
            }
            
            // Nose
            if let nose = landmarks.nose {
                landmarkPoints(points: nose.normalizedPoints, in: faceRect, color: .orange, size: 1.5)
            }
        }
    }
    
    // Individual landmark points
    @ViewBuilder
    private func landmarkPoints(points: [CGPoint], in faceRect: CGRect, color: Color, size: CGFloat) -> some View {
        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .position(
                    x: faceRect.minX + point.x * faceRect.width,
                    y: faceRect.minY + (1 - point.y) * faceRect.height // Flip Y coordinate
                )
        }
    }
    
    // Confidence indicator
    @ViewBuilder
    private func confidenceIndicator(confidence: Float) -> some View {
        let color: Color = confidence > 0.8 ? .green : confidence > 0.5 ? .orange : .red
        
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1)
            )
    }
    
    // Control panel for overlay options
    @ViewBuilder
    private func controlPanel() -> some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 4) {
                    Button(action: { showTextBoxes.toggle() }) {
                        Image(systemName: showTextBoxes ? "text.viewfinder" : "text.viewfinder.slash")
                            .foregroundColor(showTextBoxes ? textBoxColor : .gray)
                    }
                    
                    Button(action: { showFaceBoxes.toggle() }) {
                        Image(systemName: showFaceBoxes ? "person.crop.rectangle" : "person.crop.rectangle.slash")
                            .foregroundColor(showFaceBoxes ? faceBoxColor : .gray)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
                .padding(.trailing)
            }
            
            Spacer()
        }
    }
    
    // Get face caption for a specific face ID
    private func getFaceCaption(for faceID: UUID) -> FaceCaption? {
        return faceCaptions.first { $0.faceID == faceID }
    }
    
    // Convert Vision normalized rect to SwiftUI coordinates
    func convertRect(_ bbox: CGRect, in size: CGSize) -> CGRect {
        let x = bbox.origin.x * size.width
        let y = (1 - bbox.origin.y - bbox.size.height) * size.height
        let w = bbox.size.width * size.width
        let h = bbox.size.height * size.height
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

// Custom text overlay label with enhanced styling
struct TextOverlayLabel: View {
    let text: String
    let originalText: String
    let backgroundColor: Color
    let textColor: Color
    
    @State private var showOriginal: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textColor)
            
            if showOriginal && text != originalText {
                Text(originalText)
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(textColor.opacity(0.8))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .shadow(radius: 2)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showOriginal.toggle()
            }
        }
    }
}

// Custom face caption label with person information
struct FaceCaptionLabel: View {
    let caption: FaceCaption
    let backgroundColor: Color
    let textColor: Color
    
    @State private var showDetails: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(caption.translatedCaption)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
            
            if showDetails {
                VStack(spacing: 1) {
                    Text(caption.originalCaption)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(textColor.opacity(0.8))
                    
                    Text("Confidence: \(Int(caption.confidence * 100))%")
                        .font(.system(size: 9, weight: .light))
                        .foregroundColor(textColor.opacity(0.7))
                    
                    if caption.isPersonalized {
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .shadow(radius: 3)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetails.toggle()
            }
        }
    }
}

// Extension for additional overlay functionality
extension EnhancedOverlayView {
    
    // Create overlay with animation support
    func withAnimation() -> some View {
        self.animation(.easeInOut(duration: 0.3), value: textObservations.count)
            .animation(.easeInOut(duration: 0.3), value: faceObservations.count)
    }
    
    // Create overlay with accessibility support
    func withAccessibility() -> some View {
        self.accessibilityElement(children: .contain)
            .accessibilityLabel("Camera overlay showing \(textObservations.count) text areas and \(faceObservations.count) faces")
    }
    
    // Create overlay with custom styling
    func withCustomStyling(
        textColor: Color = .green,
        faceColor: Color = .blue,
        opacity: Double = 0.8
    ) -> some View {
        self.opacity(opacity)
    }
}

// Preview helper for SwiftUI previews
struct EnhancedOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedOverlayView(
            textObservations: [
                RecognizedObservation(string: "Hello", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.1)),
                RecognizedObservation(string: "World", boundingBox: CGRect(x: 0.5, y: 0.3, width: 0.2, height: 0.08))
            ],
            textTranslations: ["你好", "世界"],
            faceObservations: [
                FaceObservation(
                    boundingBox: CGRect(x: 0.2, y: 0.5, width: 0.3, height: 0.4),
                    landmarks: nil,
                    confidence: 0.85,
                    faceID: nil,
                    age: nil,
                    gender: nil,
                    expression: "smile"
                )
            ],
            faceCaptions: [
                FaceCaption(
                    faceID: UUID(),
                    boundingBox: CGRect(x: 0.2, y: 0.5, width: 0.3, height: 0.4),
                    originalCaption: "Happy person",
                    translatedCaption: "快乐的人",
                    confidence: 0.85,
                    timestamp: Date(),
                    isPersonalized: false
                )
            ]
        )
        .background(Color.black)
    }
}