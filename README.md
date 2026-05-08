# EnvironmentSwitchingKit

A drop-in network-environment switcher for iOS apps. ![iOS](https://img.shields.io/badge/iOS-15%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## What it does

Lets QA, devs, and beta testers swap the live network environment of an app at runtime by AirDropping a small JSON config file (or any custom file extension you pick). The selected environment is persisted across launches and applied with a clean app-restart so every cached service starts fresh against the new URLs.

The package is brand-agnostic: it doesn't know what an "environment" means in your app. You define a `LoadedEnvironment` shape — a list of `{key, value}` field pairs — and supply a closure that says "given one of these, swap my live state and restart the app." The package owns the storage, the file parser, the picker UI, and the shake-to-reopen affordance; you own how those values plug into your networking stack.

Once the user has imported a file, the picker is also available via a shake gesture from anywhere in the app.

## Features

- File-import path (`.yourbrand` UTI registered in your `Info.plist`).
- Shake-gesture re-entry after the first import.
- Closure-based dependency injection — the package never sees your `Environment` type.
- Persistent selection across launches (versioned UserDefaults envelope; future-proof migrations).
- Six-color `EnvironmentSwitcherTheme` protocol with a system-color default; bring your own brand.
- Built-in production seed always pinned at the top of the picker, never user-deletable.
- Native `UITableView` (insetGrouped) UI with diff-based animations and keyboard avoidance.
- Presented on its own `UIWindow` via [PresentationKit](https://github.com/stoqn4opm/PresentationKit) so it overlays whatever your app is doing.

## Quick start

```swift
import EnvironmentSwitchingKit

// 1. Define your built-in production environment.
let production = LoadedEnvironment(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    name: "Production",
    fields: [
        .init(key: "baseURL", value: "https://api.example.com"),
        .init(key: "version", value: "v1")
    ],
    isBuiltIn: true)

// 2. Build the persistence + parser + applier.
let store = UserDefaultsEnvironmentStore(
    keyPrefix: "myapp.environments",
    builtIn: production)

let parser = JSONEnvironmentFileParser()

let applier = DefaultEnvironmentApplier(store: store) { @MainActor environment in
    // Whatever it takes to point your app at the new env.
    // Typically: swap a mutable Environment wrapper your services hold,
    // tear down the websocket, clear local user state, replace the window's
    // rootViewController with a fresh splash.
    MyApp.swap(to: environment)
    MyApp.restart()
}

// 3. Build the composition root.
let switcher = EnvironmentSwitcherCompositionRoot(
    store: store,
    parser: parser,
    applier: applier,
    theme: DefaultEnvironmentSwitcherTheme(),
    fileExtension: "myapp")  // .myapp files will trigger the picker
```

```swift
// 4. From your scene delegate's openURLContexts handler:
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    switcher.handle(urlContexts: URLContexts)
}

// 5. From a shake-detection mechanism — e.g. a UIApplication subclass:
final class ShakeDetectingApplication: UIApplication {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake, store.hasBeenSeen {
            Task { @MainActor in switcher.handleShake() }
        }
    }
}
```

A complete runnable demo lives in [`Examples/EnvironmentSwitchingKitExample`](Examples/EnvironmentSwitchingKitExample) — open `EnvironmentSwitchingKit.xcworkspace` and run the `EnvironmentSwitchingKitExample` scheme.

## Installation

### Xcode → Add Package Dependencies

1. **File → Add Package Dependencies…**
2. Paste `https://github.com/stoqn4opm/EnvironmentSwitchingKit.git`
3. Pick **Up to Next Major Version** from `1.0.0`.
4. Add the `EnvironmentSwitchingKit` library product to your app target.

### `Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/stoqn4opm/EnvironmentSwitchingKit.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "EnvironmentSwitchingKit", package: "EnvironmentSwitchingKit"),
        ]
    ),
]
```

## File format

The picker reads files of the extension you configure (e.g. `.myapp`, `.staging`, `.example`). The format is a flat JSON object — `name` plus a `fields` array:

```json
{
  "name": "Staging",
  "fields": [
    { "key": "baseURL", "value": "https://staging.example.com" },
    { "key": "version", "value": "v1" }
  ]
}
```

Field keys are entirely up to your brand — the package round-trips them as opaque strings. Your apply closure decides which keys to honour.

To register the extension as an app document type, add to your `Info.plist`:

```xml
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>
    <string>MyApp Environment</string>
    <key>CFBundleTypeRole</key>
    <string>Viewer</string>
    <key>LSHandlerRank</key>
    <string>Owner</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>com.myapp.environment</string>
    </array>
  </dict>
</array>
<key>UTExportedTypeDeclarations</key>
<array>
  <dict>
    <key>UTTypeIdentifier</key>
    <string>com.myapp.environment</string>
    <key>UTTypeConformsTo</key>
    <array><string>public.data</string></array>
    <key>UTTypeTagSpecification</key>
    <dict>
      <key>public.filename-extension</key>
      <array><string>myapp</string></array>
    </dict>
  </dict>
</array>
<key>LSSupportsOpeningDocumentsInPlace</key>
<false/>
```

## Customising the theme

Conform a struct to `EnvironmentSwitcherTheme` to plug in your brand's colours:

```swift
struct MyAppTheme: EnvironmentSwitcherTheme {
    var background: UIColor { .myAppBackground }
    var cellBackground: UIColor { .myAppCellBackground }
    var foreground: UIColor { .myAppForeground }
    var foregroundSecondary: UIColor { .myAppForeground.withAlphaComponent(0.6) }
    var tint: UIColor { .myAppTint }
    var actionButtonBackground: UIColor { .myAppTint }
    var actionButtonForeground: UIColor { .white }
}
```

Pass an instance to `EnvironmentSwitcherCompositionRoot.init(theme:)`. The package ships a `DefaultEnvironmentSwitcherTheme` that uses iOS system colours so you can wire it up without touching colours at first.

## Architecture notes

The package never sees your `Environment` type. The boundary is a single closure on `DefaultEnvironmentApplier`:

```swift
public init(
    store: EnvironmentStore,
    applyAction: @escaping @MainActor (LoadedEnvironment) async -> Void)
```

Inside that closure your brand does whatever it needs — swap a `MutableEnvironment` forwarder, disconnect a websocket, clear cached user data, recompose the window's root view controller. The package's job ends at "user picked this `LoadedEnvironment`; persist it and call your closure."

This deliberate inversion is what lets a single package serve multiple brands with totally different `Environment` shapes (90 URL properties for one brand, 12 for another, none yet for a third). The brand-specific glue stays in your app target.

## Tests

Run the test suite with either `swift test` or via Xcode against an iOS simulator:

```sh
xcodebuild -scheme EnvironmentSwitchingKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

33 XCTest cases cover the model, store (including the versioned-storage envelope's legacy fallback), parser, applier ordering, and the view-model state machine.

## Licence

[MIT](LICENCE) — © 2026 Stoyan Stoyanov.
