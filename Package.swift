// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "macchi-trash",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "macchi-trash",
            targets: ["macchi-trash"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "macchi-trash"
        ),
    ]
)
