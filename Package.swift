// swift-tools-version: 5.9

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "MemberwiseInit",
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
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0"),
    .package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"),
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
        "MacroTesting",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
    .target(
      name: "MacroTesting",
      dependencies: [
        .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftOperators", package: "swift-syntax"),
        .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "MacroTestingTests",
      dependencies: [
        "MacroTesting"
      ]
    ),
  ]
)
