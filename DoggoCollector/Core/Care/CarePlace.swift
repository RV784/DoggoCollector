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
    let id = UUID()
    let name: String
    let category: CareCategory
    let distanceMeters: Double
    let isOpenNow: Bool
    let is24Hour: Bool
    let address: String
    let phoneNumber: String?
    /// Shelters/NGOs only — vet rows don't show this (per brief, vets vary
    /// little; shelters vary org-to-org).
    let description: String?
    let coordinate: CLLocationCoordinate2D

    var distanceText: String {
        let km = distanceMeters / 1000
        return km < 1 ? "\(Int(distanceMeters)) m" : String(format: "%.1f km", km)
    }
}
