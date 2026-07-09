//
//  ClinicSheet.swift
//  DoggoCollector
//
//  Mirrors CarePlaceDetailSheet's layout/actions, but reads from the dog's
//  assigned-clinic snapshot rather than a live CarePlace.
//

import SwiftUI
import MapKit

struct ClinicSheet: View {
    let dog: CaughtDog

    private var distanceText: String {
        guard let meters = dog.assignedClinicDistanceMeters else { return "" }
        let km = meters / 1000
        return km < 1 ? "\(Int(meters)) m" : String(format: "%.1f km", km)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.lg) {
            VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
                Text(dog.assignedClinicName ?? "No clinic assigned yet")
                    .font(DoggoTextStyle.displayMedium)
                    .foregroundStyle(DoggoColor.ink)
                Text("Assigned clinic \u{00B7} \(distanceText)")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }

            if let address = dog.assignedClinicAddress {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
            }

            HStack(spacing: DoggoSpacing.md) {
                if let phoneNumber = dog.assignedClinicPhone {
                    PillButton(title: "Call", systemImage: "phone.fill", style: .secondary) {
                        call(phoneNumber)
                    }
                }
                if dog.assignedClinicLatitude != nil {
                    PillButton(title: "Directions", systemImage: "map.fill", action: openInMaps)
                }
            }

            Text("See all nearby care from the paw button on your pack.")
                .font(DoggoTextStyle.caption)
                .foregroundStyle(DoggoColor.inkMuted)

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
        guard let latitude = dog.assignedClinicLatitude, let longitude = dog.assignedClinicLongitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = dog.assignedClinicName
        mapItem.openInMaps()
    }
}
