//
//  SubjectCutout.swift
//  DoggoCollector
//
//  The poster hero's cutout — the real thing, via Vision's
//  VNGenerateForegroundInstanceMaskRequest (iOS 17+). Lifts the dog off its
//  background so it floats in the poster's soft bloom.
//
//  Mirrors DogDetector's Vision idiom (VNImageRequestHandler +
//  withCheckedContinuation + a resume-once guard), and runs the heavy request
//  off the main thread. Returns nil when no subject is found or the request
//  fails — the caller then falls back to the photo-led layout, exactly as the
//  spec intends ("photo-led … selected automatically when the subject mask
//  confidence is low"). The mask genuinely fails on dark dogs at night and on
//  two dogs in one frame, so nil is an expected, handled outcome, not an error.
//

import Vision
import UIKit
import CoreImage

enum SubjectCutout {
    /// A masked cutout (subject on a transparent background), or nil to use
    /// the photo-led layout. `coverage` is the fraction of the cropped frame
    /// the subject fills — a rough confidence the caller can use to prefer
    /// photo-led on a suspiciously thin/huge mask.
    struct Result {
        let image: UIImage
        let coverage: Double
    }

    static func cutout(from image: UIImage) async -> Result? {
        guard let cg = image.cgImage else { return nil }
        let orientation = image.imageOrientation.cgOrientation
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var didResume = false
            func resume(_ value: Result?) {
                lock.lock(); defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation)
                do {
                    try handler.perform([request])
                    guard let result = request.results?.first,
                          !result.allInstances.isEmpty else {
                        resume(nil); return
                    }
                    let buffer = try result.generateMaskedImage(
                        ofInstances: result.allInstances,
                        from: handler,
                        croppedToInstancesExtent: true)
                    guard let hard = Self.makeUIImage(from: buffer) else { resume(nil); return }
                    // Soften the hard mask edge so the subject doesn't read as a
                    // paper cut-out — the poster's cutout should feel airbrushed
                    // onto the ground.
                    let softened = Self.feathered(hard) ?? hard
                    let coverage = Self.coverage(of: result, handler: handler)
                    resume(Result(image: softened, coverage: coverage))
                } catch {
                    resume(nil)
                }
            }
        }
    }

    /// Feathers the alpha edge of a hard cutout so the silhouette fades softly
    /// instead of a razor cut. Extracts the alpha as a grayscale mask, blurs
    /// it, and re-composites the sharp subject through the soft mask.
    private static func feathered(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let radius = max(3.0, Double(min(cg.width, cg.height)) * 0.01)

        // alpha → opaque grayscale mask (white = subject)
        let mask = ci.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        let softMask = mask.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: ci.extent)
        let clear = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: ci.extent)
        guard let out = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: ci,
            kCIInputBackgroundImageKey: clear,
            kCIInputMaskImageKey: softMask
        ])?.outputImage else { return nil }

        let ctx = CIContext(options: nil)
        guard let outCG = ctx.createCGImage(out, from: ci.extent) else { return nil }
        return UIImage(cgImage: outCG)
    }

    private static func makeUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext(options: nil)
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Mean of the scaled instance mask (0…1) — the share of the frame the
    /// subject occupies. Best-effort; returns 1 if it can't be measured.
    private static func coverage(of result: VNInstanceMaskObservation, handler: VNImageRequestHandler) -> Double {
        guard let mask = try? result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler) else { return 1 }
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return 1 }
        let w = CVPixelBufferGetWidth(mask)
        let h = CVPixelBufferGetHeight(mask)
        let stride = CVPixelBufferGetBytesPerRow(mask)
        let ptr = base.assumingMemoryBound(to: Float32.self)
        let bytesPerPixel = stride / max(w, 1)
        // Only handle the common 32-bit float single-channel mask; otherwise 1.
        guard bytesPerPixel >= 4 else { return 1 }
        var sum: Double = 0
        let step = max(1, h / 64)   // sample rows for speed
        var rows = 0
        var y = 0
        while y < h {
            let rowPtr = ptr.advanced(by: (y * stride) / 4)
            var rowSum: Double = 0
            let colStep = max(1, w / 64)
            var x = 0, cols = 0
            while x < w {
                rowSum += Double(rowPtr[x]); x += colStep; cols += 1
            }
            sum += rowSum / Double(max(cols, 1))
            rows += 1
            y += step
        }
        return min(1, max(0, sum / Double(max(rows, 1))))
    }
}

private extension UIImage.Orientation {
    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
