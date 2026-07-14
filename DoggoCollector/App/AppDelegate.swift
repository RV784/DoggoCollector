//
//  AppDelegate.swift
//  DoggoCollector
//
//  The one piece of UIKit lifecycle this otherwise-pure-SwiftUI-lifecycle
//  app needs (decision #18): incoming CKShare acceptance only arrives via
//  UIWindowSceneDelegate.windowScene(_:userDidAcceptCloudKitShareWith:) —
//  there is no SwiftUI Scene modifier for it on this SDK (verified before
//  building this, not assumed). This class exists solely to hand Xcode a
//  UISceneConfiguration naming SceneDelegate as the delegate class.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
