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

    // Medication tracking & medical records — literal defaults for the same
    // lightweight-migration reason as the fields above.
    @Relationship(deleteRule: .cascade, inverse: \MedicationSchedule.dog)
    var medicationSchedules: [MedicationSchedule]? = []
    @Relationship(deleteRule: .cascade, inverse: \MedicalRecord.dog)
    var medicalRecords: [MedicalRecord]? = []

    // Breed classification — literal defaults for the same lightweight-
    // migration reason as the Guardian fields above.
    /// Raw class label from CoreMLBreedClassifier, including
    /// "mixed_or_uncertain" — nil means never classified yet (pre-existing
    /// catches get a lazy backfill the first time their card is opened).
    var classifiedBreedRaw: String? = nil
    var breedConfidence: Double? = nil
    /// True once the user has corrected the breed by hand. The classifier
    /// is 67% test-accurate, so a wrong guess is an expected, common case —
    /// see `setUserEditedBreed(_:)`.
    var breedUserEdited: Bool = false

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

    /// The one place a user-corrected breed gets written — keeps every
    /// dependent field in sync in one shot: `breedLabel` (every display
    /// site reads this directly, not the insight), `classifiedBreedRaw`
    /// (so `FoundationModelsInsightProvider.ensureClassified`'s `nil` guard
    /// permanently skips backfill here — the user's word is never
    /// overwritten by the model), and `breedConfidence`/`breedUserEdited`
    /// (provenance, so e.g. Share can stop labeling it an "AI guess").
    /// Verbatim "Indie mix" is handled fine — `classifiedDisplayBreed` only
    /// special-cases the raw `"mixed_or_uncertain"` token, so this reads
    /// back correctly either way.
    func setUserEditedBreed(_ text: String) {
        breedLabel = text
        classifiedBreedRaw = text
        breedConfidence = nil
        breedUserEdited = true
    }

    var sortedCareEntries: [CareEntry] {
        (careEntries ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    /// Ended courses drop out of this list (they remain in the store,
    /// never deleted) — sorted soonest-due-first so the Dossier and Today's
    /// Care read as a timeline, not a shuffled table.
    var activeMedicationSchedules: [MedicationSchedule] {
        let entries = careEntries ?? []
        return (medicationSchedules ?? [])
            .filter(\.isActive)
            .sorted { $0.nextDueDate(in: entries) < $1.nextDueDate(in: entries) }
    }

    var sortedMedicalRecords: [MedicalRecord] {
        (medicalRecords ?? []).sorted { $0.date > $1.date }
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
