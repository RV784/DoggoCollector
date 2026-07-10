//
//  BreedClassifying.swift
//  DoggoCollector
//
//  The breed-guess seam, sibling to SubjectDetecting rather than a
//  replacement for it — SubjectDetecting only confirms "a dog is here",
//  this identifies which one. Input is CGImage (not CVPixelBuffer) to match
//  the CGImage already in hand at the catch-time hook point in
//  CameraViewModel, and the existing VNImageRequestHandler(cgImage:) pattern
//  DogDetector already uses.
//

import CoreGraphics

struct BreedResult {
    /// Cleaned display label from the classifier's class folders (e.g.
    /// "German Shepherd"), or "mixed_or_uncertain" — a valid classification
    /// outcome, not an error case.
    let breedName: String
    let confidence: Double

    /// "mixed_or_uncertain" reads as "Indie mix" everywhere in the UI — the
    /// app's existing first-class street-dog framing (see CLAUDE.md decision
    /// #8), not a fallback string.
    var displayName: String {
        breedName == "mixed_or_uncertain" ? "Indie mix" : breedName
    }
}

protocol BreedClassifying {
    /// Returns nil only on total failure (model missing / Vision error) so
    /// callers can fall back gracefully. A low-confidence real result is
    /// still a value — BreedResult(breedName: "mixed_or_uncertain", ...) —
    /// not nil; the threshold is enforced by the conformance, not the caller.
    func classify(_ image: CGImage) async -> BreedResult?
}
