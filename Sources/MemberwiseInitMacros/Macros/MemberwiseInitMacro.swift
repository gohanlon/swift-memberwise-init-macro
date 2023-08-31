import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct InitMacro: PeerMacro {
  public static func expansion(
    of node: SwiftSyntax.AttributeSyntax,
    providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
    in context: some SwiftSyntaxMacros.MacroExpansionContext
  ) throws -> [SwiftSyntax.DeclSyntax] {
    return []
  }
}

public struct MemberwiseInitMacro: MemberMacro {
  struct PropertyBinding {
    let accessLevel: AccessLevelModifier
    let configuredAccessLevel: AccessLevelModifier?
    let configuredForceEscaping: Bool
    let effectiveTypeAnnotation: TypeAnnotationSyntax?
    let initializer: ExprSyntax?
    let isComputedProperty: Bool
    let isTuplePattern: Bool
    let keywordToken: TokenKind
    let name: String?
    private let _syntaxNode: Syntax

    init(
      accessLevel: AccessLevelModifier,
      adoptedType: TypeAnnotationSyntax?,
      binding: PatternBindingSyntax,
      configuredAccessLevel: AccessLevelModifier?,
      configuredForceEscaping: Bool,
      keywordToken: TokenKind
    ) {
      self.accessLevel = accessLevel
      self.configuredAccessLevel = configuredAccessLevel
      self.effectiveTypeAnnotation = binding.typeAnnotation ?? adoptedType
      self.configuredForceEscaping = configuredForceEscaping
      self.initializer = binding.initializer?.trimmed.value
      self.isComputedProperty = binding.isComputedProperty
      self.isTuplePattern = binding.pattern.isTuplePattern
      self.keywordToken = keywordToken
      self.name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
      self._syntaxNode = binding._syntaxNode
    }

    var isPreinitializedVarWithoutType: Bool {
      self.initializer != nil
      && self.effectiveTypeAnnotation == nil
      && self.keywordToken == .keyword(.var)
    }

    var isPreinitializedLet: Bool {
      self.initializer != nil && self.keywordToken == .keyword(.let)
    }

    func diagnostic(message: MemberwiseInitMacroDiagnostic) -> Diagnostic {
      Diagnostic(node: self._syntaxNode, message: message)
    }
  }

  struct MemberProperty {
    let accessLevel: AccessLevelModifier
    let configuredAccessLevel: AccessLevelModifier?
    let configuredForceEscaping: Bool
    let initializer: ExprSyntax?
    let keywordToken: TokenKind
    let name: String
    let type: TypeSyntax

    init(
      accessLevel: AccessLevelModifier,
      configuredAccessLevel: AccessLevelModifier?,
      configuredForceEscaping: Bool,
      initializer: ExprSyntax?,
      keywordToken: TokenKind,
      name: String,
      type: TypeSyntax
    ) {
      self.accessLevel = accessLevel
      self.configuredAccessLevel = configuredAccessLevel
      self.configuredForceEscaping = configuredForceEscaping
      self.initializer = initializer
      self.keywordToken = keywordToken
      self.name = name
      self.type = type
    }

    var externalName: String {
      self.name.hasPrefix("_") ? String(self.name.dropFirst()) : self.name
    }
  }

  public static func expansion<D, C>(
    of node: AttributeSyntax,
    providingMembersOf decl: D,
    in context: C
  ) throws -> [SwiftSyntax.DeclSyntax]
  where D: DeclGroupSyntax, C: MacroExpansionContext {
    guard [SwiftSyntax.SyntaxKind.classDecl, .structDecl, .actorDecl].contains(decl.kind) else {
      throw MemberwiseInitMacroDiagnostic.invalidDeclarationKind(decl)
    }
    let configuredAccessLevel: AccessLevelModifier? = extractConfiguredAccessLevel(from: node)
    let optionalsDefaultNil: Bool = extractOptionalsDefaultNil(from: node) ?? false

    let (properties, diagnostics) = try collectMemberProperties(from: decl.memberBlock.members)
    diagnostics.forEach { context.diagnose($0) }

    let accessLevel = NonEmptyArray(
      head: configuredAccessLevel ?? .internal,
      tail: properties.compactMap { $0.configuredAccessLevel ?? $0.accessLevel }
    ).min()

    func formatParameters(from properties: [MemberProperty]) -> String {
      guard !properties.isEmpty else { return "" }

      return "\n" +
      properties
        .map { property in
          formatParameter(
            from: property,
            optionalsDefaultNil: optionalsDefaultNil
          )
        }
        .joined(separator: ",\n")
      + "\n"
    }

    let formattedInitSignature = "\n\(accessLevel) init(\(formatParameters(from: properties)))"
    return [
      DeclSyntax(
        try InitializerDeclSyntax(SyntaxNodeString(stringLiteral: formattedInitSignature)) {
          CodeBlockItemListSyntax(
            properties
              .map(formatInitializerAssignmentStatement(from:))
              .map(CodeBlockItemSyntax.init(stringLiteral:))
          )
        }
      )
    ]
  }

