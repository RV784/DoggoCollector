//
//  DogPhoto.swift
//  DoggoCollector
//
//  Decodes CaughtDog/attachment photo data at (no larger than) the size a
//  view actually displays, via ImageIO thumbnailing — the full-resolution
//  bitmap is never materialized. All UI decode sites go through this; plain
//  `UIImage(data:)` on stored photo data is banned, since a full decode of
//  even a correctly-cropped ~1080px photo at a 34pt avatar is wasteful, and
//  a full decode of one of the oversized photos stored before the
//  croppedToSquare() scale fix (see CameraViewModel.swift) is what caused
//  the app's jetsam memory kills (see memory_crash_fixes.md).
//

import ImageIO
import UIKit

enum DogPhoto {
    /// Pixel budgets for the app's display contexts (device points x 3).
    enum Size: CGFloat {
        case avatar = 128    // 34-56pt circles: TodaysCare, Wards, PastWards
        case tile   = 600    // half-width Pack grid tiles
        case card   = 1200   // full-width card: detail, celebration, share
        case thumb  = 320    // medical-record strip thumbnails
        case document = 2048 // medical-record photo attachments
    }

    private static let cache = NSCache<NSString, UIImage>()

    static func image(from data: Data?, size: Size, cacheKey: String? = nil) -> UIImage? {
        guard let data else { return nil }
        let key = cacheKey.map { "\($0)-\(size.rawValue)" as NSString }
        if let key, let hit = cache.object(forKey: key) { return hit }
        guard let source = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honors EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: size.rawValue,
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        let image = UIImage(cgImage: cg)
        if let key { cache.setObject(image, forKey: key) }
        return image
    }

    /// Drops any cached decodes for a dog whose stored photo just changed
    /// (e.g. PhotoStoreRepair rewriting `imageData`) so a stale bitmap at
    /// the old pixel dimensions doesn't linger under the same cache key.
    static func evict(id: String) {
        for size: Size in [.avatar, .tile, .card, .thumb, .document] {
            cache.removeObject(forKey: "\(id)-\(size.rawValue)" as NSString)
        }
    }
}
