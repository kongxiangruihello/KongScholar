// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "KongScholar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "KongScholar", targets: ["KongScholar"])],
    targets: [
        .target(name: "KongScholarCore"),
        .executableTarget(name: "KongScholar", dependencies: ["KongScholarCore"]),
        .testTarget(name: "KongScholarCoreTests", dependencies: ["KongScholarCore"])
    ]
)
