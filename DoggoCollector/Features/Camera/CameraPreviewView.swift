//
//  CameraPreviewView.swift
//  DoggoCollector
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        // Attach the session on the NEXT runloop turn, never synchronously in
        // this layout pass. -[AVCaptureVideoPreviewLayer setSession:] spins a
        // nested CFRunLoop to build the capture graph; doing that inline during
        // the camera-panel morph pumps a queued touch back into SwiftUI while
        // it's mid-graph-update, fatally re-entering AttributeGraph (crash on
        // tapping "Catch a doggo"). Deferring moves the runloop spin out of theZ
        // current update transaction. Keep this deferred.
        let session = session
        DispatchQueue.main.async {
            view.videoPreviewLayer.session = session
        }
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
