//
//  MapView.swift
//  DoggoCollector
//
//  Pins sit at coarsened, neighborhood-level coordinates (see LocationTagger)
//  — never the exact catch location. "Mine" is the original per-dog view;
//  "Neighborhood" (Flow 3) renders only locality-level aggregates, never
//  individual pins — now backed by REAL multi-user data (CloudKit public
//  database via CloudKitCommunityStatsProvider; see
//  ~/Documents/neighborhood_map_community_data.md).
//
//  HARD RULE (unchanged from the local-only era): the Neighborhood branch
//  only ever touches locality aggregates. Contributor names attach to a
//  *locality*, never to a pin or coordinate — explicit product decision
//  ("names at locality level"), enforced by the record schema itself.
//

import SwiftUI
import MapKit
import SwiftData

private enum MapMode: String, CaseIterable, Hashable {
    case mine = "Mine"
    case neighborhood = "Neighborhood"
}

struct MapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameCenterAuthProvider.self) private var authProvider
    @Query private var catches: [CaughtDog]

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedDog: CaughtDog?
    @State private var selectedLocality: CommunityLocalityStat?
    @State private var mapMode: MapMode = .mine
    @State private var locationProvider = LocationProvider()
    @State private var youLocation: CLLocationCoordinate2D?

    @State private var communityStats: [CommunityLocalityStat]?
    @State private var communityLoadFailed = false
    @AppStorage(NeighborhoodPublisher.consentKey) private var shareConsent = false
    @AppStorage(NeighborhoodPublisher.consentSeenKey) private var hasSeenConsentAsk = false

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                if mapMode == .mine {
                    ForEach(catches) { dog in
                        Annotation(dog.name, coordinate: CLLocationCoordinate2D(latitude: dog.latitude, longitude: dog.longitude)) {
                            pin.onTapGesture { selectedDog = dog }
                        }
                    }
                    if let youLocation {
                        MapCircle(center: youLocation, radius: 300)
                            .foregroundStyle(DoggoColor.sky.opacity(0.25))
                        Annotation("You", coordinate: youLocation) {
                            youDot
                        }
                    }
                } else {
                    ForEach(communityStats ?? []) { locality in
                        let coordinate = CLLocationCoordinate2D(latitude: locality.latitude, longitude: locality.longitude)
                        MapCircle(center: coordinate, radius: blobRadius(for: locality.count))
                            .foregroundStyle(DoggoColor.marigold.opacity(blobOpacity(for: locality.count)))
                        Annotation(locality.name, coordinate: coordinate) {
                            localityPill(locality)
                                .onTapGesture { selectedLocality = locality }
                        }
                    }
                }
            }
            .ignoresSafeArea()

            GlassEffectContainer {
                VStack(spacing: DoggoSpacing.sm) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(DoggoColor.ink)
                                .glassCircleChrome(size: 44)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }

                    SegmentedTabs(options: MapMode.allCases.map { ($0, $0.rawValue) }, selection: $mapMode)
                        .frame(maxWidth: 240)

                    statusCaption
                }
            }
            .padding(DoggoSpacing.lg)

            if mapMode == .neighborhood && !hasSeenConsentAsk {
                consentCard
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(DoggoSpacing.lg)
                    .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            youLocation = await locationProvider.currentLocation()?.coordinate
        }
        .task(id: mapMode) {
            guard mapMode == .neighborhood else { return }
            await loadCommunityStats()
        }
        .sheet(item: $selectedDog) { dog in
            // Wrapped in its own stack — CardDetailView's toolbar (native
            // nav bar) needs a NavigationStack ancestor to render at all,
            // and this sheet doesn't share Collection's outer stack. The
            // two destinations below mirror the subset of Collection's
            // registrations reachable from within Card Detail here
            // ("Find nearby care" → Care → its own Profile button).
            NavigationStack {
                CardDetailView(dog: dog)
                    .navigationDestination(for: CareDestination.self) { _ in CareView() }
                    .navigationDestination(for: ProfileDestination.self) { _ in ProfileView() }
            }
        }
        .popover(item: $selectedLocality) { locality in
            localityPopover(locality)
        }
    }

    // MARK: - Community data

    private func loadCommunityStats() async {
        communityLoadFailed = false
        guard let center = neighborhoodCenter else {
            // No live location and no located catches — nothing to center
            // a community query on. Render as an honest empty state.
            communityStats = []
            return
        }
        do {
            communityStats = try await CloudKitCommunityStatsProvider().neighborhoodStats(
                around: center,
                radiusKm: 25,
                localCatches: catches,
                ownIdentity: NeighborhoodPublisher.identity(teamPlayerID: authProvider.teamPlayerID)
            )
        } catch {
            communityLoadFailed = true
        }
    }

    private var neighborhoodCenter: CLLocationCoordinate2D? {
        if let youLocation { return youLocation }
        let located = catches.filter { !($0.latitude == 0 && $0.longitude == 0) }
        guard !located.isEmpty else { return nil }
        return CLLocationCoordinate2D(
            latitude: located.map(\.latitude).reduce(0, +) / Double(located.count),
            longitude: located.map(\.longitude).reduce(0, +) / Double(located.count)
        )
    }

    // MARK: - Chrome

    @ViewBuilder
    private var statusCaption: some View {
        if mapMode == .mine {
            captionPill("Locations are rounded for privacy")
        } else if communityLoadFailed {
            Button {
                Task { await loadCommunityStats() }
            } label: {
                captionPill("Scout couldn't fetch the neighborhood — tap to retry")
            }
            .buttonStyle(.plain)
        } else if communityStats == nil {
            captionPill("Scout's sniffing out the neighborhood\u{2026}")
        } else if communityStats?.isEmpty == true {
            captionPill("No dogs looked after around here yet — be the first")
        } else {
            captionPill("Community totals · names by neighborhood, never exact spots")
        }
    }

    private func captionPill(_ text: String) -> some View {
        Text(text)
            .font(DoggoTextStyle.caption)
            .foregroundStyle(DoggoColor.inkOffWhite)
            .padding(.horizontal, DoggoSpacing.md)
            .padding(.vertical, DoggoSpacing.xs)
            .glassEffect(.regular, in: .capsule)
    }

    /// One-time ask before this person's own name/counts get published —
    /// reading the community map never requires consent, only appearing
    /// on it does (see NeighborhoodPublisher's header).
    private var consentCard: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            HStack(alignment: .top, spacing: DoggoSpacing.sm) {
                ScoutMascot(expression: .idle, size: 44)
                Text("Show your pack on the neighborhood map? Others will see your name and totals by neighborhood — never exact spots. You can change this anytime in Settings.")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DoggoSpacing.md) {
                PillButton(title: "Show my pack") {
                    hasSeenConsentAsk = true
                    shareConsent = true
                    Task {
                        await NeighborhoodPublisher.publishIfNeeded(
                            catches: catches,
                            displayName: authProvider.currentUsername,
                            teamPlayerID: authProvider.teamPlayerID
                        )
                        await loadCommunityStats()
                    }
                }
                TextLinkButton(title: "Not now") {
                    hasSeenConsentAsk = true
                }
            }
        }
        .padding(DoggoSpacing.lg)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }

    private var pin: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(DoggoColor.marigold, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private var youDot: some View {
        Circle()
            .fill(DoggoColor.marigold)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private func localityPill(_ locality: CommunityLocalityStat) -> some View {
        HStack(spacing: 4) {
            Text(locality.name)
            Text("· \(locality.count)")
                .fontWeight(.bold)
        }
        .font(DoggoTextStyle.caption)
        .foregroundStyle(DoggoColor.ink)
        .padding(.horizontal, DoggoSpacing.sm)
        .padding(.vertical, 4)
        .background(DoggoColor.cardWhite, in: Capsule())
    }

    private func localityPopover(_ locality: CommunityLocalityStat) -> some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.sm) {
            Text(popoverHeadline(for: locality))
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.ink)
            Text("Community total · names by neighborhood, never exact spots")
                .font(DoggoTextStyle.caption)
                .foregroundStyle(DoggoColor.inkMuted)
        }
        .padding(DoggoSpacing.lg)
        .frame(maxWidth: 280)
        .presentationCompactAdaptation(.popover)
    }

    /// "rajat123 & 2 others look after 7 dogs around Indiranagar. You're
    /// part of it." — one leading name keeps the popover short; the full
    /// contributor list never renders anywhere (locality-level attribution
    /// is the ceiling, not the floor).
    private func popoverHeadline(for locality: CommunityLocalityStat) -> String {
        let dogs = "\(locality.count) \(locality.count == 1 ? "dog" : "dogs")"
        let suffix = locality.includesOwn ? " You're part of it." : ""
        guard let first = locality.contributorNames.first else {
            return locality.includesOwn
                ? "You look after \(dogs) around \(locality.name)."
                : "\(dogs) looked after around \(locality.name)."
        }
        let others = locality.contributorNames.count - 1 + (locality.includesOwn ? 1 : 0)
        let who = others > 0 ? "\(first) & \(others) \(others == 1 ? "other" : "others")" : first
        return "\(who) look after \(dogs) around \(locality.name).\(suffix)"
    }

    private func blobRadius(for count: Int) -> CLLocationDistance {
        300 + Double(count) * 120
    }

    private func blobOpacity(for count: Int) -> Double {
        min(0.15 + Double(count) * 0.05, 0.55)
    }
}
