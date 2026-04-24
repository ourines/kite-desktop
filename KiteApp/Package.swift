// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KiteApp",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
    ],
    products: [
        .executable(name: "KiteApp", targets: ["KiteApp"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "KiteApp",
            path: "Sources/KiteApp",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "KiteAppTests",
            dependencies: ["KiteApp"],
            path: "Tests/KiteAppTests"
        ),
    ]
)
