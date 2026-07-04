//
//  CarePlaceProviding.swift
//  DoggoCollector
//
//  Data source for Nearby Care. Per the brief, vets want "live map data" and
//  shelters/NGOs want a "curated set" — both are mocked for now (deferred:
//  a real MKLocalSearch-backed vet provider, decided in a future session).
//  Views should depend only on the protocol.
//

import CoreLocation
import Foundation

protocol CarePlaceProviding {
    func places(category: CareCategory) -> [CarePlace]
}

struct MockCareDirectory: CarePlaceProviding {
    /// Fallback center to jitter mock coordinates around when there's no
    /// catch history yet to derive one from — the same fictional
    /// San Francisco setting other mock content in this app already leans on
    /// (e.g. "caught at Stockton St").
    private static let fallbackCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    private let center: CLLocationCoordinate2D

    init(center: CLLocationCoordinate2D? = nil) {
        self.center = center ?? Self.fallbackCenter
    }

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

    func places(category: CareCategory) -> [CarePlace] {
        switch category {
        case .vet: vets()
        case .shelter: shelters()
        }
    }

    private func vets() -> [CarePlace] {
        var rng = SeededGenerator(seed: 1001)
        return vetNames.enumerated().map { index, name in
            let is24Hour = Double.random(in: 0...1, using: &rng) < 0.15
            let isOpenNow = is24Hour || Double.random(in: 0...1, using: &rng) < 0.6
            return CarePlace(
                name: name,
                category: .vet,
                distanceMeters: Double.random(in: 300...18_000, using: &rng),
                isOpenNow: isOpenNow,
                is24Hour: is24Hour,
                address: mockAddress(index: index, using: &rng),
                phoneNumber: mockPhoneNumber(using: &rng),
                description: nil,
                coordinate: jitteredCoordinate(using: &rng)
            )
        }.sorted { $0.distanceMeters < $1.distanceMeters }
    }

    private func shelters() -> [CarePlace] {
        var rng = SeededGenerator(seed: 2002)
        return shelterEntries.enumerated().map { index, entry in
            CarePlace(
                name: entry.name,
                category: .shelter,
                distanceMeters: Double.random(in: 300...18_000, using: &rng),
                isOpenNow: Double.random(in: 0...1, using: &rng) < 0.7,
                is24Hour: false,
                address: mockAddress(index: index, using: &rng),
                phoneNumber: mockPhoneNumber(using: &rng),
                description: entry.description,
                coordinate: jitteredCoordinate(using: &rng)
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

    private func jitteredCoordinate(using rng: inout SeededGenerator) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: center.latitude + Double.random(in: -0.08...0.08, using: &rng),
            longitude: center.longitude + Double.random(in: -0.08...0.08, using: &rng)
        )
    }
}
