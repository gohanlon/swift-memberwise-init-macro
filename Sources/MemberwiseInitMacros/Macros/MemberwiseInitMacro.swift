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
    let optionalsDefaultNil: Bool? =
      extractLabeledBoolArgument("_optionalsDefaultNil", from: node)
    let deunderscoreParameters: Bool =
      extractLabeledBoolArgument("_deunderscoreParameters", from: node) ?? false

    let (properties, diagnostics) = try collectMemberPropertiesAndDiagnostics(
      from: decl.memberBlock.members
    )
    diagnostics.forEach { context.diagnose($0) }

    let accessLevel = NonEmptyArray(
      head: configuredAccessLevel ?? .internal,
      tail: properties.compactMap { $0.customSettings?.accessLevel ?? $0.accessLevel }
    ).min()

    func formatParameters() -> String {
      guard !properties.isEmpty else { return "" }

      return "\n"
        + properties
        .map { property in
          formatParameter(
            for: property,
            considering: properties,
            deunderscoreParameters: deunderscoreParameters,
            optionalsDefaultNil: optionalsDefaultNil
              ?? defaultOptionalsDefaultNil(
                for: property.keywordToken,
                initAccessLevel: accessLevel
              )
          )
        }
        .joined(separator: ",\n")
        + "\n"
    }

    let formattedInitSignature = "\n\(accessLevel) init(\(formatParameters()))"
    return [
      DeclSyntax(
        try InitializerDeclSyntax(SyntaxNodeString(stringLiteral: formattedInitSignature)) {
          CodeBlockItemListSyntax(
            properties
              .map { property in
                CodeBlockItemSyntax(
                  stringLiteral: formatInitializerAssignmentStatement(
                    for: property,
                    considering: properties,
                    deunderscoreParameters: deunderscoreParameters
                  )
                )
              }
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

  private static func extractLabeledBoolArgument(
    _ label: String,
    from node: AttributeSyntax
  ) -> Bool? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self)
    else { return nil }

    let argument = arguments.filter { labeledExprSyntax in
      labeledExprSyntax.label?.text == label
    }.first

    guard let argument else { return nil }
    return argument.expression.as(BooleanLiteralExprSyntax.self)?.literal.text == "true"
  }

  private static func collectMemberPropertiesAndDiagnostics(
    from decl: MemberBlockItemListSyntax
  ) throws -> ([MemberProperty], [Diagnostic]) {
    var (properties, diagnostics) = try collectMemberProperties(from: decl)
    diagnostics += diagnosticsOnCustomInitLabels(properties: properties)
    return (properties, diagnostics)
  }

  private static func collectMemberProperties(
    from decl: MemberBlockItemListSyntax
  ) throws -> ([MemberProperty], [Diagnostic]) {
    return
      decl
      .compactMap { (member: MemberBlockItemSyntax) -> VariableDeclSyntax? in
        guard
          let variable = member.decl.as(VariableDeclSyntax.self),
          variable.attributes.isEmpty || variable.attributes.contains(attributeNamed: "Init"),
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
              typeFromTrailingBinding: TypeSyntax?.none
            )
          ) { acc, binding in
            let customSettings = extractPropertyCustomSettings(from: variable)

            if let customSettings, customSettings.ignore {
              return
            }

            let type =
              binding.typeAnnotation?.type
              ?? binding.initializer?.value.inferredTypeSyntax
              ?? acc.typeFromTrailingBinding

            acc.bindings.append(
              PropertyBinding(
                accessLevel: variable.accessLevel,
                adoptedType: type,
                binding: binding,
                customSettings: customSettings,
                keywordToken: variable.bindingSpecifier.tokenKind
              )
            )
            acc.typeFromTrailingBinding =
              binding.typeAnnotation?.type ?? acc.typeFromTrailingBinding
          }
          .bindings
          .reversed()
      }
      .reduce(
        (
          [MemberProperty](),
          [Diagnostic]()
        )
      ) { acc, propertyBinding in
        let (properties, diagnostics) = acc
        if propertyBinding.isComputedProperty || propertyBinding.isPreinitializedLet {
          return (properties, diagnostics)
        }
        if propertyBinding.isPreinitializedVarWithoutType,
          propertyBinding.initializer?.inferredTypeSyntax == nil
        {
          return (
            properties,
            diagnostics + [propertyBinding.diagnostic(message: .missingTypeForVarProperty)]
          )
        }
        if propertyBinding.isTuplePattern {
          return (
            properties,
            diagnostics + [propertyBinding.diagnostic(message: .tupleDestructuringInProperty)]
          )
        }

        if let customSettings = propertyBinding.customSettings {
          if customSettings.label?.isInvalidSwiftLabel ?? false {
            return (
              properties,
              diagnostics + [customSettings.diagnostic(message: .invalidSwiftLabel)]
            )
          }
        }
        guard
          let name = propertyBinding.name,
          let effectiveType = propertyBinding.effectiveType
        else { return (properties, diagnostics) }

        let newProperty = MemberProperty(
          accessLevel: propertyBinding.accessLevel,
          customSettings: propertyBinding.customSettings,
          initializer: propertyBinding.initializer,
          keywordToken: propertyBinding.keywordToken,
          name: name,
          type: effectiveType.trimmed
        )
        return (properties + [newProperty], diagnostics)
      }
  }

  private static func diagnosticsOnCustomInitLabels(properties: [MemberProperty]) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    var seenLabels: Set<String> = []
    for property in properties {
      guard
        let propertyCustomSettings = property.customSettings,
        let label = propertyCustomSettings.label,
        label != "_"
      else { continue }
      defer { seenLabels.insert(label) }
      if seenLabels.contains(label) {
        diagnostics.append(
          propertyCustomSettings.diagnosticOnLabel(message: .labelConflictsWithAnotherLabel(label))
        )
      }
    }

    let propertiesByName: [String: MemberProperty] = properties.reduce([:]) { acc, property in
      var acc = acc
      acc[property.name] = property
      return acc
    }
    for property in properties {
      guard
        let propertyCustomSettings = property.customSettings,
        let label = propertyCustomSettings.label,
        let duplicated = propertiesByName[label],
        duplicated != property
      else { continue }

      diagnostics.append(
        propertyCustomSettings.diagnosticOnLabel(message: .labelConflictsWithProperty(label))
      )
    }

    return diagnostics
  }

  private static func extractPropertyCustomSettings(
    from variable: VariableDeclSyntax
  ) -> PropertyCustomSettings? {
    let memberConfiguration = variable.attributes
      .first(where: {
        $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Init"
      })?
      .as(AttributeSyntax.self)?
      .arguments?
      .as(LabeledExprListSyntax.self)

    guard let memberConfiguration else { return nil }

    let configuredValues =
      memberConfiguration.compactMap {
        $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.trimmedDescription
      }

    let configuredIgnore = configuredValues.contains("ignore")
    let configuredForceEscaping = configuredValues.contains("escaping")
    let configuredAccessLevel =
      configuredValues
      .compactMap(AccessLevelModifier.init(rawValue:))
      .first
    let configuredLabel =
      memberConfiguration
      .first(where: { $0.label?.text == "label" })?
      .expression
      .as(StringLiteralExprSyntax.self)?
      .segments
      .trimmedDescription
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return PropertyCustomSettings(
      accessLevel: configuredAccessLevel,
      forceEscaping: configuredForceEscaping,
      ignore: configuredIgnore,
      label: configuredLabel,
      _syntaxNode: memberConfiguration
    )
  }

  private static func defaultOptionalsDefaultNil(
    for bindingKeyword: TokenKind,
    initAccessLevel: AccessLevelModifier
  ) -> Bool {
    guard bindingKeyword == .keyword(.var) else { return false }
    return switch initAccessLevel {
    case .private, .fileprivate, .internal:
      true
    case .public, .open:
      false
    }
  }

  private static func formatParameter(
    for property: MemberProperty,
    considering allProperties: [MemberProperty],
    deunderscoreParameters: Bool,
    optionalsDefaultNil: Bool
  ) -> String {
    let defaultValue =
      property.initializer.map { " = \($0.description)" }
      ?? (optionalsDefaultNil && property.type.isOptionalType ? " = nil" : "")
    let escaping =
      (property.customSettings?.forceEscaping ?? false || property.type.isFunctionType)
      ? "@escaping " : ""
    let label = property.initParameterLabel(
      considering: allProperties, deunderscoreParameters: deunderscoreParameters)
    let parameterName = property.initParameterName(
      considering: allProperties, deunderscoreParameters: deunderscoreParameters)

    return "\(label)\(parameterName): \(escaping)\(property.type.description)\(defaultValue)"
  }

  private static func formatInitializerAssignmentStatement(
    for property: MemberProperty,
    considering allProperties: [MemberProperty],
    deunderscoreParameters: Bool
  ) -> String {
    "self.\(property.name) = \(property.initParameterName(considering: allProperties, deunderscoreParameters: deunderscoreParameters))"
  }
}

