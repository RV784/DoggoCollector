//
//  CameraService.swift
//  DoggoCollector
//
//  Thin AVCaptureSession wrapper. Live-capture-only by design (no photo
//  library picker) — this is both the playful "point your camera at a real
//  dog" interaction and the app's basic anti-spoof floor for v1.
//

// AVCapturePhotoSettings (not Sendable) is deliberately passed across the
// session-queue boundary in capturePhoto(liveMovie:) so its uniqueID stays
// identical to the key registered in movieContinuationsByID — a safe,
// standard AVFoundation usage pattern the framework just hasn't been
// audited as Sendable for yet.
@preconcurrency import AVFoundation
import CoreMedia
import UIKit

/// A still photo plus a promise for its trailing live-photo movie (if one
/// was requested). `movie` resolves independently of `still` — awaiting it
/// never blocks the caller, since a live-photo movie keeps recording for
/// ~1.5s after the shutter and only finishes processing after that.
struct CaptureResult {
    let still: UIImage
    let movie: Task<LivePhotoMovie?, Never>?
}

/// The raw movie file AVFoundation wrote (not yet transcoded/stored) plus
/// the timestamp within it that corresponds to the still photo moment —
/// needed by the eventual transcoder to stamp Live Photo pairing metadata.
struct LivePhotoMovie {
    let url: URL
    let photoDisplayTime: CMTime
}

/// Zoom capability + display-label info for the active device, computed
/// once at session-config time. `displayMultiplier` converts a raw
/// `videoZoomFactor` to the Apple-style number the user expects to see —
/// e.g. on a dual-wide rig, raw 1.0 (the ultra-wide) displays as "0.5",
/// and raw 2.0 (the wide switch-over point) displays as "1". In practice
/// this multiplier is a fixed per-rig optical ratio (0.5 for an
/// ultra-wide-relative virtual device, 1.0 for a single physical camera),
/// not something that needs re-reading per zoom level — see
/// `displayValue(for:)`.
struct ZoomContext {
    var minFactor: CGFloat
    var maxFactor: CGFloat
    /// Raw `videoZoomFactor` values to render as chips — `[1.0] +`
    /// the device's own switch-over factors on a multi-camera rig, or a
    /// `[1.0, 2.0]` ("2x" = digital) fallback on single-camera hardware,
    /// where that array is empty.
    var anchorFactors: [CGFloat]
    var displayMultiplier: CGFloat

