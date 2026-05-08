//
//  AppDelegate.swift
//  EnvironmentSwitchingKitExample
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Suppress the system shake-to-undo prompt; we use shake for our own
        // env-switcher reopen.
        application.applicationSupportsShakeToEdit = false
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = DemoSceneDelegate.self
        return config
    }
}
