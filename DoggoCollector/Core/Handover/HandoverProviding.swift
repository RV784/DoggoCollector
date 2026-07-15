//
//  HandoverProviding.swift
//  DoggoCollector
//
//  The seam for Guardian Handover (decision #18), matching the project's
//  established backend-swap pattern (AuthProviding, CarePlaceProviding,
//  etc.) — CloudKitHandoverProvider is the only conformance today, but the
//  seam exists so the mechanism could change without touching call sites.
//

import Foundation
import CloudKit

enum HandoverError: Error {
    /// The share's root record couldn't be fetched or decoded on accept.
    case invalidPackage
}

/// What the recipient gets back after accepting an invite: the Codable
/// snapshot plus the binary blobs that rode alongside it as CKAssets
/// (never embedded in the JSON payload itself).
struct HandoverAcceptance {
    let package: HandoverPackage
    let photoData: Data?
    /// The transcoded live-photo movie companion, if the ward had one —
    /// nil for wards pledged before that feature existed, or wherever the
    /// toggle was off. Same "just another optional CKAsset" treatment as
    /// `photoData`, not tracked as a presence flag in `HandoverPackage`.
    let movieData: Data?
    /// The cheaper Pack-grid tier of the same movie (decision #21's
    /// grid-tier addition) — carried separately since the recipient's own
    /// Pack grid needs it too, not just their Card Detail/Celebration.
    let movieTileData: Data?
    /// Keyed by `MedicalAttachmentSnapshot.assetFieldKey`, not by array
    /// position — see HandoverPackage's own note on why.
    let attachmentData: [String: Data]
}

protocol HandoverProviding {
    /// Sender side: snapshots the dog, saves it as a shared CKRecord, and
    /// returns the invite URL to send however the user chooses (ShareLink,
    /// copy link, QR — the UI's call, not this protocol's).
    func offer(_ dog: CaughtDog) async throws -> URL

    /// Recipient side: accepts the share behind this metadata (delivered by
    /// the app's UISceneDelegate when the invite link is opened) and
    /// materializes the full package + its binary assets.
    func accept(metadata: CKShare.Metadata) async throws -> HandoverAcceptance
}
