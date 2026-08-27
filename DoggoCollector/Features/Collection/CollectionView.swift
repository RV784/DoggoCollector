//
//  CollectionView.swift
//  DoggoCollector
//
//  "Your Pack" — the daily-open home screen. Collector-first: no streak,
//  just what you've actually caught.
//

import SwiftUI
import SwiftData

private enum SurfaceState {
    case idle
    case camera
    case celebration
}

struct CollectionView: View {
    @Environment(GameCenterAuthProvider.self) private var authProvider
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(DisplayMetrics.self) private var displayMetrics
    @Query(sort: \CaughtDog.caughtAt, order: .reverse) private var catches: [CaughtDog]

    @Namespace private var morphNamespace
    @State private var surfaceState: SurfaceState = .idle
    @State private var caughtDog: CaughtDog?
    /// Gates the live camera feed so it appears only AFTER the pill has finished
    /// growing into the panel — the morph reads as "grow the button, then switch
    /// to the viewfinder." Also keeps all camera-session work out of the morph
    /// animation (nothing heavy mounts until the growth is done).
    @State private var showCameraFeed = false
    /// Scroll-driven: the "Catch a doggo" pill collapses to a circle (matching
    /// the paw button) when scrolling down, expands back to a pill scrolling up.
    @State private var catchCollapsed = false
    /// Captured at the top on first layout; the collapse is measured as
    /// distance from here, so it doesn't depend on the device's safe-area
    /// baseline or on which sign the offset happens to move in.
    @State private var scrollBaseline: CGFloat?
    /// The previous scrolled-distance, so we can tell scroll direction and
    /// expand the instant the user scrolls back up (not only at the top).
    @State private var lastScrolled: CGFloat = 0

    /// The camera panel's device-concentric corner radius: the display's own
    /// corner minus the panel's `lg` inset (a uniform gap to the screen edge).
    /// A CONSTANT — resolved from DisplayMetrics (read once at the window root),
    /// so it matches the device with zero morph lag. Falls back to 32.
    private var panelCornerRadius: CGFloat {
        guard let display = displayMetrics.displayCornerRadius else { return 32 }
        let concentric = display - DoggoSpacing.lg
        return concentric > 0 ? concentric : 32
    }

    private var hasWards: Bool { catches.contains { $0.isWard } }
    private var activeWards: [CaughtDog] { catches.filter(\.isActiveWard) }
    private var dosesDueTodayCount: Int { TodaysCare.dueTodayCount(for: catches) }

    private let mechanic = PackCollectorMechanic()
    private let columns = [
        GridItem(.flexible(), spacing: DoggoSpacing.md),
        GridItem(.flexible(), spacing: DoggoSpacing.md),
    ]

    // Matches the reference morph: a fairly stiff, grounded spring — not the
    // softer springs used for ordinary UI feedback elsewhere in the app.
    private let morphAnimation: Animation = .spring(response: 0.4, dampingFraction: 1.0, blendDuration: 0)
    private let morphOpenAnimation: Animation = .spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    // Camera panel → pill (dismiss). Its own, slightly slower spring — the
    // default morphAnimation read as a bit too fast collapsing back down.
    private let morphCloseAnimation: Animation = .spring(response: 0.5, dampingFraction: 1.0, blendDuration: 0)
    // The pill↔circle collapse — a springy little bounce, its own animation
    // so it never entangles with the camera morph's transaction. The low
    // damping is what gives the settle its overshoot/bounce.
    private let collapseAnimation: Animation = .spring(response: 0.42, dampingFraction: 0.7, blendDuration: 0)

    private let pawButtonSize: CGFloat = 58
    /// Both circular buttons shrink a touch once collapsed, back to full size
    /// when expanded.
    private let collapsedButtonSize: CGFloat = 46
    /// The pill's expanded width — screen minus the bar's horizontal padding,
    /// the paw button, and the gap between them. Explicit (not a greedy fill)
    /// so the collapse interpolates smoothly in both directions.
    private var fullCatchWidth: CGFloat {
        UIScreen.main.bounds.width - 2 * DoggoSpacing.lg - DoggoSpacing.md - pawButtonSize
    }

