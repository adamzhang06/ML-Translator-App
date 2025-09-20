import SwiftUI

// Overlay that draws bounding boxes and translated text over the camera preview.
// This view expects observations in Vision coordinates (normalized, origin bottom-left)
// and converts them to SwiftUI coordinates so boxes and labels line up with the
// camera preview. To add face captions, provide observations from a face detector
// and feed the translated captions array the same way.
struct OverlayView: View {
    var observations: [RecognizedObservation]
    var translations: [String]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(observations.enumerated()), id: \.element.id) { index, obs in
                    let rect = convertRect(obs.boundingBox, in: geo.size)
                    // Draw a rectangle around the recognized text region.
                    Rectangle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    // Draw the translated string above the box. If translations array
                    // doesn't have a value for this index, fall back to the original string.
                    Text(translations.indices.contains(index) ? translations[index] : obs.string)
                        .font(.system(size: 14))
                        .padding(4)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.black)
                        // Position the label slightly above the top-left of the box.
                        .position(x: rect.minX + 60, y: rect.minY - 18)
                }
            }
        }
        // Disable hit testing so overlays don't block camera view interactions.
        .allowsHitTesting(false)
    }

    // Convert Vision normalized rect (origin at bottom-left) to SwiftUI coordinates (origin at top-left).
    // Vision coordinates: origin bottom-left, values from 0..1 relative to image.
    // SwiftUI/Cocoa: origin top-left. This function also scales to the view size.
    func convertRect(_ bbox: CGRect, in size: CGSize) -> CGRect {
        let x = bbox.origin.x * size.width
        // Vision bbox y is bottom-left origin; UIKit/SwiftUI is top-left
        let y = (1 - bbox.origin.y - bbox.size.height) * size.height
        let w = bbox.size.width * size.width
        let h = bbox.size.height * size.height
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

// A tiny extension to help ForEach enumerated binding (not used heavily here but useful).
extension Array {
    func enumeratedArray() -> Array<(offset: Int, element: Element)> {
        Array(self.enumerated())
    }
}
