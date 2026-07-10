//
//  CaughtDog.swift
//  DoggoCollector
//

import Foundation
import SwiftData

@Model
final class CaughtDog {
    var id: UUID
    var name: String
    var breedLabel: String
    var traits: [String]
    @Attribute(.externalStorage) var imageData: Data?
    var caughtAt: Date
    var locationLabel: String
    var latitude: Double
    var longitude: Double
    var serialNumber: Int
    var isFavorite: Bool

    // Guardian Mode — literal defaults required on the declarations
    // themselves (not just in `init`) so SwiftData can lightweight-migrate
    // the existing on-device store.
    var isWard: Bool = false
    var pledgedAt: Date? = nil
    var wardStatusRaw: String = WardStatus.active.rawValue
    var sterilizationRaw: String = SterilizationStatus.unknown.rawValue
    var dietaryProfile: String? = nil
    var behavioralQuirks: String? = nil
    /// Clinic fields are a snapshot taken at pledge time (name/phone/address/
    /// distance/coordinate) rather than a reference — `CarePlace` comes from
    /// `LiveCareDirectory` (a live MKLocalSearch) and isn't itself persisted.
    var assignedClinicName: String? = nil
    var assignedClinicPhone: String? = nil
    var assignedClinicAddress: String? = nil
    var assignedClinicDistanceMeters: Double? = nil
    var assignedClinicLatitude: Double? = nil
    var assignedClinicLongitude: Double? = nil
    @Relationship(deleteRule: .cascade, inverse: \CareEntry.dog)
    var careEntries: [CareEntry]? = []

    // Breed classification — literal defaults for the same lightweight-
    // migration reason as the Guardian fields above.
    /// Raw class label from CoreMLBreedClassifier, including
    /// "mixed_or_uncertain" — nil means never classified yet (pre-existing
    /// catches get a lazy backfill the first time their card is opened).
    var classifiedBreedRaw: String? = nil
    var breedConfidence: Double? = nil

    var wardStatus: WardStatus {
        get { WardStatus(rawValue: wardStatusRaw) ?? .active }
        set { wardStatusRaw = newValue.rawValue }
    }

    var sterilization: SterilizationStatus {
        get { SterilizationStatus(rawValue: sterilizationRaw) ?? .unknown }
        set { sterilizationRaw = newValue.rawValue }
    }

    var isActiveWard: Bool { isWard && wardStatus == .active }

    /// True only once a real classification exists above threshold — the
    /// threshold itself was already applied at classification time
    /// (CoreMLBreedClassifier), so this is just "did we get a specific
    /// breed, not mixed_or_uncertain."
    var isBreedConfident: Bool {
        guard let classifiedBreedRaw else { return false }
        return classifiedBreedRaw != "mixed_or_uncertain"
    }

    var classifiedDisplayBreed: String? {
        guard let classifiedBreedRaw else { return nil }
        return classifiedBreedRaw == "mixed_or_uncertain" ? "Indie mix" : classifiedBreedRaw
    }

    var sortedCareEntries: [CareEntry] {
        (careEntries ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    init(
        id: UUID = UUID(),
        name: String,
        breedLabel: String,
        traits: [String],
        imageData: Data?,
        caughtAt: Date = .now,
        locationLabel: String,
        latitude: Double,
        longitude: Double,
        serialNumber: Int,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.breedLabel = breedLabel
        self.traits = traits
        self.imageData = imageData
        self.caughtAt = caughtAt
        self.locationLabel = locationLabel
        self.latitude = latitude
        self.longitude = longitude
        self.serialNumber = serialNumber
        self.isFavorite = isFavorite
    }
}
