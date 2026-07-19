//
//  CloudKitCommunityStatsProvider.swift
//  DoggoCollector
//
//  The read side of the real Neighborhood map: queries LocalityPresence
//  records (see NeighborhoodPublisher for the record contract and privacy
//  rules) from CloudKit's public database around a center, groups them by
//  locality, and merges in this device's own local aggregates so your own
//  map never looks emptier than reality even before/without publishing.
//
//  Deliberately a separate type rather than a second requirement on
//  CommunityStatsProviding — the shapes are different (async + throwing +
//  radius-scoped vs. the synchronous local grouping the publisher and the
//  merge both still use), and MapView is the only consumer.
//
//  Public-database READS work even with no iCloud account signed in
//  (writes don't) — an assumption this plan flags for live verification;
//  see the Neighborhood map plan doc.
//

import CloudKit
import CoreLocation
import Foundation

/// A locality aggregate across everyone who published there, plus
/// (merged separately) this device's own catches.
struct CommunityLocalityStat: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let latitude: Double
    let longitude: Double
    /// Other people's display names, biggest contributor first — never
    /// tied to a coordinate finer than the locality itself (explicit
    /// product decision: names at locality level only).
    let contributorNames: [String]
    /// True when this device's own catches are part of `count` — drives
    /// the "You're part of it." popover line.
    let includesOwn: Bool
}

struct CloudKitCommunityStatsProvider {
    /// Records older than this are treated as gone — there's no
    /// server-side cleanup for abandoned installs, so staleness filtering
    /// happens at read time.
    static let maxRecordAge: TimeInterval = 90 * 24 * 3600

    private var database: CKDatabase {
        CKContainer(identifier: "iCloud.com.DoggoCollector").publicCloudDatabase
    }

    func neighborhoodStats(
        around center: CLLocationCoordinate2D,
        radiusKm: Double,
        localCatches: [CaughtDog],
        ownIdentity: String
    ) async throws -> [CommunityLocalityStat] {
        // Verified verbatim against CKQuery.h: this is CloudKit's native
        // geo-distance predicate. The header also documents that location
        // indexes have a resolution "no less than 10 km" — so this is an
        // over-fetch, refined by the locality grouping below, not a precise
        // radius cut.
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let query = CKQuery(
            recordType: NeighborhoodPublisher.recordType,
            predicate: NSPredicate(
                format: "distanceToLocation:fromLocation:(centroid, %@) < %f",
                centerLocation, radiusKm * 1000
            )
        )

        let (results, _) = try await database.records(matching: query, resultsLimit: 300)
        let cutoff = Date.now.addingTimeInterval(-Self.maxRecordAge)

        struct Contribution {
            let locality: String
            let count: Int
            let name: String
            let latitude: Double
            let longitude: Double
        }

        var contributions: [Contribution] = []
        for (_, result) in results {
            // Per-record fetch failures are skipped, not fatal — one bad
            // record shouldn't blank the whole neighborhood.
            guard let record = try? result.get(),
                  let locality = record["localityName"] as? String,
                  let count = record["dogCount"] as? Int,
                  let centroid = record["centroid"] as? CLLocation,
                  let name = record["displayName"] as? String,
                  let owner = record["ownerIdentity"] as? String,
                  let updatedAt = record["updatedAt"] as? Date
            else { continue }
            guard updatedAt >= cutoff else { continue }
            // Own published records are excluded here and re-added from
            // the (always fresher) local store below — otherwise a stale
            // published count would fight the live local one.
            guard owner != ownIdentity else { continue }
            guard count > 0 else { continue }
            contributions.append(Contribution(
                locality: locality, count: count, name: name,
                latitude: centroid.coordinate.latitude, longitude: centroid.coordinate.longitude
            ))
        }

        var grouped: [String: (count: Int, names: [(String, Int)], lat: Double, lon: Double)] = [:]
        for c in contributions {
            var entry = grouped[c.locality] ?? (0, [], c.latitude, c.longitude)
            entry.count += c.count
            entry.names.append((c.name, c.count))
            grouped[c.locality] = entry
        }

        // Merge this device's own catches (same grouping + placeholder
        // filtering rules as the publisher, so the two sides agree on what
        // a publishable locality is).
        var ownLocalities = Set<String>()
        for own in ownLocalStats(for: localCatches) {
            ownLocalities.insert(own.name)
            var entry = grouped[own.name] ?? (0, [], own.latitude, own.longitude)
            entry.count += own.count
            grouped[own.name] = entry
        }

        return grouped
            .map { name, entry in
                CommunityLocalityStat(
                    name: name,
                    count: entry.count,
                    latitude: entry.lat,
                    longitude: entry.lon,
                    contributorNames: entry.names
                        .sorted { $0.1 > $1.1 }
                        .map(\.0)
                        .uniqued(),
                    includesOwn: ownLocalities.contains(name)
                )
            }
            .sorted { $0.count > $1.count }
    }

    private func ownLocalStats(for catches: [CaughtDog]) -> [LocalityStat] {
        LocalCommunityStatsProvider().localityStats(for: catches).filter { stat in
            stat.name != "Somewhere nearby" && !(stat.latitude == 0 && stat.longitude == 0)
        }
    }
}

private extension Array where Element == String {
    /// Order-preserving dedupe (contributor lists are tiny).
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