private struct PropertyCustomSettings: Equatable {
  let accessLevel: AccessLevelModifier?
  let forceEscaping: Bool
  let ignore: Bool
  let label: String?
  let _syntaxNode: LabeledExprListSyntax

  func diagnostic(message: MemberwiseInitMacroDiagnostic) -> Diagnostic {
    Diagnostic(node: self._syntaxNode, message: message)
  }

  func diagnosticOnLabel(message: MemberwiseInitMacroDiagnostic) -> Diagnostic {
    let labelNode = self._syntaxNode
      .first(where: { $0.label?.text == "label" })?
      .expression
    guard let labelNode else { return diagnostic(message: message) }
    return Diagnostic(node: labelNode, message: message)
  }
}

private struct PropertyBinding {
  let accessLevel: AccessLevelModifier
  let customSettings: PropertyCustomSettings?
  let effectiveType: TypeSyntax?
  let initializer: ExprSyntax?
  let isComputedProperty: Bool
  let isTuplePattern: Bool
  let keywordToken: TokenKind
  let name: String?
  private let _syntaxNode: Syntax

  // TODO: Make this a simple memberwise init?
  // Yes, while droping `binding` from params.
  // Or, store `binding` and add a bunch of computed properties.
  init(
    accessLevel: AccessLevelModifier,
    adoptedType: TypeSyntax?,
    binding: PatternBindingSyntax,
    customSettings: PropertyCustomSettings?,
    keywordToken: TokenKind
  ) {
    self.accessLevel = accessLevel
    self.customSettings = customSettings
    self.effectiveType = binding.typeAnnotation?.type ?? adoptedType
    self.initializer = binding.initializer?.trimmed.value
    self.isComputedProperty = binding.isComputedProperty
    self.isTuplePattern = binding.pattern.isTuplePattern
    self.keywordToken = keywordToken
    self.name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    self._syntaxNode = binding._syntaxNode
  }

