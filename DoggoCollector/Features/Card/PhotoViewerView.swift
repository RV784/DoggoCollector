//
//  PhotoViewerView.swift
//  DoggoCollector
//
//  The single-photo viewer, modelled on Photos: a tapped mosaic tile enlarges
//  into this full-screen pager, and a pull-down shrinks it straight back to
//  the tile it came from. Both directions are Apple's own zoom navigation
//  transition (iOS 18+): `.matchedTransitionSource` on each tile in
//  DogGalleryView + `.navigationTransition(.zoom(sourceID:in:))` here, sharing
//  one Namespace. The `sourceID` tracks the *currently paged* photo, so after
//  scrubbing to a different one, the dismiss returns to that tile — not the
//  one originally tapped, exactly as Photos does.
//
//  Chrome (per the reference + the request): back top-left, a LIVE badge for
//  live photos, Instagram/native Share bottom-left, Delete (with confirm)
//  bottom-right, and a centred thumbnail scrubber above the buttons. Swiping
//  the main image and tapping a thumb are two views onto one selection
//  (`currentPhotoID`); the scrubber follows it by always scrolling the selected
//  thumb to centre, and every change fires a selection haptic.
//
//  Each page pinch-zooms (ZoomablePage). While a page is zoomed the pager's
//  own paging is disabled (so a one-finger drag pans the image instead of
//  turning the page), the chrome hides, and a single tap toggles it back — the
//  reason the pager is a paging ScrollView rather than a TabView: only a
//  ScrollView exposes `.scrollDisabled`.
//

import SwiftUI
import SwiftData
import AVFoundation

struct PhotoViewerView: View {
    @Bindable var dog: CaughtDog
    let zoomNamespace: Namespace.ID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The single source of truth for "which photo is showing". The pager and
    /// the scrubber both drive it; the scrubber follows it back by always
    /// scrolling the selected thumb to centre.
    @State private var currentPhotoID: UUID

    /// Set true when the visible page zooms in, or by a tap. When true the top
    /// bar, LIVE badge and scrubber all fade out (immersive view).
    @State private var chromeHidden = false
    /// True while the visible page is zoomed — disables paging so a drag pans
    /// the image instead of turning the page.
    @State private var isCurrentZoomed = false

    @State private var showShare = false
    @State private var showDeleteConfirm = false

    init(dog: CaughtDog, initialPhotoID: UUID, zoomNamespace: Namespace.ID) {
        self.dog = dog
        self.zoomNamespace = zoomNamespace
        _currentPhotoID = State(initialValue: initialPhotoID)
    }

    private var photos: [DogPhoto] { dog.sortedPhotos }
    private var currentPhoto: DogPhoto? { photos.first { $0.id == currentPhotoID } }
    private var currentIsLive: Bool { currentPhoto?.livePhotoMovieData != nil }

