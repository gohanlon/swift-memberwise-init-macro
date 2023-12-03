import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
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

    deprecationDiagnostics(node: node, declaration: decl)
      .forEach(context.diagnose)

    let configuredAccessLevel: AccessLevelModifier? = extractConfiguredAccessLevel(from: node)
    let optionalsDefaultNil: Bool? =
      extractLabeledBoolArgument("_optionalsDefaultNil", from: node)
    let deunderscoreParameters: Bool =
      extractLabeledBoolArgument("_deunderscoreParameters", from: node) ?? false

    let accessLevel = configuredAccessLevel ?? .internal
    let (properties, diagnostics) = try collectMemberPropertiesAndDiagnostics(
      from: decl.memberBlock.members,
      targetAccessLevel: accessLevel
    )
    diagnostics.forEach { context.diagnose($0) }

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
    from memberBlockItemList: MemberBlockItemListSyntax,
    targetAccessLevel: AccessLevelModifier
  ) throws -> ([MemberProperty], [Diagnostic]) {
    let (variables, variableDiagnostics) = collectMemberVariables(
      from: memberBlockItemList,
      targetAccessLevel: targetAccessLevel
    )

    let bindings = collectPropertyBindings(variables: variables)
    let bindingDiagnostics = customInitLabelDiagnosticsFor(bindings: bindings)

    var (properties, memberDiagnostics) = collectMemberProperties(bindings: bindings)
    memberDiagnostics += customInitLabelDiagnosticsFor(properties: properties)

    return (properties, variableDiagnostics + bindingDiagnostics + memberDiagnostics)
  }

  private static func collectMemberVariables(
    from memberBlockItemList: MemberBlockItemListSyntax,
    targetAccessLevel: AccessLevelModifier
  ) -> ([MemberVariable], [Diagnostic]) {
    memberBlockItemList
      .reduce(
        into: (
          variables: [MemberVariable](),
          diagnostics: [Diagnostic]()
        )
      ) { acc, member in
        guard
          let variable = member.decl.as(VariableDeclSyntax.self),
          variable.attributes.isEmpty || variable.hasCustomConfigurationAttribute,
          variable.modifiersExclude([.static, .lazy]),
          !variable.isComputedProperty
        else { return }

        if variable.customConfigurationAttributes.count > 1 {
          acc.diagnostics += variable.customConfigurationAttributes.dropFirst().map { attribute in
            Diagnostic(
              node: attribute,
              message: MacroExpansionErrorMessage(
                """
                Multiple @Init configurations are not supported by @MemberwiseInit
                """
              )
            )
          }
          return
        }

        let customSettings = extractVariableCustomSettings(from: variable)
        if let customSettings, customSettings.ignore {
          return
        }

        var diagnostics = [Diagnostic]()

        if let customSettings, customSettings.label?.isInvalidSwiftLabel ?? false {
          diagnostics.append(customSettings.diagnosticOnLabelValue(message: .invalidSwiftLabel))
        } else if let customSettings,
          let label = customSettings.label,
          label != "_",
          variable.bindings.count > 1
        {
          diagnostics.append(
            customSettings.diagnosticOnLabel(message: .labelAppliedToMultipleBindings)
          )
        }

        // TODO: repetition of logic for custom configuration logic
        let effectiveAccessLevel = customSettings?.accessLevel ?? variable.accessLevel
        if targetAccessLevel > effectiveAccessLevel,
          !variable.isFullyInitializedLet
        {
          let customAccess = variable.customConfigurationArguments?
            .first?
            .expression
            .as(MemberAccessExprSyntax.self)

          let targetNode =
            customAccess?._syntaxNode
            ?? (variable.modifiers.isEmpty ? variable._syntaxNode : variable.modifiers._syntaxNode)

          diagnostics += [
            Diagnostic(
              node: targetNode,
              message: MacroExpansionErrorMessage(
                """
                @MemberwiseInit(.\(targetAccessLevel)) would leak access to '\(effectiveAccessLevel)' property
                """
              )
            )
          ]
        }

        guard diagnostics.isEmpty else {
          acc.diagnostics += diagnostics
          return
        }

        acc.variables.append(
          MemberVariable(
            customSettings: customSettings,
            syntax: variable
          )
        )
      }
  }

  private static func customInitLabelDiagnosticsFor(bindings: [PropertyBinding]) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    let customLabeledBindings = bindings.filter {
      $0.variable.customSettings?.label != nil
    }

    // Diagnose custom label conflicts with another custom label
    var seenCustomLabels: Set<String> = []
    for binding in customLabeledBindings {
      guard
        let customSettings = binding.variable.customSettings,
        let label = customSettings.label,
        label != "_"
      else { continue }
      defer { seenCustomLabels.insert(label) }
      if seenCustomLabels.contains(label) {
        diagnostics.append(
          customSettings.diagnosticOnLabelValue(message: .labelConflictsWithAnotherLabel(label))
        )
      }
    }

    return diagnostics
  }

  private static func customInitLabelDiagnosticsFor(properties: [MemberProperty]) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    let propertiesByName = Dictionary(uniqueKeysWithValues: properties.map { ($0.name, $0) })

    // Diagnose custom label conflicts with a property
    for property in properties {
      guard
        let propertyCustomSettings = property.customSettings,
        let label = propertyCustomSettings.label,
        let duplicated = propertiesByName[label],
        duplicated != property
      else { continue }

      diagnostics.append(
        propertyCustomSettings.diagnosticOnLabelValue(message: .labelConflictsWithProperty(label))
      )
    }

    return diagnostics
  }

  private static func collectPropertyBindings(variables: [MemberVariable]) -> [PropertyBinding] {
    variables.flatMap { variable -> [PropertyBinding] in
      variable.bindings
        .reversed()
        .reduce(
          into: (
            bindings: [PropertyBinding](),
            typeFromTrailingBinding: TypeSyntax?.none
          )
        ) { acc, binding in
          acc.bindings.append(
            PropertyBinding(
              typeFromTrailingBinding: acc.typeFromTrailingBinding,
              syntax: binding,
              variable: variable
            )
          )
          acc.typeFromTrailingBinding =
            binding.typeAnnotation?.type ?? acc.typeFromTrailingBinding
        }
        .bindings
        .reversed()
    }
  }

  private static func collectMemberProperties(
    bindings: [PropertyBinding]
  ) -> (
    members: [MemberProperty],
    diagnostics: [Diagnostic]
  ) {
    bindings.reduce(
      into: (
        members: [MemberProperty](),
        diagnostics: [Diagnostic]()
      )
    ) { acc, propertyBinding in
      if propertyBinding.isInitializedLet {
        return
      }

      if propertyBinding.isInitializedVarWithoutType {
        acc.diagnostics.append(propertyBinding.diagnostic(message: .missingTypeForVarProperty))
        return
      }
      if propertyBinding.isTuplePattern {
        acc.diagnostics.append(propertyBinding.diagnostic(message: .tupleDestructuringInProperty))
        return
      }

      guard
        let name = propertyBinding.name,
        let effectiveType = propertyBinding.effectiveType
      else { return }

      let newProperty = MemberProperty(
        accessLevel: propertyBinding.variable.accessLevel,
        customSettings: propertyBinding.variable.customSettings,
        initializerValue: propertyBinding.initializerValue,
        keywordToken: propertyBinding.variable.keywordToken,
        name: name,
        type: effectiveType.trimmed
      )
      acc.members.append(newProperty)
    }
  }

  private static func extractVariableCustomSettings(
    from variable: VariableDeclSyntax
  ) -> VariableCustomSettings? {
    guard let customConfigurationAttribute = variable.customConfigurationAttribute else {
      return nil
    }

    let customConfiguration = variable.customConfigurationArguments

    let configuredValues =
      customConfiguration?.compactMap {
        $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.trimmedDescription
      }

    let configuredAccessLevel =
      configuredValues?
      .compactMap(AccessLevelModifier.init(rawValue:))
      .first

    let configuredAssignee: VariableCustomSettings.Assignee? =
      (customConfigurationAttribute.isInitWrapper ? .wrapper : nil)
      ?? customConfiguration?
      .firstWhereLabel("assignee")?
      .expression
      .trimmedStringLiteral
      .map(VariableCustomSettings.Assignee.raw)

    let configuredForceEscaping =
      (customConfiguration?
        .firstWhereLabel("escaping")?
        .expression
        .as(BooleanLiteralExprSyntax.self)?
        .literal
        .text == "true")
      || configuredValues?.contains("escaping") ?? false  // Deprecated; remove in 1.0

    let configuredIgnore = configuredValues?.contains("ignore") ?? false

    let configuredDefault =
      customConfiguration?
      .firstWhereLabel("default")?
      .expression
      .trimmedDescription

    let configuredLabel =
      customConfiguration?
      .firstWhereLabel("label")?
      .expression
      .trimmedStringLiteral

    let configuredType =
      customConfiguration?
      .firstWhereLabel("type")?
      .expression
      .trimmedDescription

    // TODO: Is it possible for invalid type syntax to be provided for an `Any.Type` parameter?
    // NB: All expressions satisfying the `Any.Type` parameter type are parsable to TypeSyntax.
    let configuredTypeSyntax =
      configuredType.map(TypeSyntax.init(stringLiteral:))

    return VariableCustomSettings(
      accessLevel: configuredAccessLevel,
      assignee: configuredAssignee,
      defaultValue: configuredDefault,
      forceEscaping: configuredForceEscaping,
      ignore: configuredIgnore,
      label: configuredLabel,
      type: configuredTypeSyntax,
      _syntaxNode: customConfigurationAttribute
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
    case .package, .public, .open:
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
      property.initializerValue.map { " = \($0.description)" }
      ?? property.customSettings?.defaultValue.map { " = \($0.description)" }
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
    let assignee =
      switch property.customSettings?.assignee {
      case .none:
        "self.\(property.name)"
      case .wrapper:
        "self._\(property.name)"
      case let .raw(assignee):
        assignee
      }

    let parameterName = property.initParameterName(
      considering: allProperties,
      deunderscoreParameters: deunderscoreParameters
    )
    return "\(assignee) = \(parameterName)"
  }
}

