// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EnvironmentSwitchingKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "EnvironmentSwitchingKit",
            targets: ["EnvironmentSwitchingKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stoqn4opm/PresentationKit", from: "2.0.1")
    ],
    targets: [
        .target(
            name: "EnvironmentSwitchingKit",
            dependencies: [
                .product(name: "PresentationKit", package: "PresentationKit"),
            ]
        ),
        .testTarget(
            name: "EnvironmentSwitchingKitTests",
            dependencies: ["EnvironmentSwitchingKit"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
