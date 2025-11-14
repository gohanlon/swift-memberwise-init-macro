// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "swift-memberwise-init-macro",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "MemberwiseInit",
      targets: ["MemberwiseInit"]
    ),
    .executable(
      name: "MemberwiseInitClient",
      targets: ["MemberwiseInitClient"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"603.0.0"),
  ],
  targets: [
    .macro(
      name: "MemberwiseInitMacros",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      ]
    ),
    .target(
      name: "MemberwiseInit",
      dependencies: ["MemberwiseInitMacros"]
    ),
    .executableTarget(
      name: "MemberwiseInitClient",
      dependencies: ["MemberwiseInit"]
    ),
    .testTarget(
      name: "MemberwiseInitTests",
      dependencies: [
        "MemberwiseInitMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
  ]
)
