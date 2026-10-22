// swift-tools-version:5.10
// The line above tells Swift Package Manager which version of the package
// format this file uses. It must stay the very first line.

import PackageDescription

// Reckon is built as a Swift Package rather than an Xcode project, so it can be
// compiled from the command line with `swift build`. The script in
// `scripts/build-app.sh` then wraps the compiled program into a real
// `Reckon.app` bundle (with Info.plist, entitlements and a code signature).
let package = Package(
    name: "Reckon",
    platforms: [
        .macOS(.v14)   // We use macOS 14 APIs (EventKit full access, @Observable).
    ],
    targets: [
        .executableTarget(
            name: "Reckon",
            path: "Sources/Reckon"
        )
    ]
)
