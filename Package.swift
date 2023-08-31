// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

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
    .package(url: "https://github.com/gohanlon/swift-macro-testing", branch: "explicit-indentation-width"), // TODO: w/f https://github.com/pointfreeco/swift-macro-testing/pull/8
//    .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.2.1"),
    .package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"),
//    .package(url: "https://github.com/apple/swift-syntax", from: "509.0.0-swift-DEVELOPMENT-SNAPSHOT-2023-08-28-a"),
//    .package(url: "https://github.com/apple/swift-syntax", branch: "main"),
//    .package(url: "https://github.com/apple/swift-syntax", branch: "package-release/509"),
  ],
  targets: [
    .macro(
      name: "MemberwiseInitMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .target(name: "MemberwiseInit", dependencies: ["MemberwiseInitMacros"]),
    .executableTarget(name: "MemberwiseInitClient", dependencies: ["MemberwiseInit"]),
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