private struct VariableCustomSettings: Equatable {
  enum Assignee: Equatable {
    case wrapper
    case raw(String)
  }

  let accessLevel: AccessLevelModifier?
  let assignee: Assignee?
  let defaultValue: String?
  let forceEscaping: Bool
  let ignore: Bool
  let label: String?
  let type: TypeSyntax?
  let _syntaxNode: AttributeSyntax

  func diagnosticOnLabel(message: MemberwiseInitMacroDiagnostic) -> Diagnostic {
    let labelNode = self._syntaxNode
      .arguments?
      .as(LabeledExprListSyntax.self)?
      .firstWhereLabel("label")

    return diagnostic(node: labelNode ?? self._syntaxNode, message: message)
  }

  func diagnosticOnLabelValue(message: MemberwiseInitMacroDiagnostic) -> Diagnostic {
    let labelValueNode = self._syntaxNode
      .arguments?
      .as(LabeledExprListSyntax.self)?
      .firstWhereLabel("label")?
      .expression

    return diagnostic(node: labelValueNode ?? self._syntaxNode, message: message)
  }

  private func diagnostic(
    node: any SyntaxProtocol,
    message: MemberwiseInitMacroDiagnostic
  ) -> Diagnostic {
    Diagnostic(node: node, message: message)
  }
}

