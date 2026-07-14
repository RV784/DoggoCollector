//
//  PhotoStoreRepair.swift
//  DoggoCollector
//
//  One-shot normalization of stored catch photos to ~1080px — repairs
//  catches made while croppedToSquare() rendered at 3x screen scale
//  (~82MP stored JPEGs, the root cause of the app's jetsam memory kills,
//  see memory_crash_fixes.md). Idempotent and cheap when there's nothing
//  to do: reads only the JPEG header (no decode) to check dimensions, so a
//  repaired store costs a launch-time header read per dog, not a decode.
//

import SwiftData
import UIKit
import ImageIO

@MainActor
enum PhotoStoreRepair {
    /// Anything already at or under this doesn't need re-encoding — well
    /// above DogPhoto's largest display budget (.card = 1200px), so a
    /// correctly-sized photo is never needlessly touched.
    private static let maxAcceptableSide: CGFloat = 1440

    static func run(dogs: [CaughtDog], context: ModelContext) async {
        var repaired = 0
        for dog in dogs {
            guard let data = dog.imageData, pixelSide(of: data) > maxAcceptableSide else { continue }
            autoreleasepool {
                if let small = DogPhoto.image(from: data, size: .card),
                   let jpeg = small.jpegData(compressionQuality: 0.85) {
                    dog.imageData = jpeg
                    DogPhoto.evict(id: dog.id.uuidString)
                    repaired += 1
                }
            }
            await Task.yield() // keep the main actor breathing between dogs
        }
        if repaired > 0 { try? context.save() }
    }

    /// Header-only dimension read (kCGImageSourceShouldCache false, no
    /// decode) — cheap enough to run on every stored photo at every launch.
    private static func pixelSide(of data: Data) -> CGFloat {
        guard let source = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else { return 0 }
        return max(width, height)
    }
}
