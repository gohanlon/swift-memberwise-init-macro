import SwiftSyntax

extension AttributeListSyntax {
  func contains(attributeNamed name: String) -> Bool {
    return self.contains {
      $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == name
    }
  }
}

extension VariableDeclSyntax {
  func modifiersExclude(_ keywords: [Keyword]) -> Bool {
    return !self.modifiers.containsAny(of: keywords.map { TokenSyntax.keyword($0) })
  }
}

extension DeclModifierListSyntax {
  fileprivate func containsAny(of tokens: [TokenSyntax]) -> Bool {
    return self.contains { modifier in
      tokens.contains { $0.text == modifier.name.text }
    }
  }
}

extension PatternBindingSyntax {
  var isComputedProperty: Bool {
    guard let accessors = self.accessorBlock?.accessors else { return false }

    switch accessors {
    case .accessors(let accessors):
      let tokenKinds = accessors.compactMap { $0.accessorSpecifier.tokenKind }
      let propertyObservers: [TokenKind] = [.keyword(.didSet), .keyword(.willSet)]

      return !tokenKinds.allSatisfy(propertyObservers.contains)

    case .getter(_):
      return true
    }
  }
}

extension TypeSyntax {
  var isFunctionType: Bool {
    // NB: Check for `FunctionTypeSyntax` directly or when wrapped within `AttributedTypeSyntax`,
    // e.g., `@Sendable () -> Void`.
    return self.is(FunctionTypeSyntax.self)
      || (self.as(AttributedTypeSyntax.self)?.baseType.is(FunctionTypeSyntax.self) ?? false)
  }
}

extension TypeSyntax {
  var isOptionalType: Bool {
    self.as(OptionalTypeSyntax.self) != nil
  }
}

extension PatternSyntax {
  var isTuplePattern: Bool {
    self.as(TuplePatternSyntax.self) != nil
  }
}

extension VariableDeclSyntax {
  var isComputedProperty: Bool {
    guard
      self.bindings.count == 1,
      let binding = self.bindings.first?.as(PatternBindingSyntax.self)
    else { return false }

    return self.bindingSpecifier.tokenKind == .keyword(.var) && binding.isComputedProperty
  }

  var isFullyInitializedLet: Bool {
    self.bindingSpecifier.tokenKind == .keyword(.let)
      && self.bindings.allSatisfy { $0.initializer != nil }
  }
}

extension ExprSyntax {
  var trimmedStringLiteral: String? {
    self.as(StringLiteralExprSyntax.self)?
      .segments
      .trimmedDescription
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
