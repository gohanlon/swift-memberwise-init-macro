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
    //    .package(
    //      url: "https://github.com/gohanlon/swift-macro-testing",
    //      branch: "explicit-indentation-width"
    //    ),
    // TODO: w/f https://github.com/pointfreeco/swift-macro-testing/pull/8
    .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.2.1"),
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
        .product(name: "MacroTesting", package: "swift-macro-testing"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ]
)
