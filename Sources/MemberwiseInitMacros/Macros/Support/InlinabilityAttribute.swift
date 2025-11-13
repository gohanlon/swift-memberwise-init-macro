import SwiftSyntax

enum InlinabilityAttribute: String, Hashable, CaseIterable, Sendable {
  case usableFromInline
  case inlinable
  
}
