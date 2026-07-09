//
//  GuardianTypes.swift
//  DoggoCollector
//
//  Guardian Mode's shared vocabulary. Display metadata (title, icon, colors)
//  lives as computed vars here so every view (dossier, wards list, pledge
//  sheet, shelter pass) reuses the same source instead of re-switching on
//  the raw case in each place.
//

import Foundation
import SwiftUI

enum WardStatus: String, Codable, CaseIterable {
    case active, adopted, passed, lostContact

    var displayTitle: String {
        switch self {
        case .active: "Active"
        case .adopted: "Adopted"
        case .passed: "Passed away"
        case .lostContact: "Lost contact"
        }
    }

    var menuSubtitle: String? {
        switch self {
        case .active: nil
        case .adopted: "Found a forever home"
        case .passed: "Kept in memory, gently"
        case .lostContact: nil
        }
    }

    var icon: String {
        switch self {
        case .active: "pawprint.fill"
        case .adopted: "heart.fill"
        case .passed: "leaf.fill"
        case .lostContact: "questionmark.circle"
        }
    }

    /// Toast copy shown when a ward is archived to Past Wards via this status.
    var archiveToast: String {
        switch self {
        case .adopted: "A forever home ✓ — Past Wards"
        case .passed: "Kept in memory — Past Wards"
        case .lostContact: "Moved to Past Wards"
        case .active: ""
        }
    }
}

enum SterilizationStatus: String, Codable, CaseIterable {
    case done, notYet, unknown
}

enum CareEntryType: String, Codable, CaseIterable {
    case fed, medicated, injuryCheck, vaccinated

    var title: String {
        switch self {
        case .fed: "Fed"
        case .medicated: "Medicated"
        case .injuryCheck: "Injury check"
        case .vaccinated: "Vaccinated"
        }
    }

    var icon: String {
        switch self {
        case .fed: "fork.knife"
        case .medicated: "pills.fill"
        case .injuryCheck: "cross.case.fill"
        case .vaccinated: "syringe.fill"
        }
    }

    var bg: Color {
        switch self {
        case .fed: DoggoColor.logFedBg
        case .medicated: DoggoColor.logMedBg
        case .injuryCheck: DoggoColor.logInjuryBg
        case .vaccinated: DoggoColor.logVaxBg
        }
    }

    var fg: Color {
        switch self {
        case .fed: DoggoColor.logFedFg
        case .medicated: DoggoColor.logMedFg
        case .injuryCheck: DoggoColor.logInjuryFg
        case .vaccinated: DoggoColor.logVaxFg
        }
    }
}