  private static func extractConfiguredAccessLevel(
    from node: AttributeSyntax
  ) -> AccessLevelModifier? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self)
    else { return nil }

    // NB: Search for the first argument who's name matches an access level name
    return arguments.compactMap { labeledExprSyntax -> AccessLevelModifier? in
      guard
        let identifier = labeledExprSyntax.expression.as(MemberAccessExprSyntax.self)?.declName,
        let accessLevel = AccessLevelModifier(rawValue: identifier.baseName.trimmedDescription)
      else { return nil }

      return accessLevel
    }
    .first
  }

  private static func extractOptionalsDefaultNil(
    from node: AttributeSyntax
  ) -> Bool? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self)
    else { return nil }

    return arguments.contains { tupleExprElement -> Bool in
      guard
        tupleExprElement.label?.text == "optionalsDefaultNil",
        let booleanLiteral = tupleExprElement.expression.as(BooleanLiteralExprSyntax.self)
      else { return false }

      return booleanLiteral.literal.text == "true"
    }
  }

  private static func collectMemberProperties(
    from decl: MemberBlockItemListSyntax
  ) throws -> ([MemberProperty], [Diagnostic]) {
    return decl
      .compactMap { (member: MemberBlockItemSyntax) -> VariableDeclSyntax? in
        guard
          let variable = member.decl.as(VariableDeclSyntax.self),
          variable.attributes.isEmpty ||
            variable.attributes.contains(attributeNamed: "Init"),
          variable.modifiersExclude([.static, .lazy])
        else { return nil }
        return variable
      }
      .flatMap { variable -> [PropertyBinding] in
        variable.bindings
          .reversed()
          .reduce(
            into: (
              bindings: [PropertyBinding](),
              typeFromTrailingBinding: TypeAnnotationSyntax?.none
            )
          ) { acc, binding in
            let (
              configuredIgnore,
              configuredAccessLevel,
              configuredForceEscaping
            ) = extractMemberConfiguration(from: variable)

            guard !configuredIgnore else { return }

            acc.bindings.append(
              PropertyBinding(
                accessLevel: variable.accessLevel,
                adoptedType: binding.typeAnnotation == nil ? acc.typeFromTrailingBinding : nil,
                binding: binding,
                configuredAccessLevel: configuredAccessLevel,
                configuredForceEscaping: configuredForceEscaping,
                keywordToken: variable.bindingSpecifier.tokenKind
              )
            )
            acc.typeFromTrailingBinding = binding.typeAnnotation ?? acc.typeFromTrailingBinding
          }
          .bindings
          .reversed()
      }
      .reduce(
        (
          [MemberProperty](),
          [Diagnostic]()
        )
      ) { acc, property in
        let (properties, diagnostics) = acc
        if property.isComputedProperty || property.isPreinitializedLet {
          return (properties, diagnostics)
        }
        if property.isPreinitializedVarWithoutType {
          return (
            properties,
            diagnostics + [property.diagnostic(message: .missingExplicitTypeForVarProperty)]
          )
        }
        if property.isTuplePattern {
          return (
            properties,
            diagnostics + [property.diagnostic(message: .tupleDestructuringInProperty)]
          )
        }

        guard
          let name = property.name,
          let effectiveTypeAnnotation = property.effectiveTypeAnnotation
        else { return (properties, diagnostics) }

        let newProperty = MemberProperty(
          accessLevel: property.accessLevel,
          configuredAccessLevel: property.configuredAccessLevel,
          configuredForceEscaping: property.configuredForceEscaping,
          initializer: property.initializer,
          keywordToken: property.keywordToken,
          name: name,
          type: effectiveTypeAnnotation.type.trimmed
        )
        return (properties + [newProperty], diagnostics)
      }
  }

  private static func extractMemberConfiguration(
    from variable: VariableDeclSyntax
  ) -> (Bool, AccessLevelModifier?, Bool) {
    let memberConfiguration = variable.attributes
      .first(where: {
        $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Init"
      })?
      .as(AttributeSyntax.self)?
      .arguments?
      .as(LabeledExprListSyntax.self)

    let configuredValues = memberConfiguration?.compactMap {
      $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.trimmedDescription
    } ?? []

    let configuredIgnore = configuredValues.contains("ignore")
    let configuredForceEscaping = configuredValues.contains("escaping")
    let configuredAccessLevel = configuredValues.compactMap(AccessLevelModifier.init(rawValue:)).first

    return (configuredIgnore, configuredAccessLevel, configuredForceEscaping)
  }

  private static func formatParameter(
    from property: MemberProperty,
    optionalsDefaultNil: Bool
  ) -> String {
    let defaultValue = property.initializer.map { " = \($0.description)" }
      ?? (optionalsDefaultNil && property.type.isOptionalType ? " = nil" : "")
    let escaping = (property.configuredForceEscaping || property.type.isFunctionType) ? "@escaping " : ""

    return "\(property.externalName): \(escaping)\(property.type.description)\(defaultValue)"
  }

  private static func formatInitializerAssignmentStatement(from property: MemberProperty) -> String {
    "self.\(property.name) = \(property.externalName)"
  }
}

private struct NonEmptyArray<Element> {
  let head: Element
  let tail: [Element]

  var allElements: [Element] {
    return [head] + tail
  }

  init(head: Element, tail: [Element]) {
    self.head = head
    self.tail = tail
  }

//  func min(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows -> Element {
//    return try allElements.min(by: areInIncreasingOrder)!
//  }
}

private extension NonEmptyArray where Element: Comparable {
  func min() -> Element {
    return allElements.min()!
  }
}
