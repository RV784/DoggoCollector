//
//  CarePlaceDetailSheet.swift
//  DoggoCollector
//
//  Nearby Care Screen B — presented as a bottom sheet from CareView.
//

import SwiftUI
import MapKit

struct CarePlaceDetailSheet: View {
    let place: CarePlace

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.lg) {
            VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
                Text(place.name)
                    .font(DoggoTextStyle.displayMedium)
                    .foregroundStyle(DoggoColor.ink)
                HStack(spacing: DoggoSpacing.sm) {
                    if place.category == .vet {
                        TagChip(text: place.isOpenNow ? "Open now" : "Closed", prominent: place.isOpenNow)
                    }
                    Text(place.distanceText)
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                }
            }

            if place.category == .vet, place.is24Hour {
                Label("Open 24 hours", systemImage: "clock.fill")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }

            if let description = place.description {
                Text(description)
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.ink)
            }

            Label(place.address, systemImage: "mappin.and.ellipse")
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.inkMuted)

            HStack(spacing: DoggoSpacing.md) {
                if let phoneNumber = place.phoneNumber {
                    PillButton(title: "Call", systemImage: "phone.fill", style: .secondary) {
                        call(phoneNumber)
                    }
                }
                PillButton(title: "Open in Maps", systemImage: "map.fill", action: openInMaps)
            }

            Spacer()
        }
        .padding(DoggoSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DoggoColor.cream.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func call(_ phoneNumber: String) {
        let digits = phoneNumber.filter { $0.isNumber }
        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func openInMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        mapItem.name = place.name
        mapItem.openInMaps()
    }
}
