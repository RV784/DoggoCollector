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
    @Environment(UsernameAuthProvider.self) private var authProvider
    @Query(sort: \CaughtDog.caughtAt, order: .reverse) private var catches: [CaughtDog]

    @Namespace private var morphNamespace
    @State private var surfaceState: SurfaceState = .idle
    @State private var caughtDog: CaughtDog?

    private let mechanic = PackCollectorMechanic()
    private let columns = [
        GridItem(.flexible(), spacing: DoggoSpacing.md),
        GridItem(.flexible(), spacing: DoggoSpacing.md),
    ]

    // Matches the reference morph: a fairly stiff, grounded spring — not the
    // softer springs used for ordinary UI feedback elsewhere in the app.
    private let morphAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DoggoColor.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DoggoSpacing.xl) {
                        header
                        statsRow
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
                        catchButton
                    }
                }
                .padding(.horizontal, DoggoSpacing.lg)
                .padding(.bottom, DoggoSpacing.lg)

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
        }
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
            NavigationLink(value: ProfileDestination()) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(DoggoColor.marigold, in: Circle())
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

    @ViewBuilder
    private var content: some View {
        if catches.isEmpty {
            EmptyStateView()
                .padding(.top, DoggoSpacing.xxl)
        } else {
            LazyVGrid(columns: columns, spacing: DoggoSpacing.md) {
                ForEach(catches) { dog in
                    NavigationLink(value: dog) {
                        DoggoCardView(
                            image: dog.imageData.flatMap(UIImage.init),
                            name: dog.name,
                            breedLabel: dog.breedLabel,
                            serialNumber: dog.serialNumber,
                            isCompact: true,
                            placeholderSeed: dog.id.hashValue
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

    private var catchButton: some View {
        Button(action: openCamera) {
            ZStack {
                DoggoColor.marigold
                    .clipShape(RoundedRectangle(cornerRadius: DoggoRadius.pill))
                    .matchedGeometryEffect(id: "catchSurface", in: morphNamespace)

                HStack(spacing: DoggoSpacing.sm) {
                    Image(systemName: "camera.fill")
                    Text("Catch a doggo")
                }
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(.white)
                .transition(.opacity)
            }
            .frame(height: 56)
        }
        .buttonStyle(ScalePressButtonStyle())
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
        withAnimation(morphAnimation) { surfaceState = .camera }
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
    }
}

struct ProfileDestination: Hashable {}

#Preview {
    CollectionView()
        .environment(UsernameAuthProvider(modelContext: try! ModelContainer(for: UserProfile.self, CaughtDog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
        .modelContainer(for: [UserProfile.self, CaughtDog.self], inMemory: true)
}
