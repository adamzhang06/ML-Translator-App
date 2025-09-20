import SwiftUI
import AVFoundation

// UIViewRepresentable wrapper to use AVFoundation camera in SwiftUI.
// This component provides raw camera frames through a frameHandler closure so
// other components (for example Vision OCR or face detection) can process them.
struct CameraView: UIViewRepresentable {
    // frameHandler receives CMSampleBuffer frames from AVCaptureVideoDataOutput.
    let frameHandler: (CMSampleBuffer) -> Void

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        // Set the coordinator as the delegate to receive frames.
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(frameHandler: frameHandler)
    }

    // Coordinator bridges the SwiftUI view to the UIKit delegate pattern.
    class Coordinator: NSObject, CameraPreviewDelegate {
        let frameHandler: (CMSampleBuffer) -> Void
        init(frameHandler: @escaping (CMSampleBuffer) -> Void) {
            self.frameHandler = frameHandler
        }
        func didCapture(sampleBuffer: CMSampleBuffer) {
            // Forward frames to the provided handler (TextRecognizer in our app).
            frameHandler(sampleBuffer)
        }
    }
}

// Protocol used by the CameraPreviewView to deliver captured frames.
protocol CameraPreviewDelegate: AnyObject {
    func didCapture(sampleBuffer: CMSampleBuffer)
}

// UIKit view that sets up AVCaptureSession and outputs frames to a delegate.
class CameraPreviewView: UIView {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    weak var delegate: CameraPreviewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSession()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSession()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep preview layer matching the view bounds.
        previewLayer.frame = bounds
    }

    // Preview layer showing the camera output to the user.
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Choose the back wide-angle camera by default.
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        // Video data output provides CMSampleBuffer frames to a delegate queue.
        let queue = DispatchQueue(label: "camera.frame.queue")
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        // Attach preview layer so the user sees the camera feed.
        layer.addSublayer(previewLayer)
        session.commitConfiguration()
        session.startRunning()
    }
}

// Forward frames to the delegate. The delegate can run Vision requests or other processing.
extension CameraPreviewView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.didCapture(sampleBuffer: sampleBuffer)
    }
}
