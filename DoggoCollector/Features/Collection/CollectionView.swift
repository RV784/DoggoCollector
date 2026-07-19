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

private enum PackTab: Hashable {
    case all, wards
}

struct CollectionView: View {
    @Environment(GameCenterAuthProvider.self) private var authProvider
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaughtDog.caughtAt, order: .reverse) private var catches: [CaughtDog]

    @Namespace private var morphNamespace
    @State private var surfaceState: SurfaceState = .idle
    @State private var caughtDog: CaughtDog?
    @State private var packTab: PackTab = .all

    private var hasWards: Bool { catches.contains { $0.isWard } }
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

    // TEMP-PAYWALL-PREVIEW: remove with the matching .sheet below.
    @State private var tempPaywallPreview = ProcessInfo.processInfo.arguments.contains("-previewPaywall")

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DoggoColor.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DoggoSpacing.xl) {
                        header
                        statsRow
                        if hasWards {
                            packTabPicker
                        }
                        content
                    }
                    .padding(DoggoSpacing.lg)
                    .padding(.bottom, 110)
                }
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
                            HStack(spacing: DoggoSpacing.md) {
                                catchButton
                                pawButton
                            }
                        }
                    }
                }
                .padding(.horizontal, DoggoSpacing.lg)
                .padding(.bottom, DoggoSpacing.lg)

                // Stable anchor for the "N doses due today" entry chip —
                // only when something's genuinely due, and only in .idle
                // (must never float over the camera panel or celebration).
                ZStack {
                    if surfaceState == .idle, dosesDueTodayCount > 0 {
                        HStack {
                            todaysCareChip
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, DoggoSpacing.lg)
                    }
                }
                .padding(.bottom, 90)

                // Stable anchor for the active camera panel.
                ZStack {
                    if surfaceState == .camera {
                        cameraPanel
                            .padding(.horizontal, DoggoSpacing.lg)
                            .padding(.bottom, DoggoSpacing.lg)
                    }
                }

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
            .navigationDestination(for: CaughtDog.self) { dog in
                CardDetailView(dog: dog)
            }
            .navigationDestination(for: ProfileDestination.self) { _ in ProfileView() }
            .navigationDestination(for: CareDestination.self) { _ in CareView() }
            .navigationDestination(for: MapDestination.self) { _ in MapView() }
            .navigationDestination(for: PastWardsDestination.self) { _ in PastWardsView() }
            .navigationDestination(for: TodaysCareDestination.self) { _ in TodaysCareView() }
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

    private var statsRow: some View {
        HStack(spacing: DoggoSpacing.sm) {
            ForEach(mechanic.stats(for: catches)) { stat in
                StatChip(text: stat.label, isActive: stat.isPrimary)
            }
        }
    }

    private var packTabPicker: some View {
        SegmentedTabs(options: [(.all, "All Catches"), (.wards, "Guardian Wards")], selection: $packTab)
    }

    @ViewBuilder
    private var content: some View {
        if catches.isEmpty {
            EmptyStateView()
                .padding(.top, DoggoSpacing.xxl)
        } else if hasWards && packTab == .wards {
            WardsListView(catches: catches)
        } else {
            LazyVGrid(columns: columns, spacing: DoggoSpacing.md) {
                ForEach(catches) { dog in
                    NavigationLink(value: dog) {
                        DoggoCardView(
                            image: DogPhoto.image(from: dog.imageData, size: .tile, cacheKey: dog.id.uuidString),
                            name: dog.name,
                            breedLabel: dog.breedLabel,
                            serialNumber: dog.serialNumber,
                            isCompact: true,
                            placeholderSeed: dog.id.hashValue,
                            showsGuardianTag: dog.isActiveWard,
                            // Prefer the cheap .tile transcode (decision #21's
                            // grid-tier addition); fall back to the full
                            // 720x720 movie for catches made before that
                            // field existed, rather than showing no movie
                            // at all for them.
                            liveMovieURL: dog.livePhotoMovieTileData.flatMap { LiveMovieStore.url(for: $0, id: dog.id.uuidString, tier: .tile) }
                                ?? dog.livePhotoMovieData.flatMap { LiveMovieStore.url(for: $0, id: dog.id.uuidString, tier: .full) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

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

//    private var catchButton: some View {
//        Button(action: openCamera) {
//            ZStack {
//                // Liquid Glass on the hero pill (CLAUDE.md's Liquid Glass
//                // decision, Step 4 — isolated/revertible): marigold stays
//                // underneath at reduced opacity so the mid-morph crossfade
//                // to the black camera panel still reads as it does today;
//                // glass adds lensing on top rather than replacing the brand
//                // color. `.glassEffectTransition(.identity)` stops the glass
//                // material from running its own transition when this view
//                // leaves the hierarchy — matchedGeometryEffect alone owns
//                // the frame interpolation, so the two systems don't fight.
//                // Glass is applied before matchedGeometryEffect so the
//                // geometry effect wraps the final rendered element.
//                DoggoColor.marigold.opacity(0.85)
//                    .clipShape(RoundedRectangle(cornerRadius: DoggoRadius.pill))
//                    .glassEffect(.clear.tint(DoggoColor.marigold).interactive(), in: .rect(cornerRadius: DoggoRadius.pill))
//                    .glassEffectTransition(.identity)
//                    .matchedGeometryEffect(id: "catchSurface", in: morphNamespace)
//
//                HStack(spacing: DoggoSpacing.sm) {
//                    Image(systemName: "camera.fill")
//                    Text("Catch a doggo")
//                }
//                .font(DoggoTextStyle.bodySemibold)
//                .foregroundStyle(.purple)
//                .transition(.opacity)
//            }
//            .frame(height: 56)
//        }
//        .buttonStyle(ScalePressButtonStyle())
//    }
    
    private var catchButton: some View {
        Button(action: openCamera) {
            DoggoColor.marigold.opacity(0.85)
                .clipShape(RoundedRectangle(cornerRadius: DoggoRadius.pill))
                .overlay {
                    HStack(spacing: DoggoSpacing.sm) {
                        Image(systemName: "camera.fill")
                        Text("Catch a doggo")
                    }
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.cream)
                    .transition(.opacity)
                }
                .glassEffect(.clear.tint(DoggoColor.marigold).interactive(), in: .rect(cornerRadius: DoggoRadius.pill))
                .glassEffectTransition(.identity)
                .matchedGeometryEffect(id: "catchSurface", in: morphNamespace)
                .frame(height: 56)
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    private var todaysCareChip: some View {
        NavigationLink(value: TodaysCareDestination()) {
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
            .overlay(
                Capsule().stroke(DoggoColor.statusAttnBorder, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var pawButton: some View {
        NavigationLink(value: CareDestination()) {
            Image(systemName: "pawprint.fill")
                .foregroundStyle(DoggoColor.marigold)
                .glassCircleChrome(size: 58)
        }
        .buttonStyle(.plain)
    }

    private var cameraPanel: some View {
        ZStack {
            Color.black
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .matchedGeometryEffect(id: "catchSurface", in: morphNamespace)

            CameraView(
                onClose: closeCamera,
                onCaught: handleCaught
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .transition(.opacity)
        }
        .frame(height: UIScreen.main.bounds.height * 0.62)
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
    }

    private func openCamera() {
        withAnimation(morphOpenAnimation) { surfaceState = .camera }
    }

    private func closeCamera() {
        withAnimation(morphAnimation) { surfaceState = .idle }
    }

    private func handleCaught(_ dog: CaughtDog) {
        caughtDog = dog
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

#Preview {
    CollectionView()
        .environment(GameCenterAuthProvider(local: UsernameAuthProvider(modelContext: try! ModelContainer(for: UserProfile.self, CaughtDog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext)))
        .modelContainer(for: [UserProfile.self, CaughtDog.self], inMemory: true)
}
