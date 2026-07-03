//
//  CameraService.swift
//  DoggoCollector
//
//  Thin AVCaptureSession wrapper. Live-capture-only by design (no photo
//  library picker) — this is both the playful "point your camera at a real
//  dog" interaction and the app's basic anti-spoof floor for v1.
//

import AVFoundation
import UIKit

@Observable
final class CameraService: NSObject {
    let session = AVCaptureSession()

    private(set) var isAuthorized = false
    /// Whether a real camera input was actually attached — false on the
    /// Simulator (no hardware). `AVCapturePhotoOutput.capturePhoto` crashes
    /// if called with no active connection, so this must be checked first.
    /// Written once from the session queue during setup, read afterward —
    /// `nonisolated(unsafe)` since it's never mutated concurrently with a read.
    nonisolated(unsafe) private(set) var hasCameraInput = false
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.doggocollector.camera.session")
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    func requestAccessAndConfigure() async {
        isAuthorized = await Self.requestAccess()
        guard isAuthorized else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                self?.configureSessionIfNeeded()
                self?.session.startRunning()
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    @MainActor
    func capturePhoto() async -> UIImage? {
        guard hasCameraInput else { return nil }
        return await withCheckedContinuation { continuation in
            photoContinuation = continuation
            sessionQueue.async { [weak self] in
                guard let self, hasCameraInput else {
                    continuation.resume(returning: nil)
                    return
                }
                let settings = AVCapturePhotoSettings()
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            hasCameraInput = true
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { photoContinuation = nil }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            photoContinuation?.resume(returning: nil)
            return
        }
        photoContinuation?.resume(returning: image)
    }
}
