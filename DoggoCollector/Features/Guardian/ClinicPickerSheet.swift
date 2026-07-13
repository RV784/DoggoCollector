//
//  ClinicPickerSheet.swift
//  DoggoCollector
//
//  Lets a Guardian pick or change a ward's assigned clinic by hand instead
//  of only ever getting whatever GuardianPledgeSheet.assignNearestClinic()
//  auto-picked at pledge time. Mirrors CareView's live-search UX (same
//  loading/error/empty idioms, same row style), scoped to vets only.
//

import SwiftUI
import CoreLocation

struct ClinicPickerSheet: View {
    let dog: CaughtDog
    var onSelect: (CarePlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var places: [CarePlace]?
    @State private var searchFailed = false
    @State private var locationProvider = LocationProvider()

    private let directory: CarePlaceProviding = LiveCareDirectory()
    private let radiusKm: Double = 10

    /// The dog's own coordinates first — they're a neighborhood dog, so
    /// that's the most relevant center — falling back to the user's live
    /// location, matching the priority `assignNearestClinic()` effectively
    /// uses today.
    private var dogCoordinate: CLLocationCoordinate2D? {
        guard dog.latitude != 0 || dog.longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: dog.latitude, longitude: dog.longitude)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DoggoSpacing.lg) {
                Text("Choose \(dog.name)'s clinic")
                    .font(DoggoTextStyle.headline)
                    .foregroundStyle(DoggoColor.ink)

                searchField
            }
            .padding(.horizontal, DoggoSpacing.lg)
            .padding(.top, DoggoSpacing.lg)
            .padding(.bottom, DoggoSpacing.md)

            content
        }
        .background(DoggoColor.cream.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task(id: searchText) {
            // .task(id:)'s cancel-on-replace gives this a debounce for
            // free — a fast typer just cancels the stale sleep before it
            // ever fires a search (same idiom as CareView's own search).
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    private var searchField: some View {
        HStack(spacing: DoggoSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DoggoColor.inkMuted)
            TextField("Search clinics", text: $searchText)
                .font(DoggoTextStyle.bodyRegular)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.vertical, DoggoSpacing.md)
        .padding(.horizontal, DoggoSpacing.lg)
        .background(DoggoColor.cardWhite, in: Capsule())
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    @ViewBuilder
    private var content: some View {
        if searchFailed {
            errorState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let places {
            if places.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DoggoSpacing.sm) {
                        ForEach(places) { place in
                            Button {
                                onSelect(place)
                                dismiss()
                            } label: {
                                placeRow(place)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DoggoSpacing.lg)
                    .padding(.top, DoggoSpacing.md)
                }
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

    private var errorState: some View {
        VStack(spacing: DoggoSpacing.lg) {
            Spacer()
            ScoutMascot(expression: .sad, size: 90)
                .opacity(0.8)
            Text("Scout couldn't sniff out the neighborhood")
                .font(DoggoTextStyle.headline)
                .foregroundStyle(DoggoColor.ink)
                .multilineTextAlignment(.center)
            PillButton(title: "Try again") {
                Task { await search() }
            }
            .padding(.horizontal, DoggoSpacing.xxl)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: DoggoSpacing.lg) {
            Spacer()
            ScoutMascot(expression: .sad, size: 90)
                .opacity(0.8)
            Text("No vets found \u{2014} try a different search")
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    /// Matches on name + coordinate, since the assigned-clinic snapshot on
    /// `CaughtDog` has no stable id to compare against a fresh `CarePlace`.
    private func isCurrentlyAssigned(_ place: CarePlace) -> Bool {
        guard let name = dog.assignedClinicName,
              let latitude = dog.assignedClinicLatitude,
              let longitude = dog.assignedClinicLongitude else { return false }
        return name == place.name
            && abs(latitude - place.coordinate.latitude) < 0.0001
            && abs(longitude - place.coordinate.longitude) < 0.0001
    }

    private func placeRow(_ place: CarePlace) -> some View {
        HStack(alignment: .top, spacing: DoggoSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                Text(place.distanceText)
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            Spacer()
            if isCurrentlyAssigned(place) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DoggoColor.marigold)
            }
        }
        .padding(DoggoSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
    }

    private func search() async {
        let center: CLLocationCoordinate2D?
        if let dogCoordinate {
            center = dogCoordinate
        } else {
            center = await locationProvider.currentLocation()?.coordinate
        }
        guard let center else {
            withAnimation(.easeInOut(duration: 0.3)) { searchFailed = true }
            return
        }
        do {
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = trimmed.isEmpty
                ? try await directory.places(category: .vet, around: center, radiusKm: radiusKm)
                : try await directory.searchVets(matching: trimmed, around: center, radiusKm: radiusKm)
            withAnimation(.easeInOut(duration: 0.3)) {
                places = result
                searchFailed = false
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                searchFailed = true
            }
        }
    }
}
