//
//  DemoSceneDelegate.swift
//  EnvironmentSwitchingKitExample
//

import EnvironmentSwitchingKit
import UIKit

final class DemoSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        DemoComposition.seedDemoEnvironmentsIfNeeded()

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = DemoViewController()
        window.makeKeyAndVisible()
        self.window = window

        // If we were cold-launched by a `.example` file, the URL arrives
        // here in connectionOptions — defer one runloop tick so the window
        // finishes mounting before PresentationKit stacks its own on top.
        if !connectionOptions.urlContexts.isEmpty {
            let contexts = connectionOptions.urlContexts
            DispatchQueue.main.async {
                DemoComposition.switcher.handle(urlContexts: contexts)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        DemoComposition.switcher.handle(urlContexts: URLContexts)
    }
}
