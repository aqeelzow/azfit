import AVFoundation
import SwiftUI
import UIKit

/// The back camera for meal photos. AVFoundation wants its session started, stopped and used off the main thread,
/// so everything here runs on one serial queue.
nonisolated final class MealCamera: NSObject, @unchecked Sendable {
    enum Problem: Sendable { case denied, unavailable }

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "azfit.meal-camera")
    private var configured = false
    private var pending: CheckedContinuation<Data?, Never>?

    /// Asks for the camera the first time, then starts the preview. Nil when it's running.
    func start() async -> Problem? {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { return .denied }
        default: return .denied
        }
        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.run() ? nil : .unavailable) }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    /// The photo's file data (a JPEG), or nil if the camera couldn't take one.
    func capture(flash: Bool) async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.pending == nil, self.session.isRunning else { return continuation.resume(returning: nil) }
                self.pending = continuation
                let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                if flash, self.output.supportedFlashModes.contains(.on) { settings.flashMode = .on }
                self.output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func run() -> Bool {
        if !configured {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device)
            else { return false }
            session.beginConfiguration()
            session.sessionPreset = .photo
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                return false
            }
            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()
            configured = true
        }
        if !session.isRunning { session.startRunning() }
        return true
    }
}

nonisolated extension MealCamera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        queue.async {
            self.pending?.resume(returning: data)
            self.pending = nil
        }
    }
}

/// What the camera sees, filling its frame.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.preview.session = session
        view.preview.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // The layer is always the class above.
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
