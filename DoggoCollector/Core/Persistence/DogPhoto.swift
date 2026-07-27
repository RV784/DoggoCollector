//
//  DogPhoto.swift
//  DoggoCollector
//
//  One photo in a dog's gallery. A real entity rather than a `[Data]` array
//  on CaughtDog, deliberately: the colour/marking classifier that comes next
//  refines its read *across* a dog's accumulated photos, so its output will
//  want to hang per-photo. Keeping this as its own @Model now is what lets
//  that attach later without a schema rework.
//
//  Mirrors the MedicalAttachment pattern already proven here — same
//  .externalStorage-per-row approach, same PhotosPicker import path.
//
//  The live-photo companion movies live per-photo (not on CaughtDog) because
//  each photo has its own; that's what makes "play every live photo in
//  sequence" expressible at all. CaughtDog's same-named legacy fields are
//  retained as the migration source only — see GalleryMigration.
//

import Foundation
import SwiftData

@Model
final class DogPhoto {
    // Literal defaults on every stored property — CloudKit-backed SwiftData
    // requires it, and it's this project's standing lightweight-migration
    // discipline for any new model.
    var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data = Data()
    var dateTaken: Date = Date.now
    /// Free text, optional — never auto-generated.
    var caption: String? = nil
    /// Which photo represents this dog wherever a single thumbnail is needed
    /// (Collection tile, Wards row, Share card). The original catch photo
    /// holds this until a person explicitly changes it — deliberately never
    /// re-assigned algorithmically to a "better" photo, per the spec.
    var isCover: Bool = false
    /// Stable gallery order, mirroring MedicalAttachment.sortIndex.
    var sortIndex: Int = 0

    /// Transcoded square live-photo companions for THIS photo (720² full /
    /// 360² grid tile), patched in a few seconds after capture by the same
    /// deferred task the catch flow uses. Nil for imported photos and for
    /// captures where the toggle was off.
    @Attribute(.externalStorage) var livePhotoMovieData: Data? = nil
    @Attribute(.externalStorage) var livePhotoMovieTileData: Data? = nil

    var dog: CaughtDog? = nil

    init(
        imageData: Data,
        dateTaken: Date = .now,
        caption: String? = nil,
        isCover: Bool = false,
        sortIndex: Int = 0,
        livePhotoMovieData: Data? = nil,
        livePhotoMovieTileData: Data? = nil,
        dog: CaughtDog? = nil
    ) {
        self.id = UUID()
        self.imageData = imageData
        self.dateTaken = dateTaken
        self.caption = caption
        self.isCover = isCover
        self.sortIndex = sortIndex
        self.livePhotoMovieData = livePhotoMovieData
        self.livePhotoMovieTileData = livePhotoMovieTileData
        self.dog = dog
    }
}
