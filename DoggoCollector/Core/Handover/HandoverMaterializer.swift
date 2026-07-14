//
//  HandoverMaterializer.swift
//  DoggoCollector
//
//  Turns an accepted HandoverAcceptance back into a real local CaughtDog +
//  children, inserted into the recipient's own SwiftData store. The new
//  dog is a fresh row with its own id/serialNumber — a handover is a copy,
//  not a shared reference, matching the plan's "transfer, not co-editing"
//  framing (decision #18).
//

import Foundation
import SwiftData

enum HandoverMaterializer {
    @discardableResult
    static func materialize(_ acceptance: HandoverAcceptance, into context: ModelContext) throws -> CaughtDog {
        let package = acceptance.package
        let serialCount = (try? context.fetchCount(FetchDescriptor<CaughtDog>())) ?? 0

        let dog = CaughtDog(
            name: package.name,
            breedLabel: package.breedLabel,
            traits: package.traits,
            imageData: acceptance.photoData,
            caughtAt: package.caughtAt,
            locationLabel: package.locationLabel,
            latitude: package.latitude,
            longitude: package.longitude,
            serialNumber: serialCount + 1
        )
        dog.isWard = true
        dog.pledgedAt = package.pledgedAt ?? .now
        dog.wardStatusRaw = WardStatus.active.rawValue
        dog.sterilizationRaw = package.sterilizationRaw
        dog.dietaryProfile = package.dietaryProfile
        dog.behavioralQuirks = package.behavioralQuirks
        dog.assignedClinicName = package.assignedClinicName
        dog.assignedClinicPhone = package.assignedClinicPhone
        dog.assignedClinicAddress = package.assignedClinicAddress
        dog.assignedClinicDistanceMeters = package.assignedClinicDistanceMeters
        dog.assignedClinicLatitude = package.assignedClinicLatitude
        dog.assignedClinicLongitude = package.assignedClinicLongitude
        dog.classifiedBreedRaw = package.classifiedBreedRaw
        dog.breedConfidence = package.breedConfidence
        dog.breedUserEdited = package.breedUserEdited
        context.insert(dog)

        // scheduleId references get remapped: MedicationSchedule.id is
        // preserved from the sender's snapshot (so this mapping holds),
        // but CareEntry itself always gets a fresh id — matching how
        // every other CareEntry in this app is created, never round-tripped.
        for scheduleSnapshot in package.medicationSchedules {
            let schedule = MedicationSchedule(
                drugName: scheduleSnapshot.drugName,
                dosage: scheduleSnapshot.dosage,
                frequencyHours: scheduleSnapshot.frequencyHours,
                startDate: scheduleSnapshot.startDate,
                endDate: scheduleSnapshot.endDate,
                notes: scheduleSnapshot.notes,
                dog: dog
            )
            schedule.id = scheduleSnapshot.id
            context.insert(schedule)
        }

        for entrySnapshot in package.careEntries {
            let entry = CareEntry(
                type: CareEntryType(rawValue: entrySnapshot.type) ?? .fed,
                note: entrySnapshot.note,
                timestamp: entrySnapshot.timestamp,
                dog: dog
            )
            entry.scheduleId = entrySnapshot.scheduleId
            context.insert(entry)
        }

        for recordSnapshot in package.medicalRecords {
            let record = MedicalRecord(
                recordType: recordSnapshot.recordType,
                date: recordSnapshot.date,
                notes: recordSnapshot.notes,
                dog: dog
            )
            context.insert(record)
            for attachmentSnapshot in recordSnapshot.attachments {
                guard let data = acceptance.attachmentData[attachmentSnapshot.assetFieldKey] else { continue }
                let attachment = MedicalAttachment(
                    data: data,
                    filename: attachmentSnapshot.filename,
                    isPDF: attachmentSnapshot.isPDF,
                    sortIndex: attachmentSnapshot.sortIndex,
                    record: record
                )
                context.insert(attachment)
            }
        }

        do {
            try context.save()
        } catch {
            // If the save fails, the inserts above are still staged on the
            // shared ModelContext — without an explicit rollback, a later
            // unrelated save() elsewhere in the app would silently commit
            // this half-materialized dog anyway, even though the caller
            // was told acceptance failed. rollback() discards everything
            // inserted (and any other uncommitted changes) back to the
            // last successful save.
            context.rollback()
            throw error
        }
        return dog
    }
}
