import SwiftSyntax

extension AttributeSyntax {
  
  func firstUnlabeledValue<T>(interpretableAs type: T.Type) -> T? where T: RawRepresentable<String> {
    guard let arguments = arguments?.as(LabeledExprListSyntax.self)
    else { return nil }
    
    // NB: Search for the first argument whose name matches an access level name
    for labeledExprSyntax in arguments {
      if let identifier = labeledExprSyntax.expression.as(MemberAccessExprSyntax.self)?.declName,
         let accessLevel = T(rawValue: identifier.baseName.trimmedDescription)
      {
        return accessLevel
      }
    }
    
    return nil
  }
}

extension VariableDeclSyntax {
  func modifiersExclude(_ keywords: [Keyword]) -> Bool {
    return !self.modifiers.containsAny(of: keywords.map { TokenSyntax.keyword($0) })
  }

  func firstModifierWhere(keyword: Keyword) -> DeclModifierSyntax? {
    let keywordText = TokenSyntax.keyword(keyword).text
    return self.modifiers.first { modifier in
      modifier.name.text == keywordText
    }
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
      let binding = self.bindings.first
    else { return false }

    return self.bindingSpecifier.tokenKind == .keyword(.var) && binding.isComputedProperty
  }

  var isFullyInitialized: Bool {
    self.bindings.allSatisfy { $0.initializer != nil }
  }

  var isFullyInitializedLet: Bool {
    self.isLet && self.isFullyInitialized
  }

  var isLet: Bool {
    self.bindingSpecifier.tokenKind == .keyword(.let)
  }

  var isVar: Bool {
    self.bindingSpecifier.tokenKind == .keyword(.var)
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

extension DeclGroupSyntax {
  func descriptiveDeclKind(withArticle article: Bool = false) -> String {
    switch self {
    case is ActorDeclSyntax:
      return article ? "an actor" : "actor"
    case is ClassDeclSyntax:
      return article ? "a class" : "class"
    case is ExtensionDeclSyntax:
      return article ? "an extension" : "extension"
    case is ProtocolDeclSyntax:
      return article ? "a protocol" : "protocol"
    case is StructDeclSyntax:
      return article ? "a struct" : "struct"
    case is EnumDeclSyntax:
      return article ? "an enum" : "enum"
    default:
      return "`\(self.kind)`"
    }
  }
}
