//
//  CoreMLBreedClassifier.swift
//  DoggoCollector
//
//  Real breed classification via a Core ML model trained on Stanford Dogs
//  (see training/train_breed_classifier.swift) — mirrors DogDetector's shape
//  exactly (withCheckedContinuation, VNImageRequestHandler(cgImage:orientation:),
//  do/catch → nil).
//
//  Requires DoggoCollector/Core/Detection/BreedClassifier.mlmodel to exist
//  in the project (auto-included by the synchronized group, no pbxproj edit
//  needed) — Xcode compiles it and generates the `BreedClassifier` Swift
//  class this file references. Run training/train_breed_classifier.swift
//  first if that class doesn't resolve.
//

import CoreGraphics
import Vision

final class CoreMLBreedClassifier: BreedClassifying {
    private static let uncertainLabel = "mixed_or_uncertain"
    /// The product decision — tune after seeing real classifier results.
    /// Enforced here, at the classifier layer, so callers never see an
    /// unconditional top-1: below this, the result is honestly reported as
    /// "mixed_or_uncertain" ("Indie mix") rather than a shaky specific breed.
    private static let confidenceThreshold: Double = 0.65

    private static let visionModel: VNCoreMLModel? = {
        do {
            let model = try BreedClassifier(configuration: MLModelConfiguration()).model
            return try VNCoreMLModel(for: model)
        } catch {
            return nil
        }
    }()

    func classify(_ image: CGImage) async -> BreedResult? {
        guard let visionModel = Self.visionModel else { return nil }

        return await withCheckedContinuation { continuation in
            // Guards against a real, observed crash: "SWIFT TASK CONTINUATION
            // MISUSE — tried to resume its continuation more than once."
            // VNCoreMLRequest's completion handler fired twice for a single
            // request here — first reproduced right after CameraViewModel
            // briefly ran this concurrently with DogDetector's own Vision
            // request over the same CGImage (since reverted back to
            // sequential there as a precaution), but the double-fire wasn't
            // proven to require that concurrency — this model is a two-stage
            // Core ML *pipeline* (ImageFeaturePrint -> LogisticRegressionClassifier,
            // see CLAUDE.md Known Issue #16), and pipeline models may simply
            // have different completion-handler semantics than the
            // single-stage MLImageClassifier export this app used before.
            // A checked continuation traps immediately on a second resume,
            // so this guard is real hardening either way, not theoretical.
            let resumeLock = NSLock()
            var didResume = false
            func resumeOnce(_ result: BreedResult?) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: result)
            }

            let request = VNCoreMLRequest(model: visionModel) { request, _ in
                guard let results = request.results as? [VNClassificationObservation],
                      let top = results.first else {
                    resumeOnce(nil)
                    return
                }
                let confidence = Double(top.confidence)
                if confidence < Self.confidenceThreshold {
                    resumeOnce(BreedResult(breedName: Self.uncertainLabel, confidence: confidence))
                } else {
                    resumeOnce(BreedResult(breedName: top.identifier, confidence: confidence))
                }
            }
            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                resumeOnce(nil)
            }
        }
    }
}
