//
//  CarePlaceProviding.swift
//  DoggoCollector
//
//  Data source for Nearby Care. `LiveCareDirectory` (real MKLocalSearch) is
//  the only runtime conformance — see that file. `MockCareDirectory` below
//  survives only for SwiftUI #Previews: fake vets with fake phone numbers
//  would be worse than an honest empty/error state, so it's never wired up
//  as a runtime fallback.
//

import CoreLocation
import Foundation

protocol CarePlaceProviding {
    func places(category: CareCategory, around center: CLLocationCoordinate2D, radiusKm: Double) async throws -> [CarePlace]
}

struct MockCareDirectory: CarePlaceProviding {
    private let vetNames = [
        "Bayview Animal Hospital", "Sunny Paws Veterinary Clinic", "Cornerstone Vet Care",
        "Marigold Animal Clinic", "Downtown Pet Emergency", "Maple Street Vet",
        "Harbor Veterinary Hospital", "Whisker & Wag Clinic", "Northside Animal Care", "All Creatures Vet Clinic",
    ]

    private let shelterEntries: [(name: String, description: String)] = [
        ("Second Chance Animal Shelter", "Adoption, fostering, and stray intake."),
        ("Street Paws Rescue", "Feeding routes and sterilization drives for community dogs."),
        ("Paws & Whiskers NGO", "Free sterilization camps, runs monthly."),
        ("Harbor Humane Society", "Shelter, adoption, and low-cost vaccination clinics."),
        ("Community Tails Rescue", "Volunteer-run rescue and foster network."),
        ("Safe Haven Animal Welfare", "Emergency rescue pickups and rehabilitation."),
    ]

    private let streetNames = ["Stockton St", "Maple Ave", "Harbor Rd", "5th St", "Sunset Blvd", "Union Square", "Bay St", "Elm St"]

    func places(category: CareCategory, around center: CLLocationCoordinate2D, radiusKm: Double) async throws -> [CarePlace] {
        switch category {
        case .vet: vets(around: center)
        case .shelter: shelters(around: center)
        }
    }

    private func vets(around center: CLLocationCoordinate2D) -> [CarePlace] {
        var rng = SeededGenerator(seed: 1001)
        return vetNames.enumerated().map { index, name in
            CarePlace(
                id: "mock-vet-\(index)",
                name: name,
                category: .vet,
                distanceMeters: Double.random(in: 300...18_000, using: &rng),
                address: mockAddress(index: index, using: &rng),
                phoneNumber: mockPhoneNumber(using: &rng),
                websiteURL: nil,
                description: nil,
                coordinate: jitteredCoordinate(around: center, using: &rng)
            )
        }.sorted { $0.distanceMeters < $1.distanceMeters }
    }

    private func shelters(around center: CLLocationCoordinate2D) -> [CarePlace] {
        var rng = SeededGenerator(seed: 2002)
        return shelterEntries.enumerated().map { index, entry in
            CarePlace(
                id: "mock-shelter-\(index)",
                name: entry.name,
                category: .shelter,
                distanceMeters: Double.random(in: 300...18_000, using: &rng),
                address: mockAddress(index: index, using: &rng),
                phoneNumber: mockPhoneNumber(using: &rng),
                websiteURL: nil,
                description: entry.description,
                coordinate: jitteredCoordinate(around: center, using: &rng)
            )
        }.sorted { $0.distanceMeters < $1.distanceMeters }
    }

    private func mockAddress(index: Int, using rng: inout SeededGenerator) -> String {
        let streetNumber = Int.random(in: 100...4800, using: &rng)
        return "\(streetNumber) \(streetNames[index % streetNames.count])"
    }

    private func mockPhoneNumber(using rng: inout SeededGenerator) -> String {
        let exchange = Int.random(in: 200...999, using: &rng)
        let line = Int.random(in: 1000...9999, using: &rng)
        return "(415) \(exchange)-\(line)"
    }

    private func jitteredCoordinate(around center: CLLocationCoordinate2D, using rng: inout SeededGenerator) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: center.latitude + Double.random(in: -0.08...0.08, using: &rng),
            longitude: center.longitude + Double.random(in: -0.08...0.08, using: &rng)
        )
    }
}
