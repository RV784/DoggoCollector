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
            let request = VNCoreMLRequest(model: visionModel) { request, _ in
                guard let results = request.results as? [VNClassificationObservation],
                      let top = results.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let confidence = Double(top.confidence)
                if confidence < Self.confidenceThreshold {
                    continuation.resume(returning: BreedResult(breedName: Self.uncertainLabel, confidence: confidence))
                } else {
                    continuation.resume(returning: BreedResult(breedName: top.identifier, confidence: confidence))
                }
            }
            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
