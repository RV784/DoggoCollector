//
//  CarePlace.swift
//  DoggoCollector
//
//  Nearby Care (Flow 2) — a warm directory, not a diagnostic tool. Vets vs.
//  shelters render differently (see CareView), hence the shared category.
//

import CoreLocation
import Foundation

enum CareCategory: CaseIterable, Hashable {
    case vet
    case shelter

    var title: String {
        switch self {
        case .vet: "Vets"
        case .shelter: "Shelters & NGOs"
        }
    }
}

struct CarePlace: Identifiable {
    /// Provider-supplied stable identity — `MKMapItem.identifier` when
    /// available, else a derived key (see `LiveCareDirectory`). Not a fresh
    /// `UUID()` per instantiation, so the same real-world place keeps its
    /// identity across re-searches (e.g. dedupe across merged shelter
    /// queries, or `.sheet(item:)` re-presenting the same row).
    let id: String
    let name: String
    let category: CareCategory
    let distanceMeters: Double
    let address: String
    let phoneNumber: String?
    /// Real `MKMapItem.url`, when present — shelters/NGOs surface this more
    /// often than vets do.
    let websiteURL: URL?
    /// Shelters/NGOs only — vet rows don't show this (per brief, vets vary
    /// little; shelters vary org-to-org). Always nil from live search; kept
    /// for the model's shape and mock/preview content.
    let description: String?
    let coordinate: CLLocationCoordinate2D

    var distanceText: String {
        let km = distanceMeters / 1000
        return km < 1 ? "\(Int(distanceMeters)) m" : String(format: "%.1f km", km)
    }
}
