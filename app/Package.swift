// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clima",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Clima", targets: ["Clima"]),
    ],
    targets: [
        // Models, communication with the Python bridge, state and views
        .target(name: "ClimaKit"),
        // The menu bar app
        .executableTarget(name: "Clima", dependencies: ["ClimaKit"]),
    ]
)
