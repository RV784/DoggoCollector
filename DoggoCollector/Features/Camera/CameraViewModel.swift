//
//  CameraViewModel.swift
//  DoggoCollector
//

import SwiftUI
import SwiftData

@Observable
final class CameraViewModel {
    private(set) var isCapturing = false
    private(set) var lastCatchFailed = false

    let cameraService = CameraService()
    private let dogDetector: SubjectDetecting = DogDetector()
    private let breedClassifier: BreedClassifying = CoreMLBreedClassifier()
    private let whistlePlayer = WhistlePlayer()
    private let locationProvider = LocationProvider()
    private let locationTagger = LocationTagger()

    /// Resolved while the user is still framing their shot, so a catch
    /// doesn't have to wait on GPS + reverse geocoding — by far the biggest
    /// latency contributor (`CLLocationManager.requestLocation()` with no
    /// cached fix routinely takes 1-10s on device). `attemptCatch` reads
    /// whatever's here at save time; if it's still nil, location tagging is
    /// deferred entirely rather than blocking the catch (see attemptCatch).
    private var prewarmedLocation: CoarseLocation?

    func start() async {
        locationProvider.requestAuthorization()
        Task { @MainActor [weak self] in
            guard let self, let location = await self.locationProvider.currentLocation() else { return }
            self.prewarmedLocation = await self.locationTagger.tag(location)
        }
        await cameraService.requestAccessAndConfigure()
    }

    func stop() {
        cameraService.stop()
    }

    func replayWhistle() {
        whistlePlayer.play()
    }

