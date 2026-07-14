//
//  CloudKitShareCoordinator.swift
//  DoggoCollector
//
//  The bridge between UIKit's scene-delegate-only CKShare-accept callback
//  (there's no SwiftUI-native hook for this — verified against the
//  installed SDK before building this, decision #18) and the rest of the
//  app. SceneDelegate writes into this singleton; DoggoCollectorApp
//  observes it to present the accept-confirmation sheet.
//

import Foundation
import CloudKit

@Observable
final class CloudKitShareCoordinator {
    static let shared = CloudKitShareCoordinator()

    var pendingMetadata: CKShare.Metadata?

    private init() {}
}
