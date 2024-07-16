// swift-tools-version: 5.9

import CompilerPluginSupport
import Foundation
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
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.1"),
    //.conditionalPackage(url: "https://github.com/swiftlang/swift-syntax", envVar: "SWIFT_SYNTAX_VERSION", default: "509.0.0..<510.0.0")
    //.conditionalPackage(url: "https://github.com/swiftlang/swift-syntax", envVar: "SWIFT_SYNTAX_VERSION", default: "510.0.0..<511.0.0")
    //.conditionalPackage(url: "https://github.com/swiftlang/swift-syntax", envVar: "SWIFT_SYNTAX_VERSION", default: "511.0.0..<601.0.0-prerelease")
    .conditionalPackage(
      url: "https://github.com/swiftlang/swift-syntax",
      envVar: "SWIFT_SYNTAX_VERSION",
      default: "509.0.0..<601.0.0-prerelease"
    ),
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

extension Package.Dependency {
  /// Creates a dependency based on an environment variable or a default version range.
  ///
  /// This function allows dynamically setting the version range of a package dependency via an environment variable.
  /// If the environment variable is not set, it falls back to a specified default version range.
  ///
  /// - Parameters:
  ///   - url: The URL of the package repository.
  ///   - envVar: The name of the environment variable that contains the version range.
  ///   - versionExpression: The default version range in case the environment variable is not set.
  ///     Example format: `"509.0.0..<511.0.0"` or `"509.0.0...510.0.0"`.
  /// - Returns: A `Package.Dependency` configured with the specified or default version range.
  /// - Throws: A fatal error if the version expression format is invalid or the range operator is unsupported.
  ///
  static func conditionalPackage(
    url: String,
    envVar: String,
    default versionExpression: String
  ) -> Package.Dependency {
    let versionRangeString = ProcessInfo.processInfo.environment[envVar] ?? versionExpression
    let (lower, op, upper) = parseVersionExpression(from: versionRangeString)
    if op == "..<" {
      return .package(url: url, lower..<upper)
    } else if op == "..." {
      return .package(url: url, lower...upper)
    } else {
      fatalError("Unsupported version range operator: \(op)")
    }
  }

  private static func parseVersionExpression(
    from expression: String
  ) -> (Version, String, Version) {
    let rangeOperators = ["..<", "..."]
    for op in rangeOperators {
      if expression.contains(op) {
        let parts = expression.split(separator: op, maxSplits: 1, omittingEmptySubsequences: true)
          .map(String.init)
        guard
          parts.count == 2,
          let lower = Version(parts[0]),
          let upper = Version(parts[1])
        else {
          fatalError("Invalid version expression format: \(expression)")
        }
        return (lower, op, upper)
      }
    }
    fatalError("No valid range operator found in expression: \(expression)")
  }
}
