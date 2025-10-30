import SwiftSyntax

extension GenericArgumentSyntax {
  var argumentCompat600: TypeSyntax? {
    #if canImport(SwiftSyntax601)
      argument.as(TypeSyntax.self)
    #else
      argument
    #endif
  }
}
