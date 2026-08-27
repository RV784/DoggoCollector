//
//  PosterStudioView.swift
//  DoggoCollector
//
//  The Poster Maker host: pre-flight → ceremony → editor, presented as a
//  fullScreenCover from a dog's gallery. Owns the persisted `Poster`, resolves
//  the dummy traits (the seam a real photo model drops into) and the real
//  Vision cutout, and hands a `PosterRenderModel` to each stage. The ceremony
//  runs over the trait/cutout pass — by the time it lands, the model is ready
//  (and if it isn't, a poster still gets made, fields empty, per the spec).
//

import SwiftUI
import SwiftData
import PhotosUI

struct PosterStudioView: View {
    let dog: CaughtDog
    let initialPurpose: PosterPurpose

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(GameCenterAuthProvider.self) private var authProvider

    @State private var phase: Phase = .preflight
    @State private var purpose: PosterPurpose
    @State private var heroPhotoID: UUID?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var ceremonyID = 0

    @State private var poster: Poster?
    @State private var traits: PosterTraitSet?
    @State private var heroImage: UIImage?
    @State private var polaroids: [UIImage?] = []
    @State private var swarmTiles: [PosterCeremonyView.SwarmTile] = []
    @State private var shareImage: UIImage?
    @State private var showShare = false

    /// Shared between the pre-flight grid and the ceremony swarm so each photo
    /// flies from its exact grid cell into the orbit (one continuous element).
    @Namespace private var tileNS

    private let traitProvider: PosterTraitProviding = MockPosterTraitProvider()

    enum Phase { case preflight, ceremony, edit }

    init(dog: CaughtDog, purpose: PosterPurpose) {
        self.dog = dog
        self.initialPurpose = purpose
        _purpose = State(initialValue: purpose)
    }

    private var photos: [DogPhoto] { dog.sortedPhotos }

    var body: some View {
        ZStack {
            switch phase {
            case .preflight:
                // No .transition here: it would override the grid→orbit matched
                // geometry (the photos would cross-fade instead of flying). The
                // dark pre-flight bg matches the ceremony's, so the swap reads as
                // the photos lifting off the grid rather than a screen change.
                PosterPreflightView(
                    dog: dog, photos: photos, purpose: $purpose, heroPhotoID: $heroPhotoID,
                    pickerItems: $pickerItems, isImporting: isImporting, tileNS: tileNS,
                    onMake: makePoster, onClose: { dismiss() })

            case .ceremony:
                if let poster {
                    PosterCeremonyView(
                        model: renderModel(poster), swarmTiles: swarmTiles, tileNS: tileNS,
                        reduceMotion: reduceMotion,
                        onSkip: {}, onFinished: { withAnimation(.easeInOut(duration: 0.3)) { phase = .edit } })
                    .id(ceremonyID)
                }

            case .edit:
                if let poster {
                    // Instant swap onto the identically-positioned card; the
                    // editor animates only its own chrome in (PosterEditView).
                    PosterEditView(
                        poster: poster, heroImage: heroImage, polaroids: polaroids, photos: photos,
                        onShare: share, onClose: { dismiss() },
                        onPickHero: pickHero)
                }
            }
        }
        .task { await prepareImages() }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
        .onChange(of: heroPhotoID) { _, _ in Task { await resolveHero() } }
        .sheet(isPresented: $showShare) {
            if let shareImage {
                ActivityView(activityItems: [shareImage, shareCaption])
            }
        }
    }

    // MARK: - Render model

    private func renderModel(_ poster: Poster) -> PosterRenderModel {
        PosterRenderModel(
            purpose: poster.purpose,
            accent: poster.purpose.accent(poster.accentIndex),
            layout: poster.layout,
            content: poster.content,
            chips: poster.visibleChips.map(\.text),
            hero: heroImage,
            polaroids: polaroids,
            numberVisible: poster.numberVisible)
    }

    // MARK: - Actions

