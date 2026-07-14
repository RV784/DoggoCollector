//
//  HandoverPackage.swift
//  DoggoCollector
//
//  Guardian Handover (decision #18) — a one-time transfer of responsibility,
//  not a live co-edited document (per the plan's own reframing). This is
//  the Codable snapshot of one dog's full dossier that rides inside a
//  single shared CKRecord's JSON payload field; binary blobs (the dog's
//  photo, each medical attachment) ride alongside as separate CKAsset
//  fields on that same record, matched back by the stable IDs here rather
//  than by array position (more robust across encode/decode round-trips).
//

import Foundation

struct HandoverPackage: Codable {
    struct CareEntrySnapshot: Codable {
        var type: String
        var note: String
        var timestamp: Date
        var scheduleId: UUID?
    }

    struct MedicationScheduleSnapshot: Codable {
        var id: UUID
        var drugName: String
        var dosage: String
        var frequencyHours: Int
        var startDate: Date
        var endDate: Date?
        var notes: String?
    }

    struct MedicalAttachmentSnapshot: Codable {
        var id: UUID
        var filename: String
        var isPDF: Bool
        var sortIndex: Int
        /// Key of this attachment's CKAsset field on the shared record —
        /// see CloudKitHandoverProvider.assetFieldKey(for:).
        var assetFieldKey: String
    }

    struct MedicalRecordSnapshot: Codable {
        var recordType: String
        var date: Date
        var notes: String?
        var attachments: [MedicalAttachmentSnapshot]
    }

    var name: String
    var breedLabel: String
    var traits: [String]
    var locationLabel: String
    var latitude: Double
    var longitude: Double
    var caughtAt: Date

    var pledgedAt: Date?
    var sterilizationRaw: String
    var dietaryProfile: String?
    var behavioralQuirks: String?
    var assignedClinicName: String?
    var assignedClinicPhone: String?
    var assignedClinicAddress: String?
    var assignedClinicDistanceMeters: Double?
    var assignedClinicLatitude: Double?
    var assignedClinicLongitude: Double?

    var classifiedBreedRaw: String?
    var breedConfidence: Double?
    var breedUserEdited: Bool

    var careEntries: [CareEntrySnapshot]
    var medicationSchedules: [MedicationScheduleSnapshot]
    var medicalRecords: [MedicalRecordSnapshot]

    /// Single source of truth for the CKAsset field-name format — used
    /// both when building the snapshot here and when CloudKitHandoverProvider
    /// looks the matching asset back up on a shared CKRecord.
    static func assetFieldKey(for attachmentID: UUID) -> String {
        "asset_\(attachmentID.uuidString.replacingOccurrences(of: "-", with: ""))"
    }

    /// Builds a snapshot from a live dog — the sender side of a handover.
    /// Medical-record attachments get their field keys assigned here so
    /// the caller can pull the matching CKAsset for each one afterward.
    init(dog: CaughtDog) {
        name = dog.name
        breedLabel = dog.breedLabel
        traits = dog.traits
        locationLabel = dog.locationLabel
        latitude = dog.latitude
        longitude = dog.longitude
        caughtAt = dog.caughtAt

        pledgedAt = dog.pledgedAt
        sterilizationRaw = dog.sterilizationRaw
        dietaryProfile = dog.dietaryProfile
        behavioralQuirks = dog.behavioralQuirks
        assignedClinicName = dog.assignedClinicName
        assignedClinicPhone = dog.assignedClinicPhone
        assignedClinicAddress = dog.assignedClinicAddress
        assignedClinicDistanceMeters = dog.assignedClinicDistanceMeters
        assignedClinicLatitude = dog.assignedClinicLatitude
        assignedClinicLongitude = dog.assignedClinicLongitude

        classifiedBreedRaw = dog.classifiedBreedRaw
        breedConfidence = dog.breedConfidence
        breedUserEdited = dog.breedUserEdited

        careEntries = (dog.careEntries ?? []).map {
            CareEntrySnapshot(type: $0.typeRaw, note: $0.note, timestamp: $0.timestamp, scheduleId: $0.scheduleId)
        }
        medicationSchedules = (dog.medicationSchedules ?? []).map {
            MedicationScheduleSnapshot(
                id: $0.id, drugName: $0.drugName, dosage: $0.dosage, frequencyHours: $0.frequencyHours,
                startDate: $0.startDate, endDate: $0.endDate, notes: $0.notes
            )
        }
        medicalRecords = (dog.medicalRecords ?? []).map { record in
            MedicalRecordSnapshot(
                recordType: record.recordType,
                date: record.date,
                notes: record.notes,
                attachments: record.sortedAttachments.map { attachment in
                    MedicalAttachmentSnapshot(
                        id: attachment.id,
                        filename: attachment.filename,
                        isPDF: attachment.isPDF,
                        sortIndex: attachment.sortIndex,
                        assetFieldKey: Self.assetFieldKey(for: attachment.id)
                    )
                }
            )
        }
    }
}