    // TEMP-PAYWALL-PREVIEW: remove with the matching .sheet below.
    @State private var tempPaywallPreview = ProcessInfo.processInfo.arguments.contains("-previewPaywall")

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DoggoColor.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DoggoSpacing.xl) {
                        header
                            .padding(.horizontal, DoggoSpacing.lg)
                        if catches.isEmpty {
                            EmptyStateView()
                                .padding(.top, DoggoSpacing.xxl)
                                .padding(.horizontal, DoggoSpacing.lg)
                        } else {
                            if hasWards {
                                wardsSection
                            }
                            allCatchesSection
                                .padding(.horizontal, DoggoSpacing.lg)
                        }
                    }
                    .padding(.vertical, DoggoSpacing.lg)
                    .padding(.bottom, 110)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .named("packScroll")).minY
                    } action: { newValue in
                        updateCatchCollapse(offset: newValue)
                    }
                }
                .coordinateSpace(.named("packScroll"))
                // Belt-and-braces against a phantom top inset: with the nav bar
                // hidden, the scroll content should start right under the status
                // bar, not below a reserved (invisible) bar's height.
                .contentMargins(.top, 0, for: .scrollContent)
                .blur(radius: surfaceState == .camera ? 6 : 0)
                .allowsHitTesting(surfaceState == .idle)

                // Blur alone is purely visual — without this, taps in the
                // dimmed margin around the panel fall straight through to
                // the (blurred but still interactive) cards underneath.
                // This invisible scrim catches those taps and dismisses.
                // (Celebration is a full opaque takeover, so it needs no scrim.)
                if surfaceState == .camera {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture(perform: closeCamera)
                }

                // Stable anchor for the idle pill — wrapping the conditional
                // in its own ZStack (rather than conditionally rendering
                // `catchButton` directly in this outer ZStack) keeps SwiftUI
                // from sliding it in from a screen edge when it reappears.
                ZStack {
                    if surfaceState == .idle {
                        GlassEffectContainer {
                            // catch button pinned leading, paw pinned trailing —
                            // independent so the catch pill can collapse to a
                            // circle on the left without dragging the paw inward.
                            // When collapsed, the doses chip slides in beside the
                            // circle (matchedGeometryEffect animates it down from
                            // its floating spot above).
                            ZStack {
                                HStack(spacing: DoggoSpacing.md) {
                                    catchButton(collapsed: catchCollapsed)
                                    if catchCollapsed, dosesDueTodayCount > 0 {
                                        todaysCareChip(collapsed: true)
                                            .matchedGeometryEffect(id: "dosesChip", in: morphNamespace)
                                    }
                                    Spacer(minLength: 0)
                                }
                                HStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    pawButton
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DoggoSpacing.lg)
                // The outer ZStack is inset by the bottom safe area, so a plain
                // .padding(.bottom, lg) here stacks on top of that inset (~34pt)
                // and the gap below the buttons ends up much larger than the
                // matching lg gap on the leading/trailing. Extend into the safe
                // area and pad from the true screen edge so all three match.
                .padding(.bottom, DoggoSpacing.lg)
                .ignoresSafeArea(.container, edges: .bottom)

                // The "N doses due today" chip's *expanded* home — floating just
                // above the pill. When the pill collapses it hands off (via the
                // shared matchedGeometryEffect id) to the copy beside the circle.
                ZStack {
                    if surfaceState == .idle, dosesDueTodayCount > 0, !catchCollapsed {
                        HStack {
                            todaysCareChip(collapsed: false)
                                .matchedGeometryEffect(id: "dosesChip", in: morphNamespace)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, DoggoSpacing.lg)
                    }
                }
                // Share the button bar's coordinate frame (true screen edge, not
                // the safe-area line) so the chip stays the same ~8pt above the
                // pill now that the pill sits lower.
                .padding(.bottom, 90)
                .ignoresSafeArea(.container, edges: .bottom)

                // Stable anchor for the active camera panel. Shares the pill's
                // coordinate frame (true screen edge) so the panel's bottom lines
                // up with the pill it morphs out of, not ~34pt higher.
                ZStack {
                    if surfaceState == .camera {
                        cameraPanel
                            .padding(.horizontal, DoggoSpacing.lg)
                            .padding(.bottom, DoggoSpacing.lg)
                    }
                }
                .ignoresSafeArea(.container, edges: .bottom)

                // Stable anchor for the post-catch celebration — the
                // viewfinder continues the same morph chain straight into
                // the card shown here, rather than cutting to a modal.
                ZStack {
                    if surfaceState == .celebration, let caughtDog {
                        CatchCelebrationView(
                            dog: caughtDog,
                            morphNamespace: morphNamespace,
                            onAddToPack: returnToIdle
                        )
                        .ignoresSafeArea()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // Restore left-edge swipe-back on every pushed screen — all of
            // them hide the system back button, which otherwise kills the
            // gesture. Map opts out (see InteractiveSwipeBack.isSuppressed).
            .enableInteractiveSwipeBack()
            // The gallery replaces CardDetailView as a tapped dog's screen.
            // CardDetailView is retained in the codebase (Scout's Sniff and
            // the insight panel get repurposed from it later), just no longer
            // routed to.
            .navigationDestination(for: CaughtDog.self) { dog in
                DogGalleryView(dog: dog)
            }
            .navigationDestination(for: ProfileDestination.self) { _ in ProfileView() }
            .navigationDestination(for: CareDestination.self) { _ in CareView() }
            .navigationDestination(for: MapDestination.self) { _ in MapView() }
            .navigationDestination(for: PastWardsDestination.self) { _ in PastWardsView() }
            .navigationDestination(for: TodaysCareDestination.self) { _ in TodaysCareView() }
            .navigationDestination(for: WardsDestination.self) { _ in WardsScreen() }
        }
        // TEMP-PAYWALL-PREVIEW
        .sheet(isPresented: $tempPaywallPreview) {
            if let dog = catches.first {
                GuardianPledgeSheet(
                    dog: dog,
                    wardCount: ProcessInfo.processInfo.arguments.contains("-paidPath") ? 6 : 0
                ) {}
            }
        }
        .task {
            // Order matters: lift legacy single photos into the gallery
            // first, so the repair pass below sees (and can shrink) the
            // DogPhoto rows it just created rather than only the legacy field.
            await GalleryMigration.run(dogs: catches, context: modelContext)
            await PhotoStoreRepair.run(dogs: catches, context: modelContext)
            await MedicationReminder.sweep(dogs: catches)
            await publishNeighborhoodPresence()
        }
        // With CloudKit sync (decision #18), schedules can now arrive on
        // this device from another one — a sweep only at launch would miss
        // them for the rest of a long-lived session. Re-running on every
        // return to foreground is the plan's own "cheap version" of
        // reconciliation; a real CloudKit-push-triggered wakeup is out of
        // scope for this pass.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await MedicationReminder.sweep(dogs: catches)
                await publishNeighborhoodPresence()
            }
        }
    }

    /// Consent-gated, hash-debounced — cheap to fire from every lifecycle
    /// edge (launch, foregrounding, and each catch landing in the grid);
    /// NeighborhoodPublisher itself decides whether anything changed.
    private func publishNeighborhoodPresence() async {
        await NeighborhoodPublisher.publishIfNeeded(
            catches: catches,
            displayName: authProvider.currentUsername,
            teamPlayerID: authProvider.teamPlayerID
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
                Text(mechanic.greeting(username: authProvider.currentUsername ?? "friend"))
                    .font(DoggoTextStyle.eyebrow)
                    .foregroundStyle(DoggoColor.inkMuted)
                Text(mechanic.homeTitle)
                    .font(DoggoTextStyle.displayLarge)
                    .foregroundStyle(DoggoColor.ink)
            }
            Spacer()
            NavigationLink(value: MapDestination()) {
                Image(systemName: "mappin")
                    .foregroundStyle(DoggoColor.marigold)
                    .glassCircleChrome(size: 50)
            }
        }
    }

    // MARK: - Sections (Apple-Music-style Home)

    /// Plain section title (no "see all" affordance).
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DoggoTextStyle.headline)
            .foregroundStyle(DoggoColor.ink)
    }

    /// The hero section: active wards as large cards that scroll horizontally
    /// and bleed off the trailing edge (Apple Music "Top Picks"). Visible once
    /// any pledge has ever happened; if every ward is archived the carousel is
    /// replaced by a quiet link into the full wards screen.
    private var wardsSection: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            NavigationLink(value: WardsDestination()) {
                HStack(spacing: DoggoSpacing.xs) {
                    Text("Guardian Wards")
                        .font(DoggoTextStyle.headline)
                        .foregroundStyle(DoggoColor.ink)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DoggoColor.inkMuted)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DoggoSpacing.lg)

            if activeWards.isEmpty {
                NavigationLink(value: WardsDestination()) {
                    Text("No active wards \u{00B7} View past \u{2192}")
                        .font(DoggoTextStyle.bodySemibold)
                        .foregroundStyle(DoggoColor.marigold)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DoggoSpacing.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DoggoSpacing.md) {
                        ForEach(activeWards) { dog in
                            NavigationLink(value: dog) { wardCard(dog) }
                                .buttonStyle(ScalePressButtonStyle())
                        }
                    }
                    .padding(.horizontal, DoggoSpacing.lg)
                }
                .scrollClipDisabled()
            }
        }
    }

    /// A larger take on the standard grid card, with the ward's status and
    /// (when owed) a doses-due nudge integrated onto the card itself — the
    /// sterilization badge balancing the GUARDIAN tag across the top, the
    /// doses chip riding in the glass footer beside the name.
    private func wardCard(_ dog: CaughtDog) -> some View {
        let dueToday = TodaysCare.dueTodayCount(for: [dog])
        return DoggoCardView(
            image: PhotoDecoder.image(from: dog.coverImageData, size: .card, cacheKey: dog.coverCacheKey),
            name: dog.name,
            breedLabel: dog.breedLabel,
            serialNumber: dog.serialNumber,
            isCompact: true,
            placeholderSeed: dog.id.hashValue,
            showsGuardianTag: true,
            // The bigger ward cards warrant the crisper full-size movie
            // transcode; there are only ever a few on screen.
            slides: dog.gallerySlides(tier: .full)
        )
        .overlay(alignment: .topLeading) {
            StatusBadge.Compact(status: dog.sterilization)
                // Inset to clear the rounded (radius 36) card corner.
                .padding(DoggoSpacing.md)
        }
        .overlay(alignment: .bottomTrailing) {
            if dueToday > 0 {
                dosesDueChip(count: dueToday)
                    .padding(.horizontal, DoggoSpacing.lg)
                    .padding(.vertical, DoggoSpacing.lg)
            }
        }
        .frame(width: wardCardWidth)
    }

    /// Amber "N doses due" capsule — the one actionable nudge worth surfacing
    /// on the card face.
    private func dosesDueChip(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "pills.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(count == 1 ? "1 dose due" : "\(count) doses due")
                .font(DoggoTextStyle.caption)
        }
        .foregroundStyle(DoggoColor.statusAttnAccent)
        .padding(.horizontal, DoggoSpacing.sm)
        .padding(.vertical, 4)
        .background(DoggoColor.statusAttnBg, in: Capsule())
    }

    /// The full collection: every catch (wards included) in the standard
    /// 2-column grid.
    private var allCatchesSection: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            sectionHeader("All Catches")
            LazyVGrid(columns: columns, spacing: DoggoSpacing.md) {
                ForEach(catches) { dog in
                    NavigationLink(value: dog) {
                        DoggoCardView(
                            image: PhotoDecoder.image(from: dog.coverImageData, size: .tile, cacheKey: dog.coverCacheKey),
                            name: dog.name,
                            breedLabel: dog.breedLabel,
                            serialNumber: dog.serialNumber,
                            isCompact: true,
                            placeholderSeed: dog.id.hashValue,
                            showsGuardianTag: dog.isActiveWard,
                            // Every live photo in this dog's gallery, cheap
                            // .tile transcodes, played in sequence on a loop.
                            slides: dog.gallerySlides(tier: .tile)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// One card + a peek of the next, so the carousel reads as scrollable.
    private var wardCardWidth: CGFloat { UIScreen.main.bounds.width * 0.72 }

    // MARK: - The morphing surface (peer-layer pattern)
    //
    // Each state below is its own "box": a simple-shape background layer
    // carrying the shared `matchedGeometryEffect` id, plus a content layer
    // that just crossfades in/out via opacity. Geometry (position/size)
    // interpolation between the two fixed-size boxes is handled entirely by
    // matchedGeometryEffect — no manually-tracked corner-radius state needed.
    // Critically, the live camera preview never carries the geometry effect
    // itself (that made the morph look broken); it's pure crossfade content
    // sitting on top of a plain black rounded rect that does the growing.
    // The chain extends one step further on capture: the camera panel's
    // background hands the "catchSurface" id off to the Gotcha! card itself
    // (see CatchCelebrationView), so pill → viewfinder → card is one
    // continuous morph rather than a hard cut to a modal.

    /// The hero "Catch a doggo" control. `collapsed` swaps it between the
    /// full-width labelled pill and a paw-button-sized circle (icon only). The
    /// corner radius stays `.pill` the whole time — on a 58×58 square that's a
    /// circle — so the frame is the only thing changing, which keeps the
    /// camera morph (matchedGeometryEffect on the same background) intact.
    private func catchButton(collapsed: Bool) -> some View {
        Button(action: openCamera) {
            DoggoColor.marigold.opacity(0.85)
                .clipShape(RoundedRectangle(cornerRadius: DoggoRadius.pill))
                .overlay {
                    Group {
                        if collapsed {
                            Image(systemName: "camera.fill")
                        } else {
                            HStack(spacing: DoggoSpacing.sm) {
                                Image(systemName: "camera.fill")
                                Text("Catch a doggo")
                            }
                        }
                    }
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.cream)
                    .transition(.opacity)
                }
                .glassEffect(.clear.tint(DoggoColor.marigold).interactive(), in: .rect(cornerRadius: DoggoRadius.pill))
                .glassEffectTransition(.identity)
                .matchedGeometryEffect(id: "catchSurface", in: morphNamespace)
                .frame(width: collapsed ? collapsedButtonSize : fullCatchWidth,
                       height: collapsed ? collapsedButtonSize : pawButtonSize)
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    /// Collapse while scrolling down, expand the instant you scroll back up —
    /// and always the pill near the top. Direction is read from the change in
    /// distance-from-the-top-baseline (not the raw offset), so it's immune to
    /// which sign the scroll coordinate uses; the ±4 threshold ignores jitter.
    private func updateCatchCollapse(offset: CGFloat) {
        let baseline = scrollBaseline ?? offset
        if scrollBaseline == nil { scrollBaseline = offset }
        // Signed distance scrolled INTO the content (offset goes negative as you
        // scroll down here). Using a signed value — not abs() — means an
        // overscroll PAST the top (pull-to-refresh rubber-band) reads as a
        // negative "into content", i.e. < 40, so it stays expanded instead of
        // toggling as the abs() distance grew and then sprang back.
        let intoContent = baseline - offset
        let delta = intoContent - lastScrolled
        lastScrolled = intoContent

        if intoContent < 40 {
            setCatchCollapsed(false) // near the top / overscrolling: always full pill
        } else if delta < -4 {
            setCatchCollapsed(false) // moving back toward the top → scrolling up
        } else if delta > 4 {
            setCatchCollapsed(true)  // moving away from the top → scrolling down
        }
    }

    private func setCatchCollapsed(_ value: Bool) {
        guard catchCollapsed != value else { return }
        withAnimation(collapseAnimation) { catchCollapsed = value }
    }

    /// `collapsed` shrinks the "N doses due today" pill into a
    /// `collapsedButtonSize` circle (just the pills glyph), to sit beside the
    /// collapsed catch/paw circles; the shared matchedGeometryEffect id morphs
    /// it between the two forms.
    private func todaysCareChip(collapsed: Bool) -> some View {
        NavigationLink(value: TodaysCareDestination()) {
            Group {
                if collapsed {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DoggoColor.logMedFg)
                        .frame(width: collapsedButtonSize, height: collapsedButtonSize)
                        .background(DoggoColor.cardWhite, in: Circle())
                        .overlay(Circle().stroke(DoggoColor.statusAttnBorder, lineWidth: 1.5))
                } else {
                    HStack(spacing: DoggoSpacing.sm) {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DoggoColor.logMedFg)
                            .frame(width: 24, height: 24)
                            .background(DoggoColor.logMedBg, in: RoundedRectangle(cornerRadius: 8))
                        Text(dosesDueTodayCount == 1 ? "1 dose due today" : "\(dosesDueTodayCount) doses due today")
                            .font(DoggoTextStyle.bodySemibold)
                            .foregroundStyle(DoggoColor.ink)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DoggoColor.marigold)
                    }
                    .padding(.horizontal, DoggoSpacing.md)
                    .padding(.vertical, DoggoSpacing.sm)
                    .background(DoggoColor.cardWhite, in: Capsule())
                    .overlay(Capsule().stroke(DoggoColor.statusAttnBorder, lineWidth: 1.5))
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var pawButton: some View {
        NavigationLink(value: CareDestination()) {
            Image(systemName: "pawprint.fill")
                .foregroundStyle(DoggoColor.marigold)
                .glassCircleChrome(size: catchCollapsed ? collapsedButtonSize : pawButtonSize)
        }
        .buttonStyle(.plain)
    }

    private var cameraPanel: some View {
        ZStack {
            Color.black
                .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
                .matchedGeometryEffect(id: "catchSurface", in: morphNamespace)

            // Mounted only once the growth is finished (showCameraFeed) — the
            // black rounded rect grows first, then the live viewfinder fades in
            // on top of it. Delaying the mount also keeps the AVCaptureSession
            // startup entirely out of the morph animation.
            if showCameraFeed {
                CameraView(
                    onClose: closeCamera,
                    onCaught: handleCaught
                )
                .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
                .transition(.opacity)
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.62)
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
    }

    private func openCamera() {
        withAnimation(morphOpenAnimation) { surfaceState = .camera }
        // Reveal the viewfinder as the panel finishes growing — slightly into
        // the tail of the spring so the live feed comes up a touch sooner.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard surfaceState == .camera else { return }
            withAnimation(.easeInOut(duration: 0.25)) { showCameraFeed = true }
        }
    }

    private func closeCamera() {
        showCameraFeed = false
        withAnimation(morphCloseAnimation) { surfaceState = .idle }
    }

    private func handleCaught(_ dog: CaughtDog) {
        caughtDog = dog
        showCameraFeed = false
        withAnimation(morphAnimation) { surfaceState = .celebration }
    }

    private func returnToIdle() {
        withAnimation(morphAnimation) { surfaceState = .idle }
        // A fresh catch may have changed this device's locality aggregates.
        Task { await publishNeighborhoodPresence() }
    }
}

struct ProfileDestination: Hashable {}
struct CareDestination: Hashable {}
struct MapDestination: Hashable {}
struct PastWardsDestination: Hashable {}
struct TodaysCareDestination: Hashable {}
struct WardsDestination: Hashable {}

#Preview {
    CollectionView()
        .environment(GameCenterAuthProvider(local: UsernameAuthProvider(modelContext: try! ModelContainer(for: UserProfile.self, CaughtDog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext)))
        .modelContainer(for: [UserProfile.self, CaughtDog.self], inMemory: true)
}
