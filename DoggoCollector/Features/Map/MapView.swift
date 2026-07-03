//
//  MapView.swift
//  DoggoCollector
//
//  Pins sit at coarsened, neighborhood-level coordinates (see LocationTagger)
//  — never the exact catch location.
//

import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var catches: [CaughtDog]
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedDog: CaughtDog?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $cameraPosition) {
                ForEach(catches) { dog in
                    Annotation(dog.name, coordinate: CLLocationCoordinate2D(latitude: dog.latitude, longitude: dog.longitude)) {
                        pin.onTapGesture { selectedDog = dog }
                    }
                }
            }
            .ignoresSafeArea()

            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(DoggoColor.ink)
                    .frame(width: 44, height: 44)
                    .background(DoggoColor.cardWhite, in: Circle())
            }
            .padding(DoggoSpacing.lg)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedDog) { dog in
            CardDetailView(dog: dog)
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
}