    func displayValue(for rawFactor: CGFloat) -> CGFloat {
        rawFactor * displayMultiplier
    }
}

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
    /// Whether this device/preset combination can capture Live Photos —
    /// checked once at session config time (mirrors `hasCameraInput`'s
    /// write-once pattern). Lets the view hide the Live Photo toggle
    /// entirely on unsupported hardware and the Simulator (no camera at
    /// all there, so this stays false).
    nonisolated(unsafe) private(set) var isLivePhotoCaptureSupported = false
    /// The physical/virtual device actually attached — needed for zoom
    /// control. Written once during config on the session queue, read
    /// afterward from gesture/button call sites on the main actor (same
    /// cross-context shape as `hasCameraInput`).
    nonisolated(unsafe) private(set) var activeDevice: AVCaptureDevice?
    nonisolated(unsafe) private(set) var zoomContext: ZoomContext?
    /// Last-requested raw `videoZoomFactor` — written synchronously by
    /// `setZoomFactor` (before the actual hardware mutation is dispatched
    /// to the session queue) and once by `configureZoom` at session setup,
    /// so pinch-gesture code always has an up-to-date anchor to read
    /// without waiting on the session queue.
    nonisolated(unsafe) private(set) var currentZoomFactor: CGFloat = 1.0
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.doggocollector.camera.session")
    // AVCapturePhotoOutput invokes its delegate on "a common dispatch
    // queue — not necessarily the main queue" (verified against this
    // SDK's own header doc), so every property below is guarded by this
    // one lock rather than assumed-confined to sessionQueue.
    private let continuationLock = NSLock()
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    /// Keyed by the originating `AVCapturePhotoSettings.uniqueID` (mirrored
    /// onto the `AVCaptureResolvedPhotoSettings` the delegate receives) —
    /// a still can resolve well before its trailing movie finishes
    /// processing, so a second capture (with its own movie) can
    /// legitimately start while the first movie is still in flight. A
    /// single shared continuation slot (photoContinuation's shape) would
    /// let two overlapping movies cross-wire onto the wrong catch.
    private var movieContinuationsByID: [Int64: AsyncStream<LivePhotoMovie?>.Continuation] = [:]
    /// Movies still recording/processing — `stop()` must not tear down the
    /// session while this is nonzero (would truncate/abort them).
    private var pendingLivePhotoMovies = 0
    private var wantsStop = false

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

    /// If a live-photo movie is still recording/processing, defers the
    /// actual `stopRunning()` until it clears (via `finishMovie`) rather
    /// than truncating it — see `finishMovie`/`forceStopIfStillWanted`.
    func stop() {
        continuationLock.lock()
        if pendingLivePhotoMovies > 0 {
            wantsStop = true
            continuationLock.unlock()
            // Belt-and-braces: a delegate callback that never arrives (app
            // backgrounded mid-processing, a rare AVFoundation hiccup)
            // must not leave the capture session running forever once the
            // panel is gone. A no-op if the movie finishes normally first
            // (wantsStop is already false by then).
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.forceStopIfStillWanted()
            }
            return
        }
        continuationLock.unlock()
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    private func forceStopIfStillWanted() {
        continuationLock.lock()
        let shouldForceStop = wantsStop
        wantsStop = false
        continuationLock.unlock()
        guard shouldForceStop else { return }
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    /// Whistles, captures a still, and — if `liveMovie` is true and the
    /// hardware supports it — kicks off a trailing Live Photo movie
    /// alongside it. Returns once the still is ready; `CaptureResult.movie`
    /// is a separate promise the caller can await independently, since the
    /// movie keeps recording for ~1.5s after the shutter and finishes
    /// processing after that (never blocks the still).
    @MainActor
    func capturePhoto(liveMovie: Bool) async -> CaptureResult? {
        guard hasCameraInput else { return nil }

        let wantsMovie = liveMovie && isLivePhotoCaptureSupported
        let movieURL = wantsMovie ? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov") : nil

        var movieTask: Task<LivePhotoMovie?, Never>?

        let still: UIImage? = await withCheckedContinuation { continuation in
            continuationLock.lock()
            let alreadyPending = photoContinuation != nil
            if !alreadyPending { photoContinuation = continuation }
            continuationLock.unlock()

            guard !alreadyPending else {
                // A capture is already in flight — refuse rather than
                // silently overwrite and leak the first caller's
                // continuation (the same continuation-hygiene bug class
                // already fixed in LocationProvider and
                // CoreMLBreedClassifier; see memory_crash_fixes.md). The
                // shutter is disabled while capturing, so this guards a
                // theoretical race, not an observed live crash. No movie
                // continuation is ever registered on this path, so
                // there's nothing else to clean up.
                continuation.resume(returning: nil)
                return
            }

            let settings = AVCapturePhotoSettings()
            if let movieURL {
                settings.livePhotoMovieFileURL = movieURL
                if photoOutput.availableLivePhotoVideoCodecTypes.contains(.hevc) {
                    settings.livePhotoVideoCodecType = .hevc
                }
            }

            // Only now, having confirmed this call actually owns the
            // still slot, register the movie's own continuation — keyed
            // by uniqueID (see movieContinuationsByID's doc) rather than
            // a single shared slot.
            if wantsMovie {
                let (stream, streamContinuation) = AsyncStream<LivePhotoMovie?>.makeStream(bufferingPolicy: .bufferingNewest(1))
                continuationLock.lock()
                movieContinuationsByID[settings.uniqueID] = streamContinuation
                pendingLivePhotoMovies += 1
                continuationLock.unlock()
                movieTask = Task {
                    var iterator = stream.makeAsyncIterator()
                    return (await iterator.next()) ?? nil
                }
            }

            sessionQueue.async { [weak self] in
                guard let self, hasCameraInput else {
                    self?.resumeAndClearContinuation(with: nil)
                    self?.finishMovie(uniqueID: settings.uniqueID, with: nil)
                    return
                }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }

        guard let still else { return nil }
        return CaptureResult(still: still, movie: movieTask)
    }

    /// Takes the pending continuation (under lock, at most once) and
    /// resumes it — used by both the "no camera input" early-out and the
    /// capture delegate callback, so a continuation can never be resumed
    /// twice even if AVFoundation were to double-fire the delegate (a
    /// checked continuation traps immediately and uncatchably on a second
    /// resume).
    private func resumeAndClearContinuation(with image: UIImage?) {
        continuationLock.lock()
        let continuation = photoContinuation
        photoContinuation = nil
        continuationLock.unlock()
        continuation?.resume(returning: image)
    }

    /// Resolves (and removes) the movie continuation for a given settings
    /// uniqueID, if one is registered, and decrements the pending-movie
    /// counter `stop()` waits on. Used by both the real "movie finished
    /// processing" delegate callback and the early-exit "no camera input"
    /// cleanup path, so a registered continuation/counter increment is
    /// never left dangling regardless of how a capture actually concludes.
    private func finishMovie(uniqueID: Int64, with movie: LivePhotoMovie?) {
        continuationLock.lock()
        let continuation = movieContinuationsByID.removeValue(forKey: uniqueID)
        let hadContinuation = continuation != nil
        continuationLock.unlock()
        continuation?.yield(movie)
        continuation?.finish()
        guard hadContinuation else { return }

        continuationLock.lock()
        pendingLivePhotoMovies = max(0, pendingLivePhotoMovies - 1)
        let shouldStop = wantsStop && pendingLivePhotoMovies == 0
        if shouldStop { wantsStop = false }
        continuationLock.unlock()
        guard shouldStop else { return }
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
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

        // Triple > dual-wide > dual > single-wide preference chain — the
        // device selection that makes 0.5x/tele zoom possible at all.
        // Falls through to the plain wide-angle camera (the only case
        // verified on "Rajat's iPhone 17e", a single-rear-camera phone,
        // where every virtual-device lookup returns nil) exactly as before.
        let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        if let device, let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            hasCameraInput = true
            activeDevice = device
            configureZoom(for: device)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            // Live Photo capture requires this disruptive pipeline
            // reconfiguration to happen once, before startRunning — flipping
            // it mid-session is documented as unsupported. The per-shot
            // on/off choice is made later, by whether a given
            // AVCapturePhotoSettings carries a livePhotoMovieFileURL, never
            // by touching this flag again.
            if photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = true
                isLivePhotoCaptureSupported = true
            }
        }

        session.commitConfiguration()
    }

    /// Builds `zoomContext` and opens the camera at the "1x" the user
    /// expects. On a virtual (multi-camera) device, raw `videoZoomFactor
    /// == 1.0` is the *ultra-wide* camera — without this the panel would
    /// silently open zoomed out to 0.5x. Runs inside the same
    /// beginConfiguration/commitConfiguration transaction as addInput;
    /// `lockForConfiguration` on the device itself is a separate, nested
    /// lock and is safe to take here (a common AVFoundation pattern).
    private func configureZoom(for device: AVCaptureDevice) {
        let switchOverFactors = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        let anchors = switchOverFactors.isEmpty ? [1.0, 2.0] : ([1.0] + switchOverFactors).sorted()
        // A fixed per-rig optical ratio in practice (0.5 for an
        // ultra-wide-relative virtual device, 1.0 for a single physical
        // camera) — read once here, not re-read per anchor.
        let multiplier = device.displayVideoZoomFactorMultiplier
        let uiCapRawFactor = 6.0 / max(multiplier, 0.01)
        zoomContext = ZoomContext(
            minFactor: device.minAvailableVideoZoomFactor,
            maxFactor: min(device.maxAvailableVideoZoomFactor, uiCapRawFactor),
            anchorFactors: anchors,
            displayMultiplier: multiplier
        )

        // Open at the first switch-over factor (the *wide* camera) rather
        // than the virtual device's raw default of 1.0 (the ultra-wide).
        let initialFactor = switchOverFactors.first ?? 1.0
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = initialFactor
            device.unlockForConfiguration()
            currentZoomFactor = initialFactor
        } catch {
            currentZoomFactor = 1.0
        }
    }

    /// Clamped to the device's supported range (and a UI cap so nobody
    /// digitally zooms to 25x) before any hardware touch — both
    /// `rampToVideoZoomFactor` and an out-of-range `videoZoomFactor`
    /// assignment throw real Foundation exceptions
    /// (`NSGenericException`/`NSRangeException`) otherwise. `animated`
    /// ramps (chip taps); direct assignment for pinch tracking, which is
    /// already continuous and must not fight a ramp animation. Callers are
    /// responsible for not calling this mid-capture (would desync the
    /// still vs. the trailing live-photo movie frames).
    func setZoomFactor(_ rawFactor: CGFloat, animated: Bool) {
        guard let device = activeDevice, let context = zoomContext else { return }
        let clamped = min(max(rawFactor, context.minFactor), context.maxFactor)
        currentZoomFactor = clamped
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
            } catch {
                return
            }
            defer { device.unlockForConfiguration() }
            if animated {
                device.ramp(toVideoZoomFactor: clamped, withRate: 8)
            } else {
                device.videoZoomFactor = clamped
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            resumeAndClearContinuation(with: nil)
            return
        }
        resumeAndClearContinuation(with: image)
    }

    /// The movie file is fully written by the time this fires (unlike the
    /// earlier "eventual file" recording callback, which only means
    /// recording stopped — see the plan's §0 for that distinction). Not
    /// implementing that earlier callback: this app has no "Live" badge
    /// to dismiss (removed entirely — see the camera-revamp plan's scope).
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        let movie: LivePhotoMovie? = error == nil
            ? LivePhotoMovie(url: outputFileURL, photoDisplayTime: photoDisplayTime)
            : nil
        finishMovie(uniqueID: resolvedSettings.uniqueID, with: movie)
    }
}
