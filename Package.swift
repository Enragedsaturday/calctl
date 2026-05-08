// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "calctl",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "calctl", targets: ["calctl"]),
        .library(name: "CalCtlCore", targets: ["CalCtlCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(name: "CalCtlCore", dependencies: []),
        .executableTarget(
            name: "calctl",
            dependencies: [
                "CalCtlCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"])
            ]
        ),
        .executableTarget(name: "calctl-tests", dependencies: ["CalCtlCore"], path: "Tests/CalCtlCoreTests"),
    ]
)
