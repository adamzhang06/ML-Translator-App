import SwiftUI
import Vision

// App entry point. Add these files to a new SwiftUI Xcode project and set
// the app lifecycle to SwiftUI to use this @main struct.
@main
struct StarterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Main content view wires together the camera preview, text recognizer, face detector and overlay.
// This keeps UI separate from the vision/translation logic so you can extend it
// (for example: add face detection, offline translation DB, or server fallback).
struct ContentView: View {
    // Vision services
    @StateObject private var textRecognizer = TextRecognizer()
    @StateObject private var faceDetector = FaceDetector()
    
    // Translation services
    @StateObject private var translator = TranslationStore()
    @StateObject private var enhancedTranslator = EnhancedTranslationStore()
    @StateObject private var coreMLTranslator = CoreMLTranslationService()
    
    // Face captioning service
    @StateObject private var faceCaptionService: FaceCaptionService
    
    // UI state
    @State private var useEnhancedTranslation = true
    @State private var enableFaceDetection = true
    @State private var showEnhancedOverlay = true
    
    init() {
        let enhancedTranslator = EnhancedTranslationStore()
        let faceDetector = FaceDetector()
        _enhancedTranslator = StateObject(wrappedValue: enhancedTranslator)
        _faceDetector = StateObject(wrappedValue: faceDetector)
        _faceCaptionService = StateObject(wrappedValue: FaceCaptionService(
            faceDetector: faceDetector,
            translationService: enhancedTranslator
        ))
    }

    var body: some View {
        ZStack {
            // CameraView is a UIViewRepresentable that provides the live camera
            // and forwards frames to both text recognizer and face detector
            CameraView(frameHandler: { sampleBuffer in
                textRecognizer.handleSampleBuffer(sampleBuffer)
                if enableFaceDetection {
                    faceDetector.handleSampleBuffer(sampleBuffer)
                }
            })
            .edgesIgnoringSafeArea(.all)

            // Enhanced overlay that handles both text and face observations
            if showEnhancedOverlay {
                EnhancedOverlayView(
                    textObservations: textRecognizer.observations,
                    textTranslations: textRecognizer.observations.map { obs in
                        if useEnhancedTranslation {
                            return enhancedTranslator.translations[obs.string] ?? translator.translate(text: obs.string)
                        } else {
                            return translator.translate(text: obs.string)
                        }
                    },
                    faceObservations: faceDetector.faceObservations,
                    faceCaptions: faceCaptionService.faceCaptions
                )
                .withAnimation()
                .withAccessibility()
            } else {
                // Fallback to original overlay for text only
                OverlayView(observations: textRecognizer.observations, translations: textRecognizer.observations.map { obs in
                    if useEnhancedTranslation {
                        return enhancedTranslator.translations[obs.string] ?? translator.translate(text: obs.string)
                    } else {
                        return translator.translate(text: obs.string)
                    }
                })
            }
            
            // Settings panel
            settingsPanel()
        }
        .onAppear {
            // Start text recognition when view appears
            textRecognizer.start()
            
            // Start face detection if enabled
            if enableFaceDetection {
                faceDetector.start()
            }
            
            // Start async translation for detected text
            Task {
                for observation in textRecognizer.observations {
                    let _ = await enhancedTranslator.translate(text: observation.string)
                }
            }
        }
        .onDisappear {
            // Stop recognition to free camera/CPU when leaving the view
            textRecognizer.stop()
            faceDetector.stop()
        }
    }
    
    // Settings panel for controlling overlay features
    @ViewBuilder
    private func settingsPanel() -> some View {
        VStack {
            Spacer()
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enhanced Translation", isOn: $useEnhancedTranslation)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    Toggle("Face Detection", isOn: $enableFaceDetection)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .onChange(of: enableFaceDetection) { enabled in
                            if enabled {
                                faceDetector.start()
                            } else {
                                faceDetector.stop()
                            }
                        }
                    
                    Toggle("Enhanced Overlay", isOn: $showEnhancedOverlay)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    
                    // Statistics display
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Text: \(textRecognizer.observations.count)")
                        Text("Faces: \(faceDetector.faceObservations.count)")
                        Text("Captions: \(faceCaptionService.faceCaptions.count)")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
        }
    }
}
