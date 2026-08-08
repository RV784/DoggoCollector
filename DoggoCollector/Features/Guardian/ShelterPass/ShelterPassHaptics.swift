//
//  ShelterPassHaptics.swift
//  DoggoCollector
//
//  The Issuance Ceremony's haptic score (Shelter Pass.dc.html · "HAPTICS"):
//  a light tick as the light comes up, a soft one as the photo lands, silence
//  through the field stagger, one HEAVY hit at the seal press — the only heavy
//  hit in the whole app — and a settle. Kept in one place so the timing sheet
//  and the feedback stay together.
//

import UIKit

@MainActor
struct ShelterPassHaptics {
    enum Kind { case light, soft, heavy, selection }

    func play(_ kind: Kind) {
        switch kind {
        case .light:
            let g = UIImpactFeedbackGenerator(style: .light); g.impactOccurred(intensity: 0.4)
        case .soft:
            let g = UIImpactFeedbackGenerator(style: .soft); g.impactOccurred()
        case .heavy:
            let g = UIImpactFeedbackGenerator(style: .heavy); g.impactOccurred(intensity: 1.0)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
