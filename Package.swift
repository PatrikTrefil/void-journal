// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VoidJournal",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "VoidJournal", path: "Sources/VoidJournal")
    ]
)
