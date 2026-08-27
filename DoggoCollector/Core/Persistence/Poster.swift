//
//  Poster.swift
//  DoggoCollector
//
//  A generated poster, stored against its dog so it can be re-opened,
//  re-edited and re-shared without regenerating (spec §12). Structural choices
//  (purpose / accent / layout / hero photo / number visibility) are columns;
//  the editable copy (`PosterContent`) and the trait chips ([PosterChip]) ride
//  as small JSON blobs, since their shape differs per purpose and neither is
//  ever queried on. Literal defaults on every stored property — this project's
//  standing CloudKit / lightweight-migration discipline.
//

import Foundation
import SwiftData

enum PosterLayout: String, Codable, CaseIterable {
    case heroRight, heroCentred, photoLed
}

@Model
final class Poster {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var purposeRaw: String = PosterPurpose.missing.rawValue
    var accentIndex: Int = 0
    var layoutRaw: String = PosterLayout.heroRight.rawValue
    /// Which gallery photo is the cutout hero (nil = the dog's cover photo).
    var heroPhotoID: UUID? = nil
    var polaroid1ID: UUID? = nil
    var polaroid2ID: UUID? = nil
    /// Number off replaces the contact bar with an in-app chat QR (spec §11).
    var numberVisible: Bool = true
    /// JSON of `[PosterChip]` — on/off + order preserved across edits.
    var chipsData: Data? = nil
    /// JSON of `PosterContent`.
    var contentData: Data? = nil

    var dog: CaughtDog? = nil

    init(purpose: PosterPurpose, dog: CaughtDog?) {
        self.id = UUID()
        self.createdAt = .now
        self.purposeRaw = purpose.rawValue
        self.dog = dog
    }

    // MARK: - Typed accessors

    var purpose: PosterPurpose {
        get { PosterPurpose(rawValue: purposeRaw) ?? .missing }
        set { purposeRaw = newValue.rawValue }
    }

    var layout: PosterLayout {
        get { PosterLayout(rawValue: layoutRaw) ?? .heroRight }
        set { layoutRaw = newValue.rawValue }
    }

    var chips: [PosterChip] {
        get { chipsData.flatMap { try? JSONDecoder().decode([PosterChip].self, from: $0) } ?? [] }
        set { chipsData = try? JSONEncoder().encode(newValue) }
    }

    var content: PosterContent {
        get { contentData.flatMap { try? JSONDecoder().decode(PosterContent.self, from: $0) } ?? PosterContent() }
        set { contentData = try? JSONEncoder().encode(newValue) }
    }

    /// The three enabled chips that actually render (spec: "Three render").
    var visibleChips: [PosterChip] { chips.filter(\.enabled).prefix(3).map { $0 } }
}
