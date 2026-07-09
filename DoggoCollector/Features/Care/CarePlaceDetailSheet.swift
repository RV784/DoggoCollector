//
//  CarePlaceDetailSheet.swift
//  DoggoCollector
//
//  Nearby Care Screen B — presented as a bottom sheet from CareView.
//

import SwiftUI
import MapKit
import CoreLocation

struct CarePlaceDetailSheet: View {
    let place: CarePlace

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.lg) {
            VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
                Text(place.name)
                    .font(DoggoTextStyle.displayMedium)
                    .foregroundStyle(DoggoColor.ink)
                Text(place.distanceText)
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

            if let websiteURL = place.websiteURL {
                TextLinkButton(title: "Visit website") {
                    UIApplication.shared.open(websiteURL)
                }
            }

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
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    private func call(_ phoneNumber: String) {
        let digits = phoneNumber.filter { $0.isNumber }
        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func openInMaps() {
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = place.name
        mapItem.openInMaps()
    }
}