    /// Whistles, captures a frame, confirms a dog is present via `SubjectDetecting`,
    /// and saves a new catch. Returns nil (and sets `lastCatchFailed`) if no dog
    /// was found in the captured frame.
    func attemptCatch(in modelContext: ModelContext) async -> CaughtDog? {
        isCapturing = true
        defer { isCapturing = false }

        whistlePlayer.play()

        // Overlap the fixed 180ms whistle beat with the real AVCapture
        // round-trip instead of paying both serially.
        async let capturedImage = cameraService.capturePhoto()
        async let whistleSettled: Void = { try? await Task.sleep(for: .milliseconds(180)) }()
        let (photo, _) = await (capturedImage, whistleSettled)

        let hasDog: Bool
        let finalImage: UIImage
        // Runs on the Simulator placeholder too, not just real photos.
        // Verified live (macOS smoke test, not just assumed): a solid-color
        // placeholder does NOT reliably come back low-confidence — an
        // image classifier trained only on real dog photos has no "not a
        // dog" class to fall back to, so it confidently (>95%) picks
        // *some* breed for an out-of-distribution flat-color input. This
        // is a Simulator-testing-only quirk (a placeholder catch may show
        // an oddly specific, meaningless breed rather than "Indie mix"),
        // not a bug — real device photos classify sensibly either way.
        var breed: BreedResult?

        if let photo {
            // Crop+downscale immediately, before detection/classification —
            // the multi-hundred-MB full-res capture must not coexist with
            // Vision's working set, the classifier's working set, and a
            // JPEG encode buffer all at once. `photo` is released once this
            // scope's local reference goes away (see memory_crash_fixes.md).
            // This also means detection now judges the same square the app
            // stores/displays, which is arguably more honest than judging
            // the uncropped frame.
            let processed = photo.croppedToSquare()
            if let cgImage = processed.cgImage {
                // Detection and classification run sequentially, not
                // concurrently, deliberately — running two Vision requests
                // over the same CGImage at once (dogDetector + breedClassifier
                // both via `async let`) caused a real, reproduced crash:
                // Vision's VNCoreMLRequest completion handler fired more than
                // once, tripping Swift's "continuation resumed more than
                // once" trap inside CoreMLBreedClassifier.classify.
                // Classification is also skipped entirely when no dog is
                // detected, which is strictly better than the concurrent
                // version for the common miss case.
                hasDog = await dogDetector.detectSubject(in: cgImage)
                finalImage = processed
                if hasDog {
                    breed = await breedClassifier.classify(cgImage)
                }
            } else {
                hasDog = false
                finalImage = UIImage()
            }
        } else if let fallback = Self.simulatorFallbackImage() {
            // No real camera available (Simulator) — treat as a successful
            // catch so the rest of the flow can still be exercised end-to-end.
            let processed = fallback.croppedToSquare()
            hasDog = true
            finalImage = processed
            if let cgImage = processed.cgImage {
                breed = await breedClassifier.classify(cgImage)
            }
        } else {
            hasDog = false
            finalImage = UIImage()
        }

        guard hasDog else {
            lastCatchFailed = true
            return nil
        }

        // Location is off the critical path: use the pre-warmed fix if
        // start() already resolved one while the user was framing the
        // shot. If it's not ready yet, save now with the existing
        // "Somewhere nearby" placeholder and patch the real label in once
        // resolution finishes, instead of blocking the morph on it — the
        // celebration screen doesn't display location at all, only Card
        // Detail's caption does, so a few-seconds-late label is invisible
        // in practice. Same deferred-patch-after-save pattern as
        // GuardianPledgeSheet.assignNearestClinic().
        let coarse = prewarmedLocation ?? CoarseLocation(label: "Somewhere nearby", latitude: 0, longitude: 0)
        let needsLocationPatch = prewarmedLocation == nil

        let generated = CatchNameGenerator.generate()
        // With CloudKit sync (decision #18), two devices catching before
        // syncing can mint the same serialCount + 1 — accepted as a known
        // cross-device quirk rather than built around: this is cosmetic
        // display flavor ("#014 in your pack"), not identity — `id: UUID`
        // is the real, always-unique key everything else keys off of. Not
        // worth distributed-sequence machinery for a number nobody checks
        // for uniqueness.
        let serialCount = (try? modelContext.fetchCount(FetchDescriptor<CaughtDog>())) ?? 0

        // Cropped to a square (and downscaled, see croppedToSquare) already,
        // above, before detection ran — matching the camera's square
        // viewfinder — so every downstream display of a caught dog's photo
        // (grid cards, card detail, share, wards list) is already consistent
        // instead of each screen picking its own crop.
        let dog = CaughtDog(
            name: generated.name,
            // Classifier fallback is the old whimsical label — graceful
            // degradation matching the project's mock-fallback pattern,
            // e.g. if the model is missing or Vision throws.
            breedLabel: breed?.displayName ?? generated.breedLabel,
            traits: generated.traits,
            imageData: finalImage.jpegData(compressionQuality: 0.85),
            locationLabel: coarse.label,
            latitude: coarse.latitude,
            longitude: coarse.longitude,
            serialNumber: serialCount + 1
        )
        dog.classifiedBreedRaw = breed?.breedName
        dog.breedConfidence = breed?.confidence
        modelContext.insert(dog)
        try? modelContext.save()
        lastCatchFailed = false

        if needsLocationPatch {
            Task { @MainActor [locationProvider, locationTagger] in
                guard let location = await locationProvider.currentLocation() else { return }
                let resolved = await locationTagger.tag(location)
                // Only overwrite the placeholder — the user may have
                // renamed/edited the dog, or a second catch may already be
                // in flight, and this shouldn't clobber either.
                guard dog.locationLabel == "Somewhere nearby" else { return }
                dog.locationLabel = resolved.label
                dog.latitude = resolved.latitude
                dog.longitude = resolved.longitude
            }
        }

        return dog
    }

    private static func simulatorFallbackImage() -> UIImage? {
        #if targetEnvironment(simulator)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 640))
        return renderer.image { _ in
            UIColor(DoggoColor.sky).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 640, height: 640))
        }
        #else
        return nil
        #endif
    }
}

private extension UIImage {
    /// Center-crops to a square and caps the output at `maxSide` pixels.
    /// `UIGraphicsImageRenderer` + `draw(in:)` (rather than slicing the
    /// underlying `CGImage` directly) so the image's own `imageOrientation`
    /// is respected automatically. The renderer format's scale is pinned to
    /// 1 — the default is the device's screen scale (3x on most iPhones),
    /// which silently tripled the stored photo's dimensions (a 3024pt
    /// square became 9072x9072px, ~82MP) and was the root cause of
    /// app-wide jetsam memory kills (see memory_crash_fixes.md).
    func croppedToSquare(maxSide: CGFloat = 1080) -> UIImage {
        let side = min(size.width, size.height)
        let outSide = min(side, maxSide)
        let scaleFactor = outSide / side
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outSide, height: outSide), format: format)
        return renderer.image { _ in
            let drawSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
            let origin = CGPoint(x: (outSide - drawSize.width) / 2, y: (outSide - drawSize.height) / 2)
            draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
