//
//  CloudKitHandoverProvider.swift
//  DoggoCollector
//
//  The real HandoverProviding conformance (decision #18) — verified live
//  before writing this against the installed iOS 27 SDK's CloudKit headers
//  (SwiftData itself has no sharing API on this SDK at all, confirmed via
//  §14.B1, so this is a hand-built CKShare side-channel, not something
//  SwiftData does for us).
//
//  One dog's whole dossier rides as a SINGLE shared CKRecord (a record-level
//  CKShare(rootRecord:), not a zone-wide share — there's only one
//  meaningful record here, so zone-wide sharing would be more machinery
//  than the job needs): a `payload` field holding the JSON-encoded
//  HandoverPackage (stored via `encryptedValues` — this is personal data:
//  dietary notes, clinic contact info, care history), plus one CKAsset
//  field per binary blob (the dog's photo, each medical attachment),
//  keyed by the stable field names HandoverPackage already assigns.
//
//  `publicPermission = .readOnly`: a handover is a one-time transfer, not
//  a live co-edited document — the recipient reads the snapshot once,
//  materializes their own local copy, and the two copies never sync again.
//

import Foundation
import CloudKit

struct CloudKitHandoverProvider: HandoverProviding {
    private let containerIdentifier = "iCloud.com.DoggoCollector"
    private let recordType = "HandoverDossier"
    private let photoFieldKey = "photo"
    private let payloadFieldKey = "payload"

    private var container: CKContainer {
        CKContainer(identifier: containerIdentifier)
    }

    // MARK: - Offer (sender side)

    func offer(_ dog: CaughtDog) async throws -> URL {
        let database = container.privateCloudDatabase
        // A fresh zone/record identity per attempt, not a stable one
        // derived from dog.id — if a prior offer() call's modifyRecords
        // throws client-side after the server actually committed the
        // write (rare, but real: atomicity protects against partial
        // writes, not a lost success response), reusing the same recordID
        // on retry would hit `.ifServerRecordUnchanged`'s serverRecordChanged
        // rejection forever, since the retry's fresh CKRecord carries no
        // change tag. A new identity every attempt sidesteps that
        // entirely — "Try again" is a real fresh attempt, not a fight
        // with stale state.
        let attemptID = UUID()
        let zone = CKRecordZone(zoneName: "handover-\(attemptID.uuidString)")
        _ = try await database.save(zone)

        let recordID = CKRecord.ID(recordName: "dossier", zoneID: zone.zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        let package = HandoverPackage(dog: dog)
        record.encryptedValues[payloadFieldKey] = try JSONEncoder().encode(package)

        var tempFiles: [URL] = []
        defer { for url in tempFiles { try? FileManager.default.removeItem(at: url) } }

        if let imageData = dog.imageData {
            let url = try Self.writeTempFile(data: imageData, extension: "jpg")
            tempFiles.append(url)
            record[photoFieldKey] = CKAsset(fileURL: url)
        }

        for medicalRecord in dog.medicalRecords ?? [] {
            for attachment in medicalRecord.sortedAttachments {
                let key = HandoverPackage.assetFieldKey(for: attachment.id)
                let url = try Self.writeTempFile(data: attachment.data, extension: attachment.isPDF ? "pdf" : "jpg")
                tempFiles.append(url)
                record[key] = CKAsset(fileURL: url)
            }
        }

        let share = CKShare(rootRecord: record)
        share.publicPermission = .readOnly
        share[CKShare.SystemFieldKey.title] = "\(dog.name)'s dossier" as CKRecordValue

        // Read the URL back off the server-returned record, not the local
        // `share` object — CKDatabase.modifyRecords' return value is the
        // authoritative post-save state; an in-place mutation of the local
        // object isn't guaranteed by the API contract, only documented for
        // the return value.
        let result = try await database.modifyRecords(saving: [record, share], deleting: [])
        guard let savedShare = try result.saveResults[share.recordID]?.get() as? CKShare,
              let url = savedShare.url else {
            throw HandoverError.invalidPackage
        }
        return url
    }

    // MARK: - Accept (recipient side)

    func accept(metadata: CKShare.Metadata) async throws -> HandoverAcceptance {
        _ = try await container.accept(metadata)

        // NOT LIVE-VERIFIED: hierarchicalRootRecordID's doc comment
        // describes it in terms of "a shared record hierarchy" (multi-
        // record parent/child graphs); this app's share is a single flat
        // record with no CKRecord.parent anywhere. Apple's header marks
        // it as the direct replacement for the older, unambiguous
        // rootRecordID (deprecated in its favor), which is why it's used
        // here rather than the deprecated property — but whether it
        // reliably degenerates to "this record's own ID" for a parentless
        // share specifically hasn't been confirmed against a real accept
        // flow (blocked on the account-storage-full constraint, see
        // decision #18). If accept() always throws invalidPackage here,
        // this guard is the first place to check.
        guard let rootRecordID = metadata.hierarchicalRootRecordID else {
            throw HandoverError.invalidPackage
        }
        let record = try await container.sharedCloudDatabase.record(for: rootRecordID)

        guard let payloadData = record.encryptedValues[payloadFieldKey] as? Data else {
            throw HandoverError.invalidPackage
        }
        let package = try JSONDecoder().decode(HandoverPackage.self, from: payloadData)

        let photoData = (record[photoFieldKey] as? CKAsset)?.fileURL.flatMap { try? Data(contentsOf: $0) }

        var attachmentData: [String: Data] = [:]
        for medicalRecord in package.medicalRecords {
            for attachment in medicalRecord.attachments {
                if let asset = record[attachment.assetFieldKey] as? CKAsset,
                   let url = asset.fileURL,
                   let data = try? Data(contentsOf: url) {
                    attachmentData[attachment.assetFieldKey] = data
                }
            }
        }

        return HandoverAcceptance(package: package, photoData: photoData, attachmentData: attachmentData)
    }

    // MARK: - Helpers

    private static func writeTempFile(data: Data, extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try data.write(to: url)
        return url
    }
}
