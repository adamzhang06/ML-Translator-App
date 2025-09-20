Swift iOS Starter: Camera OCR + Simple Translation

What this provides
- Minimal SwiftUI starter app scaffold (no Xcode project file). Use the files in Xcode to create a new project and add these files.
- Camera preview using AVFoundation.
- Vision OCR integration (VNRecognizeTextRequest) to detect text and bounding boxes.
- Simple overlay layer that draws boxes and translated text.
- A small JSON-based local dictionary for English <-> Chinese translations as an example.

How to use
1. In Xcode create a new iOS app (App lifecycle: SwiftUI). Set language to Swift.
2. Add the Swift files from this folder to the Xcode project.
3. Add Privacy - Camera Usage Description to Info.plist with a suitable message.
4. Build and run on a real device (Vision OCR requires device; simulator has limited camera support).

Notes
- This starter uses a small local JSON dictionary for translation. Replace with a proper database or on-device ML translator later.
- Face captioning: the code is structured so you can add Vision face detection and overlay face labels, then pass the label through the same translation pipeline.

Files to add to your Xcode project:
- CameraView.swift
- TextRecognizer.swift
- TranslationStore.swift
- OverlayView.swift
- StarterApp.swift

Next steps I can do for you
- Create a working Xcode project (.xcodeproj) and wire the files.
- Add a Core ML translation model example or integrate an online translation API.
- Add face detection and captioning features.
