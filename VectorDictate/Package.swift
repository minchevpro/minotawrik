// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VectorDictate",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "VectorDictate",
            path: "Sources/VectorDictate"
        )
    ]
)
