//
//  LiveCareDirectory.swift
//  DoggoCollector
//
//  Real MKLocalSearch-backed CarePlaceProviding conformance (Flow 2's
//  deferred data source — see CLAUDE.md decision #8). Recipe validated live
//  against a real Bangalore region before this was written; keep the
//  request knobs (regionPriority = .required, resultTypes = .pointOfInterest)
//  exactly as-is — without them, sparse queries fall back to global/garbage
//  matches (verified: an unfiltered "veterinarian" search once returned a
//  single result in Thailand).
//
//  There is no `.veterinarian` POI category in this SDK — only
//  `.animalService` (iOS 18+) — and no shelter/NGO POI category at all, so
//  shelters are query-text-only, merged from several phrasings.
//

import CoreLocation
import MapKit

struct LiveCareDirectory: CarePlaceProviding {
    private struct AllQueriesFailedError: LocalizedError {
        var errorDescription: String? { "No care providers could be found nearby." }
    }

    func places(category: CareCategory, around center: CLLocationCoordinate2D, radiusKm: Double) async throws -> [CarePlace] {
        switch category {
        case .vet:
            try await vets(around: center, radiusKm: radiusKm)
        case .shelter:
            try await shelters(around: center, radiusKm: radiusKm)
        }
    }

    private func vets(around center: CLLocationCoordinate2D, radiusKm: Double) async throws -> [CarePlace] {
        let request = makeRequest(query: "veterinarian", center: center, radiusKm: radiusKm, filterAnimalService: true)
        let response = try await MKLocalSearch(request: request).start()
        return finalize(response.mapItems.compactMap { carePlace(from: $0, category: .vet, center: center) }, center: center, radiusKm: radiusKm)
    }

    /// Shelters have no POI category, so this runs several query phrasings
    /// concurrently and merges/dedupes — the three overlap heavily but no
    /// single phrasing alone was reliable (verified live). Gaushalas (cattle
    /// shelters) legitimately surface here; that's honest data, not a bug —
    /// no name-based filtering per the plan.
    private func shelters(around center: CLLocationCoordinate2D, radiusKm: Double) async throws -> [CarePlace] {
        let queries = ["animal shelter", "dog shelter", "animal rescue"]

        let results: [Result<[MKMapItem], Error>] = await withTaskGroup(of: Result<[MKMapItem], Error>.self) { group in
            for query in queries {
                group.addTask {
                    do {
                        let request = makeRequest(query: query, center: center, radiusKm: radiusKm, filterAnimalService: false)
                        let response = try await MKLocalSearch(request: request).start()
                        return .success(response.mapItems)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var collected: [Result<[MKMapItem], Error>] = []
            for await result in group { collected.append(result) }
            return collected
        }

        let succeeded = results.compactMap { try? $0.get() }
        guard !succeeded.isEmpty else {
            throw results.compactMap { if case .failure(let error) = $0 { error } else { nil } }.first ?? AllQueriesFailedError()
        }

        var seen = Set<String>()
        var merged: [CarePlace] = []
        for item in succeeded.flatMap({ $0 }) {
            guard let place = carePlace(from: item, category: .shelter, center: center) else { continue }
            guard seen.insert(place.id).inserted else { continue }
            merged.append(place)
        }
        return finalize(merged, center: center, radiusKm: radiusKm)
    }

    /// Free-text vet search for `ClinicPickerSheet` — deliberately without
    /// the `.animalService` POI filter that `vets(around:radiusKm:)` above
    /// uses: a user typing a specific clinic's name by hand shouldn't be
    /// filtered out just because Apple categorized it oddly.
    func searchVets(matching query: String, around center: CLLocationCoordinate2D, radiusKm: Double) async throws -> [CarePlace] {
        let request = makeRequest(query: query, center: center, radiusKm: radiusKm, filterAnimalService: false)
        let response = try await MKLocalSearch(request: request).start()
        return finalize(response.mapItems.compactMap { carePlace(from: $0, category: .vet, center: center) }, center: center, radiusKm: radiusKm)
    }

    private func makeRequest(query: String, center: CLLocationCoordinate2D, radiusKm: Double, filterAnimalService: Bool) -> MKLocalSearch.Request {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusKm * 2_000,
            longitudinalMeters: radiusKm * 2_000
        )
        request.regionPriority = .required
        request.resultTypes = .pointOfInterest
        if filterAnimalService {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.animalService])
        }
        return request
    }

    private func carePlace(from item: MKMapItem, category: CareCategory, center: CLLocationCoordinate2D) -> CarePlace? {
        guard let name = item.name else { return nil }
        let coordinate = item.location.coordinate
        let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: item.location)
        let id = item.identifier?.rawValue ?? "\(name)|\(String(format: "%.4f", coordinate.latitude))|\(String(format: "%.4f", coordinate.longitude))"
        return CarePlace(
            id: id,
            name: name,
            category: category,
            distanceMeters: distance,
            address: item.address?.shortAddress ?? item.address?.fullAddress ?? "Address unavailable",
            phoneNumber: item.phoneNumber,
            websiteURL: item.url,
            description: nil,
            coordinate: coordinate
        )
    }

    /// Filters to the actual radius (the `.required` search region is a
    /// square, so corner results can exceed a circular radius) and sorts by
    /// distance.
    private func finalize(_ places: [CarePlace], center: CLLocationCoordinate2D, radiusKm: Double) -> [CarePlace] {
        places
            .filter { $0.distanceMeters <= radiusKm * 1_000 }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }
}
