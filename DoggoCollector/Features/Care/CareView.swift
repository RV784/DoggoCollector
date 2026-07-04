//
//  CareView.swift
//  DoggoCollector
//
//  Nearby Care (Flow 2) — a warm directory, not a diagnostic tool. Entry
//  points: the paw button on Collection, and Card Detail's insight-panel
//  link. Carries its own Profile button — per the nav restructure, Profile
//  now nests one level under Care instead of hanging off Collection.
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

    private var directory: CarePlaceProviding {
        MockCareDirectory(center: averageCoordinate)
    }

    private var averageCoordinate: CLLocationCoordinate2D? {
        guard !catches.isEmpty else { return nil }
        let lat = catches.map(\.latitude).reduce(0, +) / Double(catches.count)
        let lon = catches.map(\.longitude).reduce(0, +) / Double(catches.count)
        guard lat != 0 || lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var visiblePlaces: [CarePlace] {
        directory.places(category: category).filter { $0.distanceMeters <= radiusKm * 1000 }
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

            VStack(spacing: DoggoSpacing.lg) {
                topBar
                header

                if hasLocationPermission {
                    scoutBanner
                    categoryPicker
                    content
                } else {
                    noPermissionState
                }
            }
            .padding(DoggoSpacing.lg)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { locationProvider.requestAuthorization() }
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
            Text("Scout found \(visiblePlaces.count) \(category.title.lowercased()) nearby")
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(DoggoColor.ink)
            Spacer()
        }
        .padding(DoggoSpacing.md)
        .background(DoggoColor.chipCream, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
    }

    private var categoryPicker: some View {
        Picker("Category", selection: $category) {
            ForEach(CareCategory.allCases, id: \.self) { cat in
                Text(cat.title).tag(cat)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var content: some View {
        if visiblePlaces.isEmpty {
            noResultsState
        } else {
            ScrollView {
                LazyVStack(spacing: DoggoSpacing.sm) {
                    ForEach(visiblePlaces) { place in
                        Button {
                            selectedPlace = place
                        } label: {
                            placeRow(place)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, DoggoSpacing.lg)
            }
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
            Text("No \(category.title.lowercased()) within \(Int(radiusKm)) km yet")
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.inkMuted)
                .multilineTextAlignment(.center)
            if radiusKm < 15 {
                TextLinkButton(title: "Widen to 15 km") { radiusKm = 15 }
            }
            Spacer()
        }
    }

    private func placeRow(_ place: CarePlace) -> some View {
        HStack(alignment: .top, spacing: DoggoSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                if place.category == .vet, place.is24Hour {
                    Text("Open 24 hours")
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                }
                if place.category == .shelter, let description = place.description {
                    Text(description)
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                }
                Text(place.distanceText)
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            Spacer()
            if place.category == .vet {
                TagChip(text: place.isOpenNow ? "Open now" : "Closed", prominent: place.isOpenNow)
            }
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
}

#Preview {
    CareView()
        .modelContainer(for: [UserProfile.self, CaughtDog.self], inMemory: true)
}
