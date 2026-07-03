//
//  LocationTagger.swift
//  DoggoCollector
//
//  Produces a neighborhood-level label and a coarsened coordinate for a
//  catch — never the exact GPS fix. Privacy-conscious by design, matching
//  what the reference apps in the design brief did for map pins.
//

import CoreLocation

struct CoarseLocation {
    let label: String
    let latitude: Double
    let longitude: Double
}

final class LocationTagger {
    private let geocoder = CLGeocoder()

    /// Rounds a coordinate to roughly ~100m precision so stored/mapped pins
    /// never point at an exact address.
    private func coarsen(_ coordinate: CLLocationCoordinate2D) -> (Double, Double) {
        func round(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
        return (round(coordinate.latitude), round(coordinate.longitude))
    }

    func tag(_ location: CLLocation) async -> CoarseLocation {
        let (lat, lon) = coarsen(location.coordinate)
        let label = await reverseGeocodedLabel(for: location) ?? "Somewhere nearby"
        return CoarseLocation(label: label, latitude: lat, longitude: lon)
    }

    private func reverseGeocodedLabel(for location: CLLocation) async -> String? {
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }
        return placemark.thoroughfare ?? placemark.subLocality ?? placemark.locality
    }
}
