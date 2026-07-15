//
//  CatchCelebrationView.swift
//  DoggoCollector
//
//  "Gotcha!" — the peak-delight moment. The catch is already saved by the
//  time this shows (CameraViewModel.attemptCatch persists it), so this
//  screen is purely celebratory.
//
//  Lives as a peer state inside CollectionView's own ZStack (not a
//  `.fullScreenCover`) so the card can share `morphNamespace` with the
//  camera panel — the viewfinder morphs directly into this card on capture,
//  continuing the same shutter → card animation chain as the pill → panel one.
//

import SwiftUI

struct CatchCelebrationView: View {
    @Bindable var dog: CaughtDog
    var morphNamespace: Namespace.ID
    var onAddToPack: () -> Void

    @State private var showShare = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showEditBreed = false
    @State private var editBreedText = ""
    /// Gates the live-photo movie overlay until the pill→panel→card morph
    /// (decision #5) has settled — this card *is* the geometry-matched
    /// element in that chain, and LoopingMovieView is UIKit-backed, the
    /// exact content class that broke the original morph. In practice the
    /// movie data doesn't even exist until CameraViewModel's deferred
    /// patch task lands (~2-4s post-shutter), so this mostly guards
    /// against re-entry with an already-populated dog. Same idiom as
    /// decision #16's ambient-shapes-vs-morph-transaction fix.
    @State private var showLiveMovie = false

    var body: some View {
        ZStack(alignment: .bottom) {
            DoggoColor.launchGradient.ignoresSafeArea()
            AmbientBackgroundShapes().ignoresSafeArea()

            ScrollView {
                VStack(spacing: DoggoSpacing.lg) {
                    ScoutMascot(expression: .happy, size: 100)
                        .phaseAnimator([-6.0, 6.0]) { view, angle in
                            view.rotationEffect(.degrees(angle))
                        } animation: { _ in
                            .easeInOut(duration: 0.5)
                        }
                        .transition(.opacity)

                    VStack(spacing: DoggoSpacing.xs) {
                        Text("Gotcha!")
                            .font(DoggoTextStyle.displayLarge)
                            .foregroundStyle(.white)

                        Button {
                            renameText = dog.name
                            showRename = true
                        } label: {
                            HStack(spacing: DoggoSpacing.xs) {
                                Text("\(dog.name) joined your pack")
                                    .font(DoggoTextStyle.bodyRegular)
                                    .foregroundStyle(.white.opacity(0.9))
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            editBreedText = dog.breedLabel
                            showEditBreed = true
                        } label: {
                            HStack(spacing: DoggoSpacing.xs) {
                                Text("\(dog.breedLabel) \u{00B7} not right?")
                                    .font(DoggoTextStyle.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: DoggoSpacing.xs) {
                            Image(systemName: "tag.fill")
                            Text("Spot a collar? This might be someone's pet \u{2014} help them find their way home.")
                        }
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DoggoSpacing.xxl)
                    }
                    .transition(.opacity)

                    DoggoCardView(
                        image: DogPhoto.image(from: dog.imageData, size: .card, cacheKey: dog.id.uuidString),
                        name: dog.name,
                        breedLabel: dog.breedLabel,
                        serialNumber: dog.serialNumber,
                        traits: dog.traits,
                        placeholderSeed: dog.id.hashValue,
                        liveMovieURL: showLiveMovie
                            ? dog.livePhotoMovieData.flatMap { LiveMovieStore.url(for: $0, id: dog.id.uuidString) }
                            : nil
                    )
                    .matchedGeometryEffect(id: "catchSurface", in: morphNamespace)
                    .rotationEffect(.degrees(-3))
                    .padding(.horizontal, DoggoSpacing.xl)
                    .padding(.vertical, DoggoSpacing.md)
                }
                .padding(.top, DoggoSpacing.xxl)
                .padding(.bottom, 180)
            }

            VStack(spacing: DoggoSpacing.md) {
                PillButton(title: "Add to pack", style: .secondary, action: onAddToPack)
                TextLinkButton(title: "Share instead", color: .white) { showShare = true }
            }
            .padding(.horizontal, DoggoSpacing.xl)
            .padding(.bottom, DoggoSpacing.xl)
            .contentShape(Rectangle())
            .zIndex(1)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            showLiveMovie = true
        }
        .sheet(isPresented: $showShare) {
            ShareView(dog: dog)
        }
        .alert("Rename doggo", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { dog.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Edit breed", isPresented: $showEditBreed) {
            TextField("Breed", text: $editBreedText)
            Button("Save") {
                let trimmed = editBreedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { dog.setUserEditedBreed(trimmed) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