  var isPreinitializedVarWithoutType: Bool {
    self.initializer != nil
      && self.effectiveType == nil
      && self.keywordToken == .keyword(.var)
  }

  var isPreinitializedLet: Bool {
    self.initializer != nil && self.keywordToken == .keyword(.let)
  }

  func diagnostic(message: MemberwiseInitMacroDiagnostic) -> Diagnostic {
    Diagnostic(node: self._syntaxNode, message: message)
  }
}

private struct MemberProperty: Equatable {
  let accessLevel: AccessLevelModifier
  let customSettings: PropertyCustomSettings?
  let initializer: ExprSyntax?
  let keywordToken: TokenKind
  let name: String
  let type: TypeSyntax

  init(
    accessLevel: AccessLevelModifier,
    customSettings: PropertyCustomSettings?,
    initializer: ExprSyntax?,
    keywordToken: TokenKind,
    name: String,
    type: TypeSyntax
  ) {
    self.accessLevel = accessLevel
    self.customSettings = customSettings
    self.initializer = initializer
    self.keywordToken = keywordToken
    self.name = name
    self.type = type
  }

  func initParameterLabel(
    considering allProperties: [MemberProperty],
    deunderscoreParameters: Bool
  ) -> String {
    guard
      let customSettings = self.customSettings,
      customSettings.label
        != self.initParameterName(
          considering: allProperties,
          deunderscoreParameters: deunderscoreParameters
        )
    else { return "" }

    return customSettings.label.map { "\($0) " } ?? ""
  }

  func initParameterName(
    considering allProperties: [MemberProperty],
    deunderscoreParameters: Bool
  ) -> String {
    guard
      self.customSettings?.label == nil,
      deunderscoreParameters
    else { return self.name }

    let potentialName = self.name.hasPrefix("_") ? String(name.dropFirst()) : self.name
    return allProperties.contains(where: { $0.name == potentialName }) ? self.name : potentialName
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

extension NonEmptyArray where Element: Comparable {
  fileprivate func min() -> Element {
    return allElements.min()!
  }
}
