// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SpideyCursor",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SpideyCursor", targets: ["SpideyCursor"])
    ],
    targets: [
        .executableTarget(name: "SpideyCursor")
    ],
    swiftLanguageModes: [.v5]
)
