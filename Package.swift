// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "apple_reminder_cli",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "RemindCore", targets: ["RemindCore"]),
    .executable(name: "apple_reminder_cli", targets: ["apple_reminder_cli"]),
  ],
  dependencies: [
    .package(url: "https://github.com/steipete/Commander.git", from: "0.2.0"),
  ],
  targets: [
    .target(
      name: "RemindCore",
      dependencies: [],
      linkerSettings: [
        .linkedFramework("EventKit"),
      ]
    ),
    .executableTarget(
      name: "apple_reminder_cli",
      dependencies: [
        "RemindCore",
        .product(name: "Commander", package: "Commander"),
      ],
      exclude: [
        "Resources/Info.plist",
      ],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-sectcreate",
          "-Xlinker", "__TEXT",
          "-Xlinker", "__info_plist",
          "-Xlinker", "Sources/apple_reminder_cli/Resources/Info.plist",
        ]),
      ]
    ),
    .testTarget(
      name: "RemindCoreTests",
      dependencies: [
        "RemindCore",
      ]
    ),
    .testTarget(
      name: "apple_reminder_cliTests",
      dependencies: [
        "apple_reminder_cli",
        "RemindCore",
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
