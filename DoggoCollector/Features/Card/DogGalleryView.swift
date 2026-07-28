//
//  DogGalleryView.swift
//  DoggoCollector
//
//  A dog's own screen, modelled 1:1 on Photos' "People & Pets": a dominant
//  cycling hero, a varied-tile mosaic of every photo, and three floating
//  glass controls at each edge.
//
//  Replaces CardDetailView as the destination for a tapped dog. CardDetailView
//  itself is retained untouched in the codebase — Scout's Sniff and the
//  insight panel get repurposed from it later.
//
//  Two morphs live here, deliberately on separate namespaces so they can
//  never interfere:
//
//  1. `morphNamespace` — the camera. The exact peer-layer pattern from
//     CollectionView's "Catch a doggo" pill (CLAUDE.md decision #5): geometry
//     rides a trivial background shape, the live preview is a separate
//     crossfading peer layer, never geometry-matched itself.
//  2. `careNamespace` — the Care transition. Tapping Care flies the mosaic
//     into a small fanned stack beside the button while the Guardian dossier
//     takes the grid's place; tapping the stack reverses it. Symmetric for
//     free, since both directions share these ids.
//

import SwiftUI
import SwiftData
import PhotosUI

struct DogGalleryView: View {
    @Bindable var dog: CaughtDog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(GuardianEntitlementStore.self) private var entitlements
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Only for the freemium free-ward count (decision #25).
    @Query private var catches: [CaughtDog]

    @Namespace private var morphNamespace
    @Namespace private var careNamespace
    /// The Photos-style tile→viewer zoom. Kept separate from the other two
    /// namespaces so the three transitions can never interfere.
    @Namespace private var zoomNamespace

    private enum Surface { case gallery, camera }
    @State private var surface: Surface = .gallery
    @State private var careMode = false

    /// The photo whose full-screen viewer is pushed. nil = grid only.
    @State private var viewerPhoto: DogPhoto?

    @State private var showPledgeSheet = false
    @State private var showLogSheet = false
    @State private var showShelterPass = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showEditBreed = false
    @State private var editBreedText = ""
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var toastMessage: String?

    /// How many mosaic tiles physically fly into the stack. The rest fade
    /// toward it — flying 200 tiles is what would make this stutter, and
    /// past ~5 the stack is visually full anyway.
    private static let flyingTileCount = 5

    /// The one leading/trailing margin every element on this screen shares —
    /// the floating bars, the hero name, the camera panel, and the dossier
    /// sections. A touch more than DoggoSpacing.xl (24) so the whole screen
    /// breathes a little wider than the app's default content margin.
    private let screenInset: CGFloat = 30

    private var photos: [DogPhoto] { dog.sortedPhotos }
    private var wardCount: Int {
        catches.filter { $0.isWard && !$0.receivedViaHandover }.count
    }
    private var morphAnimation: Animation { .spring(response: 0.4, dampingFraction: 1.0, blendDuration: 0) }
    /// Slightly looser than the camera morph — this one carries many tiles at
    /// once and a stiff spring makes a crowd of them look mechanical.
    private var careAnimation: Animation { .spring(response: 0.55, dampingFraction: 0.86, blendDuration: 0) }

    var body: some View {
        ZStack(alignment: .bottom) {
            DoggoColor.cream.ignoresSafeArea()

            // Only the scrolling content bleeds under the status bar (so the
            // hero runs full height). The bars stay INSIDE the safe area —
            // ignoring it on the whole ZStack pushed them out too, which is
            // what left every floating control jammed against the screen
            // edge and forced a magic .padding(.top, 60) to compensate.
            scrollContent
                .ignoresSafeArea(edges: .top)
                .blur(radius: surface == .camera ? 6 : 0)
                .allowsHitTesting(surface == .gallery)

            // Blur is purely visual — without this scrim, taps in the dimmed
            // margin fall through to the content underneath (the same bug
            // CollectionView's camera panel already had to fix).
            if surface == .camera {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { closeCamera() }
            }

            // Both bars are REMOVED while the camera is up, not just hidden.
            // Hiding the bottom bar with `.opacity(0)` left the camera button
            // in the hierarchy, so it and the camera panel were both live
            // `matchedGeometryEffect` sources for "gallerySurface" at once —
            // SwiftUI logged `AttributeGraph: cycle detected` on a loop and
            // simply stopped rendering the panel (the state was correct the
            // whole time; the view graph was broken). CollectionView has
            // always removed its pill for exactly this reason.
            ZStack {
                if surface == .gallery {
                    topBar.frame(maxHeight: .infinity, alignment: .top)
                }
            }

            ZStack {
                if surface == .gallery {
                    bottomBar
                }
            }

            // Stable anchor for the camera panel (see decision #5 — wrapping
            // the conditional in its own ZStack stops SwiftUI sliding it in
            // from a screen edge).
            ZStack {
                if surface == .camera {
                    cameraPanel
                        // Same inset as the bottom bar, so the panel's edges
                        // line up with the camera button it morphs out of
                        // rather than running wider than it.
                        .padding(.horizontal, screenInset)
                        .padding(.bottom, DoggoSpacing.lg)
                }
            }
        }
        .toast(message: $toastMessage)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPledgeSheet) {
            GuardianPledgeSheet(dog: dog, wardCount: wardCount) {
                toastMessage = "You're now \(dog.name)'s Guardian \u{2713}"
                // Drop straight into the dossier they just unlocked.
                withAnimation(careAnimation) { careMode = true }
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogInteractionSheet(dog: dog) { type in
                toastMessage = "\(type.title) logged \u{2713}"
            }
        }
        .fullScreenCover(isPresented: $showShelterPass) { ShelterPassView(dog: dog) }
        .navigationDestination(item: $viewerPhoto) { photo in
            PhotoViewerView(dog: dog, initialPhotoID: photo.id, zoomNamespace: zoomNamespace)
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
        .onChange(of: photosPickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
    }

    // MARK: - Scrolling content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                GalleryHeroView(dog: dog, contentInset: screenInset)
                    .frame(height: 430)

                if careMode {
                    GuardianDossierView(dog: dog) { toastMessage = $0 }
                        // Same leading/trailing inset as the hero name and the
                        // floating bars, so the dossier sections line up with
                        // the rest of the screen's margin rather than sitting
                        // tighter to the edge.
                        .padding(.horizontal, screenInset)
                        .padding(.vertical, DoggoSpacing.lg)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 28)),
                            removal: .opacity
                        ))
                } else {
                    // Butted straight against the hero — no gap, matching the
                    // reference where the mosaic reads as continuing the
                    // image rather than sitting in its own section.
                    mosaic
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    private var mosaic: some View {
        MosaicLayout(columns: 3, spacing: 3) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                mosaicTile(photo, index: index)
            }
        }
        .padding(.top, 3)
    }

    private func mosaicTile(_ photo: DogPhoto, index: Int) -> some View {
        Button { viewerPhoto = photo } label: {
            Color.clear
                .overlay {
                    if let image = PhotoDecoder.image(from: photo.imageData, size: .tile, cacheKey: photo.id.uuidString) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        PolkaDotPlaceholder(seed: photo.id.hashValue)
                    }
                }
                .clipped()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The zoom transition's source: this tile is what the viewer enlarges
        // out of and shrinks back into.
        .matchedTransitionSource(id: photo.id, in: zoomNamespace)
        // Only the first few tiles carry the shared id — those are the
        // ones that physically fly into the stack (the Care transition).
        .matchedGeometryEffect(
            id: index < Self.flyingTileCount ? "carePhoto-\(photo.id)" : "carePhotoIdle-\(photo.id)",
            in: careNamespace,
            isSource: !careMode
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(DoggoColor.marigold)
                    .glassCircleChrome(size: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                Button("Rename", systemImage: "pencil") {
                    renameText = dog.name
                    showRename = true
                }
                Button("Edit breed", systemImage: "pencil") {
                    editBreedText = dog.breedLabel
                    showEditBreed = true
                }
                // Lifecycle actions are Guardian-only and only meaningful
                // while the ward is still active — same rule CardDetailView's
                // overflow menu has always used.
                if dog.isWard && dog.wardStatus == .active {
                    Divider()
                    Button("Adopted", systemImage: "heart.fill") { archiveWard(as: .adopted) }
                    Button("Passed away", systemImage: "leaf.fill") { archiveWard(as: .passed) }
                    Button("Lost contact", systemImage: "questionmark.circle") { archiveWard(as: .lostContact) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(DoggoColor.marigold)
                    .glassCircleChrome(size: 44)
            }

            // The gallery's "+" entry point (spec) — a Guardian adds photos
            // to a dog any time, not just at the original catch. Sits with
            // the other top-bar controls rather than floating over the grid.
            PhotosPicker(selection: $photosPickerItems, maxSelectionCount: nil, matching: .images) {
                Group {
                    if isImporting {
                        ProgressView().tint(DoggoColor.marigold)
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .foregroundStyle(DoggoColor.marigold)
                .glassCircleChrome(size: 44)
            }
            .disabled(isImporting)
            .padding(.leading, DoggoSpacing.sm)

            // One-tap call to the assigned clinic. Shown only when there IS
            // one — a call button that can't call is exactly the dead
            // affordance this project keeps refusing to ship.
            if let phone = dog.assignedClinicPhone, let url = telURL(phone) {
                Button { UIApplication.shared.open(url) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                        Text("Clinic")
                    }
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.callGreen)
                    .padding(.horizontal, DoggoSpacing.md)
                    .frame(height: 44)
                    .glassEffect(.clear, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.leading, DoggoSpacing.sm)
            }
        }
        // Floating chrome sitting over full-bleed imagery needs a wider inset
        // than content inside a padded container does — at 16 these circles
        // read as stuck to the screen edge, especially against the display's
        // corner radius.
        .padding(.horizontal, screenInset)
        .padding(.top, DoggoSpacing.sm)
    }

    private func telURL(_ phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel://\(digits)")
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        GlassEffectContainer {
            HStack(spacing: DoggoSpacing.md) {
                if careMode {
                    // The stack the photos flew into — tapping it reverses
                    // the whole transition.
                    photoStack
                } else {
                    cameraButton
                }

                centerButton

                // The Instagram/native share moved into the photo viewer's
                // bottom-left. This slot is now the Shelter Pass export — a
                // Guardian-only document, so it's shown only for wards (nothing
                // to put on a pass for a dog with no dossier).
                if dog.isWard {
                    Button { showShelterPass = true } label: {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(DoggoColor.marigold)
                            .glassCircleChrome(size: 58)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Shelter Pass")
                }
            }
        }
        // Matches the top bar's inset so the two rows of floating controls
        // line up on the same margin.
        .padding(.horizontal, screenInset)
        .padding(.bottom, DoggoSpacing.lg)
    }

    /// Visually identical to the Share button on the other side — same glass
    /// circle, same size, just a camera glyph. It additionally carries the
    /// morph's geometry anchor; that's safe here because this is plain
    /// SwiftUI content (an SF Symbol in a glass circle), not the UIKit-backed
    /// kind decision #5 forbids geometry-matching. `.glassEffectTransition`
    /// stops the glass material running its own transition and fighting the
    /// frame interpolation.
    /// Structurally identical to the Share button on the other side (same
    /// `Button` + `glassCircleChrome`), so the two read as a matched pair —
    /// with the morph's geometry anchor added on an inert layer behind it.
    ///
    /// Both details are load-bearing. `glassCircleChrome` applies
    /// `.glassEffect(.interactive)`, which consumes touches itself, so the
    /// tap has to be owned by a real `Button` wrapping it (an
    /// `onTapGesture` on a parent gets swallowed by the glass and the button
    /// goes dead — observed twice while building this). And the shared id
    /// rides `Color.clear`, never the button: `matchedGeometryEffect`
    /// replaces a view's layout geometry, which is exactly decision #5's
    /// rule about keeping the anchor on a trivial shape.
    private var cameraButton: some View {
        Button { openCamera() } label: {
            Image(systemName: "camera.fill")
                .foregroundStyle(DoggoColor.marigold)
                .glassCircleChrome(size: 58)
        }
        .buttonStyle(.plain)
        .background(
            Color.clear.matchedGeometryEffect(id: "gallerySurface", in: morphNamespace)
        )
    }

    /// The 5 flown tiles, fanned. Each keeps the shared id from its mosaic
    /// position, so SwiftUI interpolates the flight itself.
    private var photoStack: some View {
        ZStack {
            ForEach(Array(photos.prefix(Self.flyingTileCount).enumerated().reversed()), id: \.element.id) { index, photo in
                Group {
                    if let image = PhotoDecoder.image(from: photo.imageData, size: .avatar, cacheKey: photo.id.uuidString) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        PolkaDotPlaceholder(seed: photo.id.hashValue)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                .rotationEffect(.degrees(Double(index) * -5))
                .offset(x: CGFloat(index) * 2.5, y: CGFloat(index) * -2)
                .matchedGeometryEffect(id: "carePhoto-\(photo.id)", in: careNamespace, isSource: careMode)
            }
        }
        .frame(width: 58, height: 58)
        .contentShape(Rectangle())
        .onTapGesture { setCareMode(false) }
        .accessibilityLabel("Back to photos")
    }

    /// Care Mode → Care → Log Interaction, depending on where this dog is.
    @ViewBuilder
    private var centerButton: some View {
        if careMode {
            PillButton(title: "Log Interaction", systemImage: "checkmark.circle.fill") {
                showLogSheet = true
            }
        } else if dog.isWard {
            PillButton(title: "Care", systemImage: "heart.text.square.fill") {
                setCareMode(true)
            }
        } else {
            PillButton(title: "Care Mode", systemImage: "pawprint.fill") {
                showPledgeSheet = true
            }
        }
    }

    // MARK: - Camera panel

    private var cameraPanel: some View {
        ZStack {
            Color.black
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .matchedGeometryEffect(id: "gallerySurface", in: morphNamespace)

            CameraView(
                onClose: { closeCamera() },
                galleryDog: dog,
                onAddedToGallery: {
                    closeCamera()
                    toastMessage = "Photo added to \(dog.name)'s gallery \u{2713}"
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .transition(.opacity)
        }
        .frame(height: UIScreen.main.bounds.height * 0.62)
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
    }

    // MARK: - Actions

    private func openCamera() {
        withAnimation(morphAnimation) { surface = .camera }
    }

    private func closeCamera() {
        withAnimation(morphAnimation) { surface = .gallery }
    }

    private func setCareMode(_ on: Bool) {
        // Under Reduce Motion the tiles don't fly — the two states just
        // crossfade (standing rule for every animated element here).
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : careAnimation) {
            careMode = on
        }
    }

    private func archiveWard(as status: WardStatus) {
        dog.wardStatus = status
        MedicationReminder.cancelAll(for: dog)
        toastMessage = status.archiveToast
        if careMode { setCareMode(false) }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        isImporting = true
        defer { isImporting = false }
        var nextIndex = (dog.sortedPhotos.last?.sortIndex ?? -1) + 1
        var added = 0
        for item in items {
            guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
            // Downscale on import exactly like medical records do — a
            // library pick can be 48MP+, which is the oversize class that
            // caused this app's jetsam kills (memory_crash_fixes.md).
            let data = PhotoDecoder.image(from: raw, size: .document)?
                .jpegData(compressionQuality: 0.85) ?? raw
            let photo = DogPhoto(
                imageData: data,
                dateTaken: .now,
                isCover: false,
                sortIndex: nextIndex,
                dog: dog
            )
            modelContext.insert(photo)
            nextIndex += 1
            added += 1
        }
        photosPickerItems = []
        guard added > 0 else { return }
        try? modelContext.save()
        toastMessage = "\(added) photo\(added == 1 ? "" : "s") added \u{2713}"
    }
}
