// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PrivilegedHelperKit",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PrivilegedHelperKit",
            targets: ["PrivilegedHelperKit"]
        ),
        .library(
            name: "PrivilegedHelperManager",
            targets: ["PrivilegedHelperManager"]
        ),
        .library(
            name: "PrivilegedHelperRunner",
            targets: ["PrivilegedHelperRunner"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/codingiran/AppleExtension.git", .upToNextMajor(from: "3.0.1")),
        .package(url: "https://github.com/codingiran/ScriptRunner.git", .upToNextMajor(from: "0.0.2")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PrivilegedHelperKit",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PrivilegedHelperManager",
            dependencies: [
                "PrivilegedHelperKit",
                "AppleExtension",
                "ScriptRunner",
            ],
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PrivilegedHelperRunner",
            dependencies: [
                "PrivilegedHelperKit",
            ],
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "PrivilegedHelperKitTests",
            dependencies: ["PrivilegedHelperKit"]
        ),
    ]
)
