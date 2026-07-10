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

    func start() async {
        locationProvider.requestAuthorization()
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
        try? await Task.sleep(for: .milliseconds(180))

        let capturedImage = await cameraService.capturePhoto()
        let hasDog: Bool
        let finalImage: UIImage

        if let capturedImage, let cgImage = capturedImage.cgImage {
            hasDog = await dogDetector.detectSubject(in: cgImage)
            finalImage = capturedImage
        } else if let fallback = Self.simulatorFallbackImage() {
            // No real camera available (Simulator) — treat as a successful
            // catch so the rest of the flow can still be exercised end-to-end.
            hasDog = true
            finalImage = fallback
        } else {
            hasDog = false
            finalImage = UIImage()
        }

        guard hasDog else {
            lastCatchFailed = true
            return nil
        }

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
        if let cgImage = finalImage.cgImage {
            breed = await breedClassifier.classify(cgImage)
        }

        let location = await locationProvider.currentLocation()
        let coarse: CoarseLocation
        if let location {
            coarse = await locationTagger.tag(location)
        } else {
            coarse = CoarseLocation(label: "Somewhere nearby", latitude: 0, longitude: 0)
        }

        let generated = CatchNameGenerator.generate()
        let serialCount = (try? modelContext.fetchCount(FetchDescriptor<CaughtDog>())) ?? 0

        // Cropped to a square here, once, at the source — matching the
        // camera's square viewfinder — so every downstream display of a
        // caught dog's photo (grid cards, card detail, share, wards list)
        // is already consistent instead of each screen picking its own crop.
        let dog = CaughtDog(
            name: generated.name,
            // Classifier fallback is the old whimsical label — graceful
            // degradation matching the project's mock-fallback pattern,
            // e.g. if the model is missing or Vision throws.
            breedLabel: breed?.displayName ?? generated.breedLabel,
            traits: generated.traits,
            imageData: finalImage.croppedToSquare().jpegData(compressionQuality: 0.85),
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
    /// Center-crops to a square. `UIGraphicsImageRenderer` + `draw(at:)`
    /// (rather than slicing the underlying `CGImage` directly) so the
    /// image's own `imageOrientation` is respected automatically.
    func croppedToSquare() -> UIImage {
        let side = min(size.width, size.height)
        let origin = CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            draw(at: origin)
        }
    }
}
