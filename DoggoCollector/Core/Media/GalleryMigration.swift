//
//  GalleryMigration.swift
//  DoggoCollector
//
//  Lifts every pre-gallery dog's single photo into its `photos` gallery as
//  the cover entry. Adding the relationship alone would leave every existing
//  dog with an empty gallery — the photo would still render (coverImageData
//  falls back to the legacy field) but the gallery screen would look empty
//  and any new photo would sort ahead of the original catch. This closes
//  that, once, in place.
//
//  Idempotent and cheap: a dog that already has photos is skipped, so this
//  can run from CollectionView's launch .task on every start (alongside
//  PhotoStoreRepair) without a "has migrated" flag to keep in sync.
//
//  The legacy CaughtDog.imageData / livePhotoMovieData* fields are read here
//  and then deliberately LEFT IN PLACE rather than nil-ed out: dropping the
//  only copy of a user's photo on a best-effort background pass is exactly
//  the kind of irreversible move this project doesn't make. They cost one
//  duplicated external-storage blob per pre-existing dog and stop being
//  written for new catches.
//

import Foundation
import SwiftData

enum GalleryMigration {
    @MainActor
    static func run(dogs: [CaughtDog], context: ModelContext) async {
        var migrated = 0

        for dog in dogs {
            // Already has a gallery (migrated on an earlier launch, or a
            // catch made after the gallery shipped) — nothing to do.
            guard (dog.photos ?? []).isEmpty else { continue }
            guard let imageData = dog.imageData, !imageData.isEmpty else { continue }

            let photo = DogPhoto(
                imageData: imageData,
                // The catch date is the honest "date taken" for the original
                // photo — not the migration's run date.
                dateTaken: dog.caughtAt,
                isCover: true,
                sortIndex: 0,
                livePhotoMovieData: dog.livePhotoMovieData,
                livePhotoMovieTileData: dog.livePhotoMovieTileData,
                dog: dog
            )
            context.insert(photo)
            migrated += 1
        }

        guard migrated > 0 else { return }
        try? context.save()
    }
}
