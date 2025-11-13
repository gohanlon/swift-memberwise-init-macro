import SwiftSyntax

extension AttributeSyntax {
  
  func firstArgumentValue<T>(interpretableAs type: T.Type) -> T? where T: RawRepresentable<String> {
    guard case .argumentList(let arguments) = arguments else { return nil }
    
    // NB: Search for the first argument whose name matches an access level name
    for labeledExprSyntax in arguments {
      if let interpretedValue = labeledExprSyntax.value(interpretedAs: type) {
        return interpretedValue
      }
    }
    
    return nil
  }
}

extension LabeledExprSyntax {
  
  func value<T>(interpretedAs type: T.Type) -> T? where T: RawRepresentable<String> {
    guard let identifier = expression.as(MemberAccessExprSyntax.self)?.declName else {
      return nil
    }
    
    return T(rawValue: identifier.baseName.trimmedDescription)
  }
}

extension LabeledExprListSyntax {

  func removingFirstArgumentValue<T>(interpretableAs type: T.Type) -> Self where T: RawRepresentable<String> {
    removingFirstItem { labeledExprSyntax in
      labeledExprSyntax.value(interpretedAs: type) != nil
    }
  }

  func replacingFirstArgument<T>(
    interpretableAs type: T.Type,
    with value: LabeledExprSyntax
  ) -> Self where T: RawRepresentable<String> {
    var result = Self()
    var hasFoundItemToReplace = false
    for node in self {
      if !hasFoundItemToReplace, let _ = node.value(interpretedAs: type) {
        hasFoundItemToReplace = true
        result.append(value)
      } else {
        result.append(node)
      }
    }
    
    return result.withFixedInterItemCommas()
  }

  func removingFirstItem(where predicate: (Element) throws -> Bool) rethrows -> Self {
    var result = Self()
    var hasFoundItemToRemove = false
    for node in self {
      if !hasFoundItemToRemove, try predicate(node) {
        hasFoundItemToRemove = true
        continue
      }
      result.append(node)
    }
    
    return result.withFixedInterItemCommas()
  }
  
  func withFixedInterItemCommas() -> LabeledExprListSyntax {
    guard !isEmpty else {
      return self
    }
    
    let finalIndex = count - 1
    var result = Self()
    for (index, node) in enumerated() {
      if index == finalIndex {
        result.append(node.with(\.trailingComma, nil))
      } else {
        result.append(node.with(\.trailingComma, .commaToken(trailingTrivia: Trivia.spaces(1))))
      }
    }
    
    return result    
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