    /// Bridges the non-optional selection to `.scrollPosition`'s optional id.
    private var scrollPositionBinding: Binding<UUID?> {
        Binding(
            get: { currentPhotoID },
            set: { if let new = $0 { currentPhotoID = new } }
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                pager(size: geo.size)

                VStack(spacing: 0) {
                    topBar
                    if currentIsLive { liveBadgeRow }
                    Spacer(minLength: 0)
                    bottomChrome(width: geo.size.width)
                }
                // All chrome fades together when a page is zoomed or the image
                // is tapped; when hidden it stops intercepting touches so a tap
                // on the image can bring it back.
                .opacity(chromeHidden ? 0 : 1)
                .animation(.easeInOut(duration: 0.22), value: chromeHidden)
                .allowsHitTesting(!chromeHidden)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationTransition(.zoom(sourceID: currentPhotoID, in: zoomNamespace))
        .sensoryFeedback(.selection, trigger: currentPhotoID)
        // A new photo is never carried in zoomed, and always shows its chrome.
        .onChange(of: currentPhotoID) { _, _ in
            isCurrentZoomed = false
            chromeHidden = false
        }
        .sheet(isPresented: $showShare) { ShareView(dog: dog) }
        .confirmationDialog(
            "Delete this photo?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Photo", role: .destructive) { deleteCurrent() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo will be removed from \(dog.name)'s gallery.")
        }
    }

    // MARK: - Pager

    private func pager(size: CGSize) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(photos) { photo in
                    ZoomablePage(
                        photo: photo,
                        isCurrent: photo.id == currentPhotoID,
                        size: size,
                        chromeHidden: $chromeHidden,
                        onZoomChange: { zoomed in
                            guard photo.id == currentPhotoID else { return }
                            isCurrentZoomed = zoomed
                            chromeHidden = zoomed
                        }
                    )
                    .frame(width: size.width, height: size.height)
                    .id(photo.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: scrollPositionBinding)
        .scrollDisabled(isCurrentZoomed)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
    }

    // MARK: - Live badge

    private var liveBadgeRow: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "livephoto")
                Text("LIVE")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, DoggoSpacing.sm)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .glassCircleChrome(size: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            if let date = currentPhoto?.dateTaken {
                VStack(spacing: 1) {
                    Text(date, format: .dateTime.weekday(.wide))
                        .font(DoggoTextStyle.bodySemibold)
                    Text(date, format: .dateTime.hour().minute())
                        .font(DoggoTextStyle.caption)
                        .opacity(0.75)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
            }

            Spacer()

            // Balances the back button so the date stays centred.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, DoggoSpacing.sm)
    }

    // MARK: - Bottom chrome (scrubber + actions)

    private func bottomChrome(width: CGFloat) -> some View {
        VStack(spacing: DoggoSpacing.md) {
            if photos.count > 1 {
                filmstrip(width: width)
            }
            bottomActions
        }
        .padding(.bottom, DoggoSpacing.sm)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()
        )
    }

    private func filmstrip(width: CGFloat) -> some View {
        // Side inset lets the first and last thumbnails settle at screen centre.
        let side = max((width - 52) / 2, 0)
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(photos) { photo in
                        thumbnail(photo)
                            .id(photo.id)
                    }
                }
                .padding(.horizontal, side)
            }
            .scrollIndicators(.hidden)
            .frame(height: 60)
            // Whatever moves the selection — a thumb tap or a main-image swipe —
            // the selected thumb is always scrolled to screen centre.
            .onChange(of: currentPhotoID) { _, id in
                withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo(id, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(currentPhotoID, anchor: .center) }
        }
    }

    private func thumbnail(_ photo: DogPhoto) -> some View {
        let selected = photo.id == currentPhotoID
        return Group {
            if let image = PhotoDecoder.image(from: photo.imageData, size: .thumb, cacheKey: photo.id.uuidString) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                PolkaDotPlaceholder(seed: photo.id.hashValue)
            }
        }
        .frame(width: selected ? 52 : 40, height: selected ? 52 : 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white, lineWidth: selected ? 2 : 0)
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: selected)
        .contentShape(Rectangle())
        .onTapGesture { currentPhotoID = photo.id }
    }

    private var bottomActions: some View {
        HStack {
            Button { showShare = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(.white)
                    .glassCircleChrome(size: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")

            Spacer()

            Button { showDeleteConfirm = true } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.white)
                    .glassCircleChrome(size: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete photo")
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Delete

    private func deleteCurrent() {
        let all = photos
        guard let idx = all.firstIndex(where: { $0.id == currentPhotoID }) else { return }
        let photo = all[idx]
        let wasCover = photo.isCover
        let remaining = all.filter { $0.id != photo.id }

        modelContext.delete(photo)
        PhotoDecoder.evict(id: photo.id.uuidString)
        // Never leave a dog with no cover — promote the first survivor.
        if wasCover, let newCover = remaining.first { newCover.isCover = true }
        try? modelContext.save()

        guard !remaining.isEmpty else {
            // Last photo gone — close the viewer (the gallery falls back to the
            // legacy cover image via coverImageData).
            dismiss()
            return
        }
        // Land on the neighbour that slid into this slot.
        let newIndex = min(idx, remaining.count - 1)
        currentPhotoID = remaining[newIndex].id
    }
}

// MARK: - One page (zoomable)

/// A single full-screen photo, filling the screen width edge-to-edge (aspect
/// preserved, any vertical overflow clipped — never a leading/trailing bar),
/// with pinch-to-zoom + pan. A live photo shows its still by default and plays
/// its movie only while the finger is held down (with a haptic when playback
/// begins), exactly like Photos' press-to-play.
private struct ZoomablePage: View {
    let photo: DogPhoto
    let isCurrent: Bool
    let size: CGSize
    @Binding var chromeHidden: Bool
    /// Reports zoom-in/out so the container can disable paging + hide chrome.
    let onZoomChange: (Bool) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// True only while the finger is held past the long-press threshold. A quick
    /// tap never trips it, so the still never flashes.
    @State private var isPressing = false

    private let maxScale: CGFloat = 4
    private var isZoomed: Bool { scale > 1.01 }
    private let settle = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.85)

    private var movieURL: URL? {
        guard let data = photo.livePhotoMovieData else { return nil }
        return LiveMovieStore.url(for: data, id: photo.id.uuidString, tier: .full)
    }

    var body: some View {
        ZStack {
            if let image = PhotoDecoder.image(from: photo.imageData, size: .card, cacheKey: photo.id.uuidString) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    // Constrain width only → the image fills the full screen
                    // width; height follows the aspect ratio (overflow clipped
                    // below), so there are never leading/trailing bars.
                    .frame(width: size.width)
            }
            // Mounted only while held (and only on the visible page) — plays
            // from the start each hold and vanishes back to the still on
            // release. A handful of concurrent players is the memory pressure
            // this project already fought once.
            if isCurrent, isPressing, let url = movieURL {
                LoopingFitPlayerView(url: url)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(scale)
        .offset(offset)
        // Re-establish a fixed page-sized slot and clip, so a zoomed image can't
        // bleed into the neighbouring pages of the pager.
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        // Pinch (two fingers) never conflicts with the pager's one-finger swipe.
        .simultaneousGesture(magnifyGesture)
        // Pan is only armed while zoomed (`.subviews` disables it otherwise), so
        // at 1× a drag reaches the pager (paging) / the zoom transition
        // (pull-to-dismiss) untouched.
        .simultaneousGesture(panGesture, including: isZoomed ? .all : .subviews)
        // Tap toggles the chrome (this is how the scrubber comes back after a
        // zoom hides it).
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.22)) { chromeHidden.toggle() }
        }
        // Press-and-hold to play; release to return to the still. `perform`
        // fires only once the 0.3s hold is met (a quick tap never plays);
        // `maximumDistance` hands a moving finger back to the pager/dismiss.
        .onLongPressGesture(
            minimumDuration: 0.3,
            maximumDistance: 10,
            perform: { if movieURL != nil { isPressing = true } },
            onPressingChanged: { pressing in
                if !pressing { isPressing = false }
            }
        )
        // Haptic the instant playback begins (only on the false→true edge).
        .sensoryFeedback(trigger: isPressing) { _, now in
            now ? .impact(weight: .medium) : nil
        }
        .onChange(of: isCurrent) { _, current in
            if !current {
                isPressing = false
                resetZoom(animated: false)
            }
        }
    }

    // MARK: Gestures

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    resetZoom(animated: true)
                } else {
                    withAnimation(settle) { offset = clampedOffset(offset) }
                    lastOffset = clampedOffset(offset)
                }
                onZoomChange(isZoomed)
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard isZoomed else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                let clamped = clampedOffset(offset)
                lastOffset = clamped
                withAnimation(settle) { offset = clamped }
            }
    }

    // MARK: Zoom helpers

    /// Keeps the panned image within its own edges (generous — clamps against
    /// the container, so a letterboxed image can drift into the black but never
    /// tears away entirely).
    private func clampedOffset(_ o: CGSize) -> CGSize {
        let maxX = max((size.width * scale - size.width) / 2, 0)
        let maxY = max((size.height * scale - size.height) / 2, 0)
        return CGSize(
            width: min(max(o.width, -maxX), maxX),
            height: min(max(o.height, -maxY), maxY)
        )
    }

    private func resetZoom(animated: Bool) {
        lastScale = 1
        lastOffset = .zero
        if animated {
            withAnimation(settle) { scale = 1; offset = .zero }
        } else {
            scale = 1
            offset = .zero
        }
    }
}

