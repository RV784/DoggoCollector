//
//  SceneDelegate.swift
//  DoggoCollector
//
//  Named by AppDelegate's UISceneConfiguration. Its only job is catching
//  the CKShare-accept callback and handing the metadata to
//  CloudKitShareCoordinator — everything else about window/scene setup is
//  left to SwiftUI's own WindowGroup, which still works normally alongside
//  a named scene delegate class as long as this class doesn't try to own
//  window creation itself.
//

import UIKit
import CloudKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        CloudKitShareCoordinator.shared.pendingMetadata = cloudKitShareMetadata
    }
}
