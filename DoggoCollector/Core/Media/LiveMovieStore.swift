//
//  LiveMovieStore.swift
//  DoggoCollector
//
//  AVPlayer needs a file URL, but a caught dog's live-photo movie bytes
//  live in SwiftData (CaughtDog.livePhotoMovieData/livePhotoMovieTileData)
//  — mirrors DogPhoto's role for photos, materializing bytes to a
//  Caches-directory file on demand so playback never has to reason about
//  SwiftData directly. Caches/ is OS-purgeable and rebuilt from the
//  SwiftData bytes on the next request, so there are no cleanup
//  obligations on dog deletion.
//

import Foundation

enum LiveMovieStore {
    /// Which stored movie field a file corresponds to — `.tile` is the
    /// cheaper 360x360 transcode used by the Pack grid (decision #21's
    /// grid-tier addition); `.full` is the 720x720 one used by Card
    /// Detail/Celebration.
    enum Tier: String {
        case full, tile
    }

    private static var directory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveMovies", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(id: String, tier: Tier) -> URL {
        let name = tier == .full ? id : "\(id)-\(tier.rawValue)"
        return directory.appendingPathComponent(name).appendingPathExtension("mov")
    }

    /// Writes `data` to `Caches/LiveMovies/<id>[-tile].mov` if it isn't
    /// already there (or if the existing file's size doesn't match — a
    /// cheap staleness check; the stored movie data only ever changes via
    /// a deliberate patch/replace, never an in-place append), and returns
    /// the URL.
    static func url(for data: Data, id: String, tier: Tier = .full) -> URL? {
        let fileURL = fileURL(id: id, tier: tier)
        let existingSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.size] as? Int
        if existingSize == data.count {
            return fileURL
        }
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Removes both cached files (full + tile) for a dog whose movie data
    /// just changed — called from the catch-time deferred-patch task once
    /// a fresh transcode lands, so a stale cached movie never lingers
    /// under the same id.
    static func evict(id: String) {
        for tier: Tier in [.full, .tile] {
            try? FileManager.default.removeItem(at: fileURL(id: id, tier: tier))
        }
    }
}
