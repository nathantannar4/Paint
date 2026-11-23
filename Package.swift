// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Paint",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .macCatalyst(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Paint",
            targets: [
                "Paint"
            ]
        ),
        .library(
            name: "PaintUI",
            targets: [
                "PaintUI"
            ]
        ),
    ],
    targets: [
        .target(
            name: "Paint",
            swiftSettings: {
                var settings = [SwiftSetting]()
                #if compiler(>=6.2)
                settings.append(.define("XCODE_26"))
                #endif
                #if compiler(>=6.4)
                settings.append(.define("XCODE_27"))
                #endif
                return settings
            }()
        ),
        .target(
            name: "PaintUI",
            dependencies: [
                "Paint"
            ],
            swiftSettings: {
                var settings = [SwiftSetting]()
                #if compiler(>=6.2)
                settings.append(.define("XCODE_26"))
                #endif
                #if compiler(>=6.4)
                settings.append(.define("XCODE_27"))
                #endif
                return settings
            }()
        ),
        .testTarget(
            name: "PaintTests",
            dependencies: [
                "Paint",
                "PaintUI",
            ],
            resources: [
                .copy("Resources/Images"),
            ],
            swiftSettings: {
                var settings = [SwiftSetting]()
                #if compiler(>=6.2)
                settings.append(.define("XCODE_26"))
                #endif
                #if compiler(>=6.4)
                settings.append(.define("XCODE_27"))
                #endif
                return settings
            }()
        ),
    ]
)
