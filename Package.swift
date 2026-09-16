// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SquooshPro",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SquooshCore", targets: ["SquooshCore"]),
        .library(name: "SquooshCodecHost", targets: ["SquooshCodecHost"]),
        .library(name: "SquooshNativeCodecHost", targets: ["SquooshNativeCodecHost"]),
        .executable(name: "SquooshPro", targets: ["SquooshPro"]),
        .executable(name: "SquooshCoreCheck", targets: ["SquooshCoreCheck"]),
        .executable(name: "SquooshWebKitCheck", targets: ["SquooshWebKitCheck"]),
        .executable(name: "SquooshNativeCodecWorker", targets: ["SquooshNativeCodecWorker"]),
        .executable(name: "SquooshNativeCodecCheck", targets: ["SquooshNativeCodecCheck"]),
    ],
    targets: [
        .target(name: "SquooshCore"),
        .target(
            name: "SquooshCodecHost",
            dependencies: ["SquooshCore"],
            resources: [.copy("Resources/CodecWorker")]
        ),
        .target(name: "SquooshNativeCodecHost", dependencies: ["SquooshCore"]),
        .executableTarget(
            name: "SquooshPro",
            dependencies: ["SquooshCore", "SquooshCodecHost", "SquooshNativeCodecHost"],
            resources: [.copy("Resources/SystemPresets.json"), .copy("Resources/ThirdPartyLicenses")]
        ),
        .executableTarget(name: "SquooshCoreCheck", dependencies: ["SquooshCore"]),
        .executableTarget(name: "SquooshWebKitCheck", dependencies: ["SquooshCore", "SquooshCodecHost"]),
        .executableTarget(name: "SquooshNativeCodecWorker", dependencies: ["SquooshCore"]),
        .executableTarget(name: "SquooshNativeCodecCheck", dependencies: ["SquooshCore", "SquooshNativeCodecHost"]),
        .testTarget(name: "SquooshCoreTests", dependencies: ["SquooshCore"]),
    ],
    swiftLanguageModes: [.v5]
)
