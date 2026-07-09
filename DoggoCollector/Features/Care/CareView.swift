//
//  CareView.swift
//  DoggoCollector
//
//  Nearby Care (Flow 2) — a warm directory, not a diagnostic tool. Entry
//  points: the paw button on Collection, and Card Detail's insight-panel
//  link. Carries its own Profile button — per the nav restructure, Profile
//  now nests one level under Care instead of hanging off Collection.
//
//  Backed by LiveCareDirectory (real MKLocalSearch) — see CLAUDE.md decision
//  #8. Search center prefers the user's actual live location over the mean
//  of their catch history, since "near me" is the whole point of the search.
//

import SwiftUI
import SwiftData
import CoreLocation

struct CareView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var catches: [CaughtDog]

    @State private var category: CareCategory = .vet
    @State private var radiusKm: Double = 5
    @State private var selectedPlace: CarePlace?
    @State private var locationProvider = LocationProvider()

    @State private var places: [CarePlace]?
    @State private var searchFailed = false
    /// The radius actually used for the last completed search — may be
    /// larger than `radiusKm` (see `fetchWithMinimum`), so copy that
    /// references "within N km" stays accurate.
    @State private var lastSearchRadiusKm: Double = 5

    private let directory: CarePlaceProviding = LiveCareDirectory()
    private let minimumResultCount = 10
    /// Shelters/NGOs are genuinely sparse (CLAUDE.md decision #13) — a
    /// strict 5 km cutoff can surface just one real org even though the
    /// city has more. These are the radii tried, in order, until at least
    /// `minimumResultCount` results come back or the list runs out of
    /// tiers — capped at 50 km so a genuinely remote location doesn't
    /// trigger unbounded network calls.
    private let escalationTiersKm: [Double] = [15, 50]

    private var averageCoordinate: CLLocationCoordinate2D? {
        guard !catches.isEmpty else { return nil }
        let lat = catches.map(\.latitude).reduce(0, +) / Double(catches.count)
        let lon = catches.map(\.longitude).reduce(0, +) / Double(catches.count)
        guard lat != 0 || lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var hasLocationPermission: Bool {
        switch locationProvider.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: true
        default: false
        }
    }

    var body: some View {
        ZStack {
            DoggoColor.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: DoggoSpacing.lg) {
                    topBar
                    header

                    if hasLocationPermission {
                        scoutBanner
                        categoryPicker
                    }
                }
                .padding(.horizontal, DoggoSpacing.lg)
                .padding(.top, DoggoSpacing.lg)
                .padding(.bottom, hasLocationPermission ? DoggoSpacing.lg : 0)

                if hasLocationPermission {
                    content
                } else {
                    noPermissionState
                        .padding(.horizontal, DoggoSpacing.lg)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { locationProvider.requestAuthorization() }
        .task(id: "\(category)-\(radiusKm)-\(hasLocationPermission)") {
            guard hasLocationPermission else { return }
            await search()
        }
        .sheet(item: $selectedPlace) { place in
            CarePlaceDetailSheet(place: place)
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(DoggoColor.ink)
                    .frame(width: 44, height: 44)
                    .background(DoggoColor.cardWhite, in: Circle())
            }
            .buttonStyle(ScalePressButtonStyle())
            Spacer()
            NavigationLink(value: ProfileDestination()) {
                Image(systemName: "person.fill")
                    .foregroundStyle(DoggoColor.ink)
                    .frame(width: 44, height: 44)
                    .background(DoggoColor.cardWhite, in: Circle())
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
            Text("CARE")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)
            Text("Nearby Care")
                .font(DoggoTextStyle.displayMedium)
                .foregroundStyle(DoggoColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoutBanner: some View {
        HStack(spacing: DoggoSpacing.sm) {
            ScoutMascot(expression: .idle, size: 40)
            Text("Scout found \(places?.count ?? 0) \(category.title.lowercased()) nearby")
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(DoggoColor.ink)
            Spacer()
        }
        .padding(DoggoSpacing.md)
        .background(DoggoColor.chipCream, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
    }

    private var categoryPicker: some View {
        SegmentedTabs(options: CareCategory.allCases.map { ($0, $0.title) }, selection: $category)
    }

    @ViewBuilder
    private var content: some View {
        if searchFailed {
            searchFailedState
                .padding(.horizontal, DoggoSpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let places {
            if places.isEmpty {
                noResultsState
                    .padding(.horizontal, DoggoSpacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DoggoSpacing.sm) {
                        ForEach(places) { place in
                            Button {
                                selectedPlace = place
                            } label: {
                                placeRow(place)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Listings come from Apple Maps \u{2014} details may occasionally be out of date.")
                            .font(DoggoTextStyle.caption)
                            .foregroundStyle(DoggoColor.inkMuted)
                            .padding(.top, DoggoSpacing.sm)
                    }
                    .padding(.horizontal, DoggoSpacing.lg)
                    .padding(.top, DoggoSpacing.md)
                }
                .contentMargins(.bottom, DoggoSpacing.xxl, for: .scrollContent)
                .refreshable { await search() }
            }
        } else {
            loadingState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var loadingState: some View {
        VStack(spacing: DoggoSpacing.lg) {
            Spacer()
            ScoutMascot(expression: .curious, size: 90)
            VStack(spacing: DoggoSpacing.sm) {
                Text("Scout's sniffing around the neighborhood\u{2026}")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
                BouncingDotsView()
            }
            Spacer()
        }
    }

    private var searchFailedState: some View {
        VStack(spacing: DoggoSpacing.lg) {
            Spacer()
            ScoutMascot(expression: .sad, size: 90)
                .opacity(0.8)
            VStack(spacing: DoggoSpacing.xs) {
                Text("Scout couldn't sniff out the neighborhood")
                    .font(DoggoTextStyle.headline)
                    .foregroundStyle(DoggoColor.ink)
                Text("Check your connection and try again.")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            .multilineTextAlignment(.center)
            PillButton(title: "Try again") {
                Task { await search() }
            }
            .padding(.horizontal, DoggoSpacing.xxl)
            Spacer()
        }
    }

    private var noPermissionState: some View {
        VStack(spacing: DoggoSpacing.lg) {
            Spacer()
            ScoutMascot(expression: .sad, size: 100)
                .opacity(0.8)
                .floatingIdle()
            VStack(spacing: DoggoSpacing.xs) {
                Text("Scout needs to know where you are")
                    .font(DoggoTextStyle.headline)
                    .foregroundStyle(DoggoColor.ink)
                Text("Turn on location to see care nearby.")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            .multilineTextAlignment(.center)
            PillButton(title: "Turn on location", action: requestLocation)
                .padding(.horizontal, DoggoSpacing.xxl)
            Spacer()
        }
    }

    private var noResultsState: some View {
        VStack(spacing: DoggoSpacing.lg) {
            Spacer()
            ScoutMascot(expression: .sad, size: 90)
                .opacity(0.8)
            Text("No \(category.title.lowercased()) within \(Int(lastSearchRadiusKm)) km yet")
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func placeRow(_ place: CarePlace) -> some View {
        HStack(alignment: .top, spacing: DoggoSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                if place.category == .shelter, let description = place.description {
                    Text(description)
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                } else if place.category == .shelter {
                    Text(place.address)
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                }
                Text(place.distanceText)
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            Spacer()
        }
        .padding(DoggoSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
    }

    private func requestLocation() {
        switch locationProvider.authorizationStatus {
        case .notDetermined:
            locationProvider.requestAuthorization()
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    /// Resolves a search center (live location, falling back to the mean of
    /// the user's catch history) and calls the directory, racing a ~500ms
    /// minimum delay so the loading state always reads as real work rather
    /// than a flash (same idiom as InsightPanelView). Also used by
    /// pull-to-refresh, so a lingering visit can pick up a fresher location
    /// fix without leaving and re-entering the screen.
    private func search() async {
        places = nil
        searchFailed = false

        guard let center = await locationProvider.currentLocation()?.coordinate ?? averageCoordinate else {
            searchFailed = true
            return
        }

        async let minimumDelay: ()? = try? Task.sleep(for: .milliseconds(500))
        do {
            let (result, searchedRadius) = try await fetchWithMinimum(center: center)
            _ = await minimumDelay
            withAnimation(.easeInOut(duration: 0.3)) {
                places = result
                lastSearchRadiusKm = searchedRadius
            }
        } catch {
            _ = await minimumDelay
            withAnimation(.easeInOut(duration: 0.3)) {
                searchFailed = true
            }
        }
    }

    /// Tries `radiusKm` first, then escalates through `escalationTiersKm`
    /// until at least `minimumResultCount` results come back or the tiers
    /// run out — at that point, whatever came back is genuinely all that's
    /// nearby. Returns the radius actually used so the UI can report it
    /// accurately.
    private func fetchWithMinimum(center: CLLocationCoordinate2D) async throws -> (places: [CarePlace], radiusKm: Double) {
        var radius = radiusKm
        var result = try await directory.places(category: category, around: center, radiusKm: radius)
        for tier in escalationTiersKm where result.count < minimumResultCount && tier > radius {
            radius = tier
            result = try await directory.places(category: category, around: center, radiusKm: radius)
        }
        return (result, radius)
    }
}

#Preview {
    CareView()
        .modelContainer(for: [UserProfile.self, CaughtDog.self], inMemory: true)
}