private struct PropertyBinding {
  let typeFromTrailingBinding: TypeSyntax?
  let syntax: PatternBindingSyntax
  let variable: MemberVariable

  var effectiveType: TypeSyntax? {
    variable.customSettings?.type
      ?? self.syntax.typeAnnotation?.type
      ?? self.syntax.initializer?.value.inferredTypeSyntax
      ?? self.typeFromTrailingBinding
  }

  var initializerValue: ExprSyntax? {
    self.syntax.initializer?.trimmed.value
  }

  var isComputedProperty: Bool {
    self.syntax.isComputedProperty
  }

  var isTuplePattern: Bool {
    self.syntax.pattern.isTuplePattern
  }

  // TODO: think carefully about how to improve this situation
  var name: String? {
    self.syntax.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
  }

  var isInitializedVarWithoutType: Bool {
    self.initializerValue != nil
      && self.variable.keywordToken == .keyword(.var)
      && self.effectiveType == nil
      && self.initializerValue?.inferredTypeSyntax == nil
  }

  var isInitializedLet: Bool {
    self.initializerValue != nil && self.variable.keywordToken == .keyword(.let)
  }

  func diagnostic(message: MemberwiseInitMacroDiagnostic) -> Diagnostic {
    Diagnostic(node: self.syntax._syntaxNode, message: message)
  }
}

private struct MemberVariable {
  let customSettings: VariableCustomSettings?
  let syntax: VariableDeclSyntax

  var accessLevel: AccessLevelModifier {
    self.syntax.accessLevel
  }

  var bindings: PatternBindingListSyntax {
    self.syntax.bindings
  }

  var keywordToken: TokenKind {
    self.syntax.bindingSpecifier.tokenKind
  }

  var _syntaxNode: Syntax {
    self.syntax._syntaxNode
  }
}

private struct MemberProperty: Equatable {
  let accessLevel: AccessLevelModifier
  let customSettings: VariableCustomSettings?
  let initializerValue: ExprSyntax?
  let keywordToken: TokenKind
  let name: String
  let type: TypeSyntax

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
