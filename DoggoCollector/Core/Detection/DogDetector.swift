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
            // Same resume-once guard as CoreMLBreedClassifier.classify —
            // see that file's comment for the real crash this prevents
            // ("SWIFT TASK CONTINUATION MISUSE — tried to resume its
            // continuation more than once"); this sibling uses the
            // identical VNImageRequestHandler + single-continuation shape,
            // so it's equally exposed even though it wasn't the one that
            // actually crashed.
            let resumeLock = NSLock()
            var didResume = false
            func resumeOnce(_ result: Bool) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: result)
            }

            let request = VNRecognizeAnimalsRequest { request, _ in
                guard let results = request.results as? [VNRecognizedObjectObservation] else {
                    resumeOnce(false)
                    return
                }
                let threshold = self.confidenceThreshold
                let hasDog = results.contains { observation in
                    observation.labels.contains { $0.identifier == "Dog" && $0.confidence >= threshold }
                }
                resumeOnce(hasDog)
            }

            let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                resumeOnce(false)
            }
        }
    }
}
