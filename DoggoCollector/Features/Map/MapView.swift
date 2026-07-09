//
//  MapView.swift
//  DoggoCollector
//
//  Pins sit at coarsened, neighborhood-level coordinates (see LocationTagger)
//  — never the exact catch location. "Mine" is the original per-dog view;
//  "Neighborhood" (Flow 3) renders only locality-level aggregates, never
//  individual pins — see CommunityStatsProviding's hard-rule comment.
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
    @Query private var catches: [CaughtDog]

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedDog: CaughtDog?
    @State private var selectedLocality: LocalityStat?
    @State private var mapMode: MapMode = .mine
    @State private var locationProvider = LocationProvider()
    @State private var youLocation: CLLocationCoordinate2D?

    private let communityStats: CommunityStatsProviding = LocalCommunityStatsProvider()

    private var localityStats: [LocalityStat] {
        communityStats.localityStats(for: catches)
    }

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
                    ForEach(localityStats) { locality in
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

            VStack(spacing: DoggoSpacing.sm) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(DoggoColor.ink)
                            .frame(width: 44, height: 44)
                            .background(DoggoColor.cardWhite, in: Circle())
                    }
                    Spacer()
                }

                SegmentedTabs(options: MapMode.allCases.map { ($0, $0.rawValue) }, selection: $mapMode)
                    .frame(maxWidth: 240)

                if mapMode == .mine {
                    Text("Locations are rounded for privacy")
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                        .padding(.horizontal, DoggoSpacing.md)
                        .padding(.vertical, DoggoSpacing.xs)
                        .background(DoggoColor.cardWhite, in: Capsule())
                } else {
                    Text("Community total · individual spots stay private")
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                        .padding(.horizontal, DoggoSpacing.md)
                        .padding(.vertical, DoggoSpacing.xs)
                        .background(DoggoColor.cardWhite, in: Capsule())
                }
            }
            .padding(DoggoSpacing.lg)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            youLocation = await locationProvider.currentLocation()?.coordinate
        }
        .sheet(item: $selectedDog) { dog in
            CardDetailView(dog: dog)
        }
        .popover(item: $selectedLocality) { locality in
            localityPopover(locality)
        }
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

    private func localityPill(_ locality: LocalityStat) -> some View {
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

    private func localityPopover(_ locality: LocalityStat) -> some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.sm) {
            Text("\(locality.count) dogs looked after around \(locality.name) this month. You're part of it.")
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.ink)
            Text("Community total · individual spots stay private")
                .font(DoggoTextStyle.caption)
                .foregroundStyle(DoggoColor.inkMuted)
        }
        .padding(DoggoSpacing.lg)
        .frame(maxWidth: 280)
        .presentationCompactAdaptation(.popover)
    }

    private func blobRadius(for count: Int) -> CLLocationDistance {
        300 + Double(count) * 120
    }

    private func blobOpacity(for count: Int) -> Double {
        min(0.15 + Double(count) * 0.05, 0.55)
    }
}
