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

        let location = await locationProvider.currentLocation()
        let coarse: CoarseLocation
        if let location {
            coarse = await locationTagger.tag(location)
        } else {
            coarse = CoarseLocation(label: "Somewhere nearby", latitude: 0, longitude: 0)
        }

        let generated = CatchNameGenerator.generate()
        let serialCount = (try? modelContext.fetchCount(FetchDescriptor<CaughtDog>())) ?? 0

        let dog = CaughtDog(
            name: generated.name,
            breedLabel: generated.breedLabel,
            traits: generated.traits,
            imageData: finalImage.jpegData(compressionQuality: 0.85),
            locationLabel: coarse.label,
            latitude: coarse.latitude,
            longitude: coarse.longitude,
            serialNumber: serialCount + 1
        )
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
