// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Porch",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "Porch",
            path: "PorchApp",
            exclude: ["Info.plist"],
            // Embed Info.plist in binary so settings work even without an app bundle (swift run)
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "PorchApp/Info.plist",
                ]),
            ]
        ),
    ]
)
