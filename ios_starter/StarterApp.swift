import SwiftUI

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

// Main content view wires together the camera preview, text recognizer and overlay.
// This keeps UI separate from the vision/translation logic so you can extend it
// (for example: add face detection, offline translation DB, or server fallback).
struct ContentView: View {
    // TextRecognizer publishes detected text observations (strings + boxes).
    @StateObject private var recognizer = TextRecognizer()
    // TranslationStore provides a simple translate(text:) method.
    @StateObject private var translator = TranslationStore()

    var body: some View {
        ZStack {
            // CameraView is a UIViewRepresentable that provides the live camera
            // and forwards frames to the recognizer via frameHandler.
            CameraView(frameHandler: recognizer.handleSampleBuffer)
                .edgesIgnoringSafeArea(.all)

            // OverlayView draws boxes and translated text over the camera preview.
            // For now we synchronously call translator.translate for each observation.
            // In production you may want to run translation async and cache results.
            OverlayView(observations: recognizer.observations, translations: recognizer.observations.map { obs in
                translator.translate(text: obs.string)
            })
        }
        .onAppear {
            // Start recognition when view appears.
            recognizer.start()
        }
        .onDisappear {
            // Stop recognition to free camera/CPU when leaving the view.
            recognizer.stop()
        }
    }
}
