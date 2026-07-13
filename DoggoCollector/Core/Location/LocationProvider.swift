//
//  LocationProvider.swift
//  DoggoCollector
//

import CoreLocation

@Observable
final class LocationProvider: NSObject {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private let manager = CLLocationManager()
    // An array, not a single slot: a second concurrent caller (e.g. a
    // catch-time call while CameraViewModel's start-of-camera pre-warm call
    // is still in flight) used to silently overwrite the first caller's
    // continuation here, leaking it — the first caller would then hang
    // forever, since only the continuation referenced at the moment
    // didUpdateLocations fires ever got resumed. Every pending caller is
    // resumed together off the same location/error callback now.
    private var pendingContinuations: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func currentLocation() async -> CLLocation? {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
            manager.requestLocation()
        }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(returning: locations.first)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(returning: nil)
        }
    }
}
