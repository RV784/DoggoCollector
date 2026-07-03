//
//  DogDetector.swift
//  DoggoCollector
//
//  On-device detection via Vision's built-in animal recognizer — no
//  custom-trained model for v1, per the build spec's time budget. This only
//  confirms "a dog is in frame"; it can't identify breed, so card metadata
//  beyond that is generated rather than classified (see Mechanic/).
//

import Vision

final class DogDetector: SubjectDetecting {
    private let confidenceThreshold: Float = 0.6

    func detectSubject(in image: CGImage) async -> Bool {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeAnimalsRequest { request, _ in
                guard let results = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: false)
                    return
                }
                let threshold = self.confidenceThreshold
                let hasDog = results.contains { observation in
                    observation.labels.contains { $0.identifier == "Dog" && $0.confidence >= threshold }
                }
                continuation.resume(returning: hasDog)
            }

            let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
