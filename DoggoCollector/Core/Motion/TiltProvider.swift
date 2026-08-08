//
//  TiltProvider.swift
//  DoggoCollector
//
//  A tiny CoreMotion wrapper for the Shelter Pass's "the light moves with you"
//  tilt bloom. Publishes a normalized, clamped, smoothed roll/pitch in -1…1.
//  Device-only: on the Simulator (no device motion) it simply stays at zero and
//  the bloom rests centered — nothing breaks, it just doesn't move.
//

import CoreMotion
import SwiftUI

@MainActor
@Observable
final class TiltProvider {
    /// Normalized, clamped roll/pitch in -1…1. Multiply by a point amount in the
    /// view. Springs toward the raw reading via a simple low-pass each update.
    private(set) var x: CGFloat = 0
    private(set) var y: CGFloat = 0

    private let manager = CMMotionManager()
    /// Radians of tilt that maps to full deflection (the prototype's ±0.35rad).
    private let range: Double = 0.35
    /// Low-pass factor — the "spring(0.35, 0.85)" feel without a physics engine.
    private let smoothing: CGFloat = 0.12

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            let targetX = CGFloat(max(-self.range, min(self.range, m.attitude.roll)) / self.range)
            let targetY = CGFloat(max(-self.range, min(self.range, m.attitude.pitch)) / self.range)
            self.x += (targetX - self.x) * self.smoothing
            self.y += (targetY - self.y) * self.smoothing
        }
    }

    func stop() {
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
    }
}
