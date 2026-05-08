//
//  DemoComposition.swift
//  EnvironmentSwitchingKitExample
//
//  Single-file composition root for the demo. Holds the long-lived
//  EnvironmentSwitcher pieces and a simple `LoadedEnvironment` ref the
//  view controller renders. The "apply action" in this demo doesn't
//  actually swap a real network stack — it just stores the new selection
//  and replaces the window's rootViewController, mimicking what a brand
//  with an actual networking layer would do.
//

import EnvironmentSwitchingKit
import UIKit

@MainActor
enum DemoComposition {

    // MARK: - Built-In Production

    static let production = LoadedEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Production",
        fields: [
            .init(key: "baseURL", value: "https://api.example.com"),
            .init(key: "version", value: "v1")
        ],
        isBuiltIn: true)

    // MARK: - Long-Lived Pieces

    static let store: EnvironmentStore = UserDefaultsEnvironmentStore(
        keyPrefix: "EnvironmentSwitchingKitExample.environments",
        builtIn: production)

    static let parser = JSONEnvironmentFileParser()

    static let applier: EnvironmentApplier = DefaultEnvironmentApplier(
        store: store,
        applyAction: { @MainActor environment in
            print("[Demo] applying \(environment.name): \(environment.fields)")
            // Replace the window's rootVC with a fresh DemoViewController so
            // the screen re-reads the freshly-applied env from the store.
            guard
                let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let window = scene.windows.first
            else { return }
            UIView.transition(
                with: window, duration: 0.3,
                options: .transitionCrossDissolve,
                animations: { window.rootViewController = DemoViewController() },
                completion: nil)
        })

    static let switcher = EnvironmentSwitcherCompositionRoot(
        store: store,
        parser: parser,
        applier: applier,
        theme: DefaultEnvironmentSwitcherTheme(),
        fileExtension: "example")

    // MARK: - First-Run Seed

    /// Pre-seeds the store with a "Staging" demo env on first launch, so
    /// the picker has at least two rows to pick between without making the
    /// user import a real file. Idempotent.
    static func seedDemoEnvironmentsIfNeeded() {
        guard store.loaded.contains(where: { !$0.isBuiltIn }) == false else { return }
        store.add(LoadedEnvironment(
            id: UUID(),
            name: "Staging",
            fields: [
                .init(key: "baseURL", value: "https://staging.example.com"),
                .init(key: "version", value: "v1")
            ],
            isBuiltIn: false))
    }
}