// MARK: - Fit-gravity looping player

/// A single movie looped gaplessly, aspect-*fit* (not fill) so it sits exactly
/// over the fit still beneath it. AVPlayerLooper is correct here — one template
/// item, loop forever — unlike GalleryPlaybackView, which needs to *sequence*
/// many slides and so can't use it.
private struct LoopingFitPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingFitPlayerUIView {
        LoopingFitPlayerUIView(url: url)
    }

    func updateUIView(_ uiView: LoopingFitPlayerUIView, context: Context) {
        uiView.update(url: url)
    }

    static func dismantleUIView(_ uiView: LoopingFitPlayerUIView, coordinator: ()) {
        uiView.teardown()
    }
}

private final class LoopingFitPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var queuePlayer: AVQueuePlayer?
    // Retained deliberately — AVPlayerLooper isn't held by the player, and if it
    // deallocates the loop silently stops.
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    init(url: URL) {
        super.init(frame: .zero)
        playerLayer.videoGravity = .resizeAspect
        setup(url)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(_ url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: item)
        playerLayer.player = player
        queuePlayer = player
        currentURL = url
        player.play()
    }

    func update(url: URL) {
        guard url != currentURL else { return }
        teardown()
        setup(url)
    }

    func teardown() {
        queuePlayer?.pause()
        looper?.disableLooping()
        looper = nil
        queuePlayer = nil
        playerLayer.player = nil
        currentURL = nil
    }
}