    private func makePoster() {
        Task {
            let set: PosterTraitSet
            if let existing = traits { set = existing }
            else { set = await traitProvider.traits(for: dog, purpose: purpose) }
            traits = set
            let username = authProvider.currentUsername ?? ""
            let p = Poster(purpose: purpose, dog: dog)
            p.content = PosterContent.make(purpose: purpose, dog: dog, traits: set, username: username)
            p.chips = set.chips
            p.heroPhotoID = heroPhotoID ?? dog.coverPhoto?.id
            // Photo-led when there's no confident cutout.
            p.layout = heroImage == nil ? .photoLed : .heroCentred
            modelContext.insert(p)
            try? modelContext.save()
            poster = p
            ceremonyID += 1
            // The matched-geometry flight (grid photos → orbit ring) rides this
            // animation, so give it a real beat rather than a quick cut.
            withAnimation(.easeInOut(duration: 0.55)) { phase = .ceremony }
        }
    }

    private func share() {
        guard let poster else { return }
        shareImage = PosterRenderer.render(renderModel(poster))
        if shareImage != nil { showShare = true }
    }

    private var shareCaption: String {
        guard let poster else { return "" }
        let line = poster.content.freeLine.trimmingCharacters(in: .whitespacesAndNewlines)
        var base: String
        switch poster.purpose {
        case .missing: base = "\(dog.name) is missing \u{2014} please share \u{1F415}"
        case .found: base = "Found this dog safe \u{2014} is it yours? \u{1F415}"
        case .adopt: base = "\(dog.name) is looking for a home \u{2014} please share \u{1F415}"
        }
        if !line.isEmpty { base += "\n" + line }
        return base
    }

    private func pickHero(_ id: UUID) {
        heroPhotoID = id
        poster?.heroPhotoID = id
        try? modelContext.save()
    }

    // MARK: - Image resolution

    private func prepareImages() async {
        // Swarm: the whole gallery flying (capped for perf), carried WITH their
        // photo ids so each ceremony tile matches its grid cell.
        let selected = Array(photos.prefix(14))
        let images = await decodeAll(selected, size: .tile)
        let tiles = zip(selected, images).map { PosterCeremonyView.SwarmTile(id: $0.0.id, image: $0.1) }
        await MainActor.run { swarmTiles = tiles }
        await resolveHero()
    }

    /// Resolve the cutout for the current hero + pick two polaroids.
    private func resolveHero() async {
        let heroPhoto = photos.first { $0.id == (heroPhotoID ?? dog.coverPhoto?.id) } ?? photos.first
        // Polaroids: the next two photos that aren't the hero.
        let others = photos.filter { $0.id != heroPhoto?.id }.prefix(2)
        let polaroidImgs = await decodeAll(Array(others), size: .card)

        var cutout: UIImage?
        var layoutForNoCutout = false
        if let heroPhoto, let full = PhotoDecoder.image(from: heroPhoto.imageData, size: .document, cacheKey: "poster-hero-\(heroPhoto.id)") {
            if let result = await SubjectCutout.cutout(from: full), result.coverage > 0.02 {
                cutout = result.image
            } else {
                cutout = full   // photo-led fallback uses the raw photo
                layoutForNoCutout = true
            }
        }

        await MainActor.run {
            polaroids = polaroidImgs
            heroImage = cutout
            if let poster, layoutForNoCutout { poster.layout = .photoLed }
            else if let poster, poster.layout == .photoLed, !layoutForNoCutout, cutout != nil { poster.layout = .heroCentred }
        }
    }

    private func decodeAll(_ items: [DogPhoto], size: PhotoDecoder.Size) async -> [UIImage?] {
        items.map { PhotoDecoder.image(from: $0.imageData, size: size, cacheKey: $0.id.uuidString) }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        isImporting = true
        defer { isImporting = false }
        var nextIndex = (photos.last?.sortIndex ?? -1) + 1
        var added = false
        for item in items {
            guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
            let data = PhotoDecoder.image(from: raw, size: .document)?.jpegData(compressionQuality: 0.85) ?? raw
            let photo = DogPhoto(imageData: data, dateTaken: .now, isCover: false, sortIndex: nextIndex, dog: dog)
            modelContext.insert(photo)
            nextIndex += 1
            added = true
        }
        pickerItems = []
        guard added else { return }
        try? modelContext.save()
        await prepareImages()
    }
}
