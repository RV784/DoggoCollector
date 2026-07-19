//
//  NeighborhoodPublisher.swift
//  DoggoCollector
//
//  Publishes this person's locality-level catch aggregates to CloudKit's
//  PUBLIC database so other players' Neighborhood maps can show real
//  community numbers (see ~/Documents/neighborhood_map_community_data.md).
//
//  Privacy is enforced by schema, not UI restraint: one `LocalityPresence`
//  record per (person, locality) — a neighborhood name, a centroid already
//  coarsened at catch time (~100m, LocationTagger), a count, and a display
//  name. Nothing per-catch, no dog names, no photos, no exact coordinates
//  ever leave the device. Publishing is consent-gated (Settings toggle +
//  first-open ask on the map); reading never requires consent.
//
//  The public database bills against the developer's auto-scaling quota,
//  NOT the user's personal iCloud storage — which is why this is the one
//  CloudKit surface in this app that isn't blocked by the account-full
//  constraint (Known Issue #18). Writes still require the device to be
//  signed into iCloud at all; this silently no-ops otherwise.
//

import CloudKit
import CryptoKit
import Foundation

@MainActor
enum NeighborhoodPublisher {
    static let recordType = "LocalityPresence"
    static let consentKey = "neighborhoodShareEnabled"
    static let consentSeenKey = "hasSeenNeighborhoodConsent"

    private static let identityKey = "neighborhood.publish.identity"
    private static let lastIdentityKey = "neighborhood.publish.lastIdentity"
    private static let lastStateKey = "neighborhood.publish.lastState"
    private static let lastLocalitiesKey = "neighborhood.publish.lastLocalities"

    private static var database: CKDatabase {
        CKContainer(identifier: "iCloud.com.DoggoCollector").publicCloudDatabase
    }

    /// The publish identity: Game Center's `teamPlayerID` when available
    /// (stable across the user's devices, so two CloudKit-synced devices
    /// update the same records instead of double-counting), else a
    /// persisted per-install UUID.
    static func identity(teamPlayerID: String?) -> String {
        if let teamPlayerID, !teamPlayerID.isEmpty {
            return "gc-\(teamPlayerID)"
        }
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: identityKey) {
            return existing
        }
        let fresh = "local-\(UUID().uuidString)"
        defaults.set(fresh, forKey: identityKey)
        return fresh
    }

    /// Idempotent, debounced by a state hash — cheap to call from launch,
    /// foregrounding, and after each catch. Does nothing unless consent is
    /// on, iCloud is signed in, and the aggregates actually changed since
    /// the last successful publish.
    static func publishIfNeeded(catches: [CaughtDog], displayName: String?, teamPlayerID: String?) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: consentKey) else { return }

        let identity = identity(teamPlayerID: teamPlayerID)
        let name = displayName ?? "A doggo collector"
        let stats = publishableStats(for: catches)

        // Identity migration (per-install UUID → Game Center ID once GC
        // authenticates): remove the old identity's records first so the
        // same person never appears twice.
        if let previous = defaults.string(forKey: lastIdentityKey), previous != identity {
            await deleteAllRecords(ownerIdentity: previous)
            defaults.removeObject(forKey: lastStateKey)
            defaults.removeObject(forKey: lastLocalitiesKey)
        }

        let state = stateFingerprint(identity: identity, name: name, stats: stats)
        guard state != defaults.string(forKey: lastStateKey) else { return }

        guard await accountAvailable() else { return }

        var records: [CKRecord] = []
        for stat in stats {
            let record = CKRecord(
                recordType: recordType,
                recordID: CKRecord.ID(recordName: recordName(identity: identity, locality: stat.name))
            )
            record["localityName"] = stat.name
            record["centroid"] = CLLocation(latitude: stat.latitude, longitude: stat.longitude)
            record["dogCount"] = stat.count as NSNumber
            record["displayName"] = name
            record["ownerIdentity"] = identity
            record["updatedAt"] = Date.now
            records.append(record)
        }

        // Localities published last time that no longer exist locally
        // (e.g. every catch there was deleted) get removed rather than
        // left stale forever.
        let currentNames = Set(stats.map(\.name))
        let previousNames = Set(defaults.stringArray(forKey: lastLocalitiesKey) ?? [])
        let deletions = previousNames.subtracting(currentNames).map {
            CKRecord.ID(recordName: recordName(identity: identity, locality: $0))
        }

        do {
            // .allKeys ignores server change tags — a blind last-writer-wins
            // upsert, correct here because each identity owns its records
            // outright. atomically:false so one bad record can't sink the
            // batch.
            _ = try await database.modifyRecords(
                saving: records, deleting: deletions,
                savePolicy: .allKeys, atomically: false
            )
            defaults.set(state, forKey: lastStateKey)
            defaults.set(identity, forKey: lastIdentityKey)
            defaults.set(Array(currentNames), forKey: lastLocalitiesKey)
        } catch {
            // Leave lastState untouched — the next trigger retries.
        }
    }

    /// Consent switched off: remove everything this person ever published.
    static func withdrawAll(teamPlayerID: String?) async {
        let defaults = UserDefaults.standard
        let identity = identity(teamPlayerID: teamPlayerID)
        await deleteAllRecords(ownerIdentity: identity)
        if let previous = defaults.string(forKey: lastIdentityKey), previous != identity {
            await deleteAllRecords(ownerIdentity: previous)
        }
        defaults.removeObject(forKey: lastStateKey)
        defaults.removeObject(forKey: lastLocalitiesKey)
    }

    // MARK: - Internals

    /// The same locality grouping the local map uses, minus entries that
    /// can't honestly go on a public map: the "Somewhere nearby"
    /// pre-geocode placeholder and anything with a (0,0) centroid.
    private static func publishableStats(for catches: [CaughtDog]) -> [LocalityStat] {
        LocalCommunityStatsProvider().localityStats(for: catches).filter { stat in
            stat.name != "Somewhere nearby" && !(stat.latitude == 0 && stat.longitude == 0)
        }
    }

    /// Deterministic per-(identity, locality) record name. The locality is
    /// hashed rather than embedded because record names have charset/length
    /// limits and locality labels are arbitrary user-locale text.
    private static func recordName(identity: String, locality: String) -> String {
        let digest = SHA256.hash(data: Data(locality.utf8))
        let hex = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
        return "\(identity)|\(hex)"
    }

    private static func stateFingerprint(identity: String, name: String, stats: [LocalityStat]) -> String {
        let parts = stats
            .map { "\($0.name)=\($0.count)@\($0.latitude),\($0.longitude)" }
            .sorted()
            .joined(separator: ";")
        return "\(identity)|\(name)|\(parts)"
    }

    private static func accountAvailable() async -> Bool {
        (try? await CKContainer(identifier: "iCloud.com.DoggoCollector").accountStatus()) == .available
    }

    private static func deleteAllRecords(ownerIdentity: String) async {
        guard await accountAvailable() else { return }
        let query = CKQuery(
            recordType: recordType,
            predicate: NSPredicate(format: "ownerIdentity == %@", ownerIdentity)
        )
        guard let (results, _) = try? await database.records(matching: query, resultsLimit: 400) else { return }
        let ids = results.map(\.0)
        guard !ids.isEmpty else { return }
        _ = try? await database.modifyRecords(saving: [], deleting: ids, savePolicy: .allKeys, atomically: false)
    }
}
