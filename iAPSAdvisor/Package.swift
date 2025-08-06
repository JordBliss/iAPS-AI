// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iAPSAdvisor",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(name: "iAPSAdvisor", targets: ["iAPSAdvisor"])
    ],
    targets: [
        .executableTarget(
            name: "iAPSAdvisor",
            path: ".",
            sources: ["App", "Views"]
        )
    ]
)
