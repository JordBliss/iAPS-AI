// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [
    .library(name: "NightscoutService", targets: ["NightscoutService"])
]

var targets: [Target] = [
    .target(
        name: "NightscoutService",
        path: "App",
        exclude: ["iAPSAdvisorApp.swift", "LoopSettingsProvider.swift"],
        sources: ["NightscoutService.swift"]
    ),
    .testTarget(
        name: "iAPSAdvisorTests",
        dependencies: ["NightscoutService"],
        path: "Tests/iAPSAdvisorTests"
    )
]

#if canImport(SwiftUI)
products.append(
    .executable(name: "iAPSAdvisor", targets: ["iAPSAdvisor"])
)

targets.append(
    .executableTarget(
        name: "iAPSAdvisor",
        path: ".",
        sources: ["App", "Views"]
    )
)
#endif

let package = Package(
    name: "iAPSAdvisor",
    platforms: [
        .iOS(.v15)
    ],
    products: products,
    targets: targets
)
