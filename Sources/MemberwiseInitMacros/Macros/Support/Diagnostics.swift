import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

// MARK: - Diagnose attributed properties

func diagnoseAttributedPropertyWithoutInit(
  variable: VariableDeclSyntax
) -> Diagnostic {
  let nonConfigAttributes = variable.attributes
    .compactMap { $0.as(AttributeSyntax.self) }
    .filter {
      let name = $0.attributeName.trimmedDescription
      if ["Init", "InitWrapper", "InitRaw"].contains(name) { return false }
      if case .safe = knownAttribute(name) { return false }
      return true
    }

  // Prefer recognized property wrappers over other attributes for the diagnostic
  let diagnosticAttribute: AttributeSyntax? =
    nonConfigAttributes.first(where: {
      guard let kind = knownAttribute($0.attributeName.trimmedDescription) else { return false }
      if case .safe = kind { return false }
      return true
    }) ?? nonConfigAttributes.first

  let attributeName = diagnosticAttribute?.attributeName.trimmedDescription ?? "custom"
  let kind = knownAttribute(attributeName)

  let fixIts: [FixIt]
  switch kind {
  case .wrapperInit(let qualifiedName):
    fixIts = fixItsForWrapperInit(
      variable: variable,
      attributeName: attributeName,
      qualifiedName: qualifiedName
    )

  case .directInclude(let qualifiedName):
    fixIts = fixItsForDirectInclude(
      variable: variable,
      qualifiedName: qualifiedName
    )

  case .ignore(let qualifiedName, let reason):
    fixIts = fixItsForIgnore(
      variable: variable,
      qualifiedName: qualifiedName,
      reason: reason
    )

  case .safe:
    // Should never reach here — safe attributes are filtered out
    fixIts = fixItsForUnknown(variable: variable)

  case nil:
    fixIts = fixItsForUnknown(variable: variable)
  }

  return Diagnostic(
    node: variable._syntaxNode,
    message: MacroExpansionErrorMessage(
      """
      @MemberwiseInit requires explicit @Init configuration for property with \
      '@\(attributeName)' attribute
      """
    ),
    fixIts: fixIts
  )
}

// MARK: Fix-its by attribute kind

private func fixItsForWrapperInit(
  variable: VariableDeclSyntax,
  attributeName: String,
  qualifiedName: String
) -> [FixIt] {
  let wrapperName =
    attributeName.contains(".")
    ? String(attributeName.split(separator: ".").last!)
    : attributeName
  let propertyType: TypeSyntax? = variable.bindings.first?.typeAnnotation?.type

  let typeArg: String
  if let propertyType {
    typeArg = "\(wrapperName)<\(propertyType.trimmedDescription)>.self"
  } else {
    typeArg = "\(wrapperName)<\u{3C}#Type#\u{3E}>.self"
  }

  return [
    makeAddAttributeFixIt(
      variable: variable,
      attributeString: "@InitWrapper(type: \(typeArg))",
      message: "Add '@InitWrapper(type: \(typeArg))' (@\(qualifiedName))"
    ),
    makeAddInitFixIt(
      variable: variable,
      message: "Add '@Init' to include in the initializer"
    ),
    makeAddIgnoreFixIt(variable: variable, message: nil),
  ]
}

private func fixItsForDirectInclude(
  variable: VariableDeclSyntax,
  qualifiedName: String
) -> [FixIt] {
  [
    makeAddInitFixIt(
      variable: variable,
      message: "Add '@Init' to include in the initializer (@\(qualifiedName))"
    ),
    makeAddIgnoreFixIt(variable: variable, message: nil),
  ]
}

private func fixItsForIgnore(
  variable: VariableDeclSyntax,
  qualifiedName: String,
  reason: IgnoreReason
) -> [FixIt] {
  if reason.noteOnInitFixIt {
    // firstRender: note goes on @Init fix-it, not on @Init(.ignore)
    return [
      makeAddIgnoreFixIt(variable: variable, message: nil),
      makeAddInitFixIt(
        variable: variable,
        message: "Add '@Init' to include (@\(qualifiedName) — \(reason.note))"
      ),
    ]
  } else {
    // injected, frameworkManaged, etc: note goes on @Init(.ignore)
    return [
      makeAddIgnoreFixIt(
        variable: variable,
        message: "Add '@Init(.ignore)' (@\(qualifiedName) — \(reason.note))"
      ),
      makeAddInitFixIt(
        variable: variable,
        message: "Add '@Init' to include in the initializer"
      ),
    ]
  }
}

private func fixItsForUnknown(
  variable: VariableDeclSyntax
) -> [FixIt] {
  [
    makeAddInitFixIt(
      variable: variable,
      message: "Add '@Init' to include in the initializer"
    ),
    makeAddIgnoreFixIt(variable: variable, message: nil),
  ]
}

// MARK: Primitive fix-it constructors

private func makeAddAttributeFixIt(
  variable: VariableDeclSyntax,
  attributeString: String,
  message: String
) -> FixIt {
  var attr = AttributeSyntax(stringLiteral: "\(attributeString)\n")
  attr.leadingTrivia = variable.leadingTrivia

  var newVariable = variable
  newVariable.leadingTrivia = Trivia()
  newVariable.attributes = AttributeListSyntax(
    [.attribute(attr)] + Array(variable.attributes)
  )

  return FixIt(
    message: MacroExpansionFixItMessage(message),
    changes: [.replace(oldNode: Syntax(variable), newNode: Syntax(newVariable))]
  )
}

private func makeAddInitFixIt(
  variable: VariableDeclSyntax,
  message: String
) -> FixIt {
  makeAddAttributeFixIt(
    variable: variable,
    attributeString: "@Init",
    message: message
  )
}

/// Builds an `@Init(.ignore)` fix-it, adding a default value placeholder when needed.
/// When `message` is nil, a default message is generated based on initialization state.
private func makeAddIgnoreFixIt(
  variable: VariableDeclSyntax,
  message: String?
) -> FixIt {
  var ignoreAttr = AttributeSyntax(stringLiteral: "@Init(.ignore)\n")
  ignoreAttr.leadingTrivia = variable.leadingTrivia

  var newVariable = variable
  newVariable.leadingTrivia = Trivia()
  newVariable.attributes = AttributeListSyntax(
    [.attribute(ignoreAttr)] + Array(variable.attributes)
  )

  let needsDefault = !variable.isFullyInitialized

  if needsDefault {
    newVariable.bindings = PatternBindingListSyntax(
      newVariable.bindings.map { binding in
        guard binding.initializer == nil else { return binding }
        var newBinding = binding
        newBinding.initializer = InitializerClauseSyntax(
          equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
          value: EditorPlaceholderExprSyntax(
            placeholder: TokenSyntax(stringLiteral: "\u{3C}#value#\u{3E}")
          )
        )
        return newBinding
      }
    )
  }

  let effectiveMessage: String
  if let message {
    effectiveMessage = needsDefault ? "\(message) and a default value" : message
  } else {
    effectiveMessage =
      needsDefault
      ? "Add '@Init(.ignore)' and a default value"
      : "Add '@Init(.ignore)'"
  }

  return FixIt(
    message: MacroExpansionFixItMessage(effectiveMessage),
    changes: [.replace(oldNode: Syntax(variable), newNode: Syntax(newVariable))]
  )
}

// MARK: - Diagnose VariableDeclSyntax

func diagnoseMultipleConfigurations(variable: VariableDeclSyntax) -> [Diagnostic]? {
  guard variable.customConfigurationAttributes.count > 1 else { return nil }

  return variable.customConfigurationAttributes.dropFirst().map { attribute in
    Diagnostic(
      node: attribute,
      message: MacroExpansionErrorMessage(
        "Multiple @Init configurations are not supported by @MemberwiseInit"
      )
    )
  }
}

func diagnoseVariableDecl(
  customSettings: VariableCustomSettings?,
  variable: VariableDeclSyntax,
  targetAccessLevel: AccessLevelModifier
) -> [Diagnostic] {
  let customSettingsDiagnostics =
    customSettings.map { settings in
      if let diagnostic = diagnoseInitOnInitializedLet(customSettings: settings, variable: variable)
      {
        return [diagnostic]
      }

      if let diagnostic = diagnoseMemberModifiers(customSettings: settings, variable: variable) {
        return [diagnostic]
      }

      return [
        diagnoseVariableLabel(customSettings: settings, variable: variable),
        diagnoseDefaultValueAppliedToMultipleBindings(
          customSettings: settings,
          variable: variable
        )
          ?? diagnoseDefaultValueAppliedToInitialized(customSettings: settings, variable: variable),
      ].compactMap { $0 }
    } ?? [Diagnostic]()

  let accessibilityDiagnostics = [
    diagnoseAccessibilityLeak(
      customSettings: customSettings,
      variable: variable,
      targetAccessLevel: targetAccessLevel
    )
  ].compactMap { $0 }

  return customSettingsDiagnostics + accessibilityDiagnostics
}

private func diagnoseInitOnInitializedLet(
  customSettings: VariableCustomSettings,
  variable: VariableDeclSyntax
) -> Diagnostic? {
  guard
    variable.isLet,
    variable.isFullyInitialized
  else { return nil }

  let fixIts = [
    variable.fixItRemoveCustomInit,
    variable.fixItRemoveInitializer,
  ].compactMap { $0 }

  var diagnosticMessage: DiagnosticMessage {
    let attributeName = customSettings.customAttributeName

    let message = "@\(attributeName) can't be applied to already initialized constant"

    return MacroExpansionErrorMessage(message)
  }

  return customSettings.diagnosticOnDefault(diagnosticMessage, fixIts: fixIts)
}

private func diagnoseMemberModifiers(
  customSettings: VariableCustomSettings,
  variable: VariableDeclSyntax
) -> Diagnostic? {
  let attributeName = customSettings.customAttributeName

  if let modifier = variable.firstModifierWhere(keyword: .static) {
    return Diagnostic(
      node: modifier,
      message: MacroExpansionErrorMessage(
        "@\(attributeName) can't be applied to 'static' members"),
      fixIts: [variable.fixItRemoveCustomInit].compactMap { $0 }
    )
  }

  if let modifier = variable.firstModifierWhere(keyword: .lazy) {
    return Diagnostic(
      node: modifier,
      message: MacroExpansionErrorMessage("@\(attributeName) can't be applied to 'lazy' members"),
      fixIts: [variable.fixItRemoveCustomInit].compactMap { $0 }
    )
  }

  return nil
}

private func diagnoseVariableLabel(
  customSettings: VariableCustomSettings,
  variable: VariableDeclSyntax
) -> Diagnostic? {
  if let label = customSettings.label,
    label != "_",
    variable.bindings.count > 1
  {
    return customSettings.diagnosticOnLabel(
      MacroExpansionErrorMessage("Custom 'label' can't be applied to multiple bindings")
    )
  }

  if customSettings.label?.isInvalidSwiftLabel ?? false {
    return customSettings.diagnosticOnLabelValue(MacroExpansionErrorMessage("Invalid label value"))
  }

  return nil
}

private func diagnoseDefaultValueAppliedToMultipleBindings(
  customSettings: VariableCustomSettings,
  variable: VariableDeclSyntax
) -> Diagnostic? {
  guard
    let defaultValue = customSettings.defaultValue,
    variable.bindings.count > 1
  else { return nil }

  let fixIts = [
    determineRemoveDefaultFixIt(variable: variable, defaultValue: defaultValue),
    determineRemoveCustomInitFixIt(variable: variable),
  ].compactMap { $0 }

  return customSettings.diagnosticOnDefault(
    MacroExpansionErrorMessage("Custom 'default' can't be applied to multiple bindings"),
    fixIts: fixIts
  )
}

private func diagnoseDefaultValueAppliedToInitialized(
  customSettings: VariableCustomSettings,
  variable: VariableDeclSyntax
) -> Diagnostic? {
  guard
    let defaultValue = customSettings.defaultValue,
    variable.isFullyInitialized
  else { return nil }

  let fixIts = [
    determineRemoveDefaultFixIt(variable: variable, defaultValue: defaultValue),
    determineRemoveCustomInitFixIt(variable: variable),
    variable.fixItRemoveInitializer,
  ].compactMap { $0 }

  return customSettings.diagnosticOnDefault(
    MacroExpansionErrorMessage("Custom 'default' can't be applied to already initialized variable"),
    fixIts: fixIts
  )
}

private func determineRemoveDefaultFixIt(
  variable: VariableDeclSyntax,
  defaultValue: String
) -> FixIt? {
  let shouldRemoveDefault =
    variable.isVar
    && (!variable.hasSoleArgument("default") || variable.hasNonConfigurationAttributes)
    || variable.bindings.count > 1 && !variable.hasSoleArgument("default")

  return shouldRemoveDefault ? variable.fixItRemoveDefault(defaultValue: defaultValue) : nil
}

private func determineRemoveCustomInitFixIt(
  variable: VariableDeclSyntax
) -> FixIt? {
  let shouldRemoveCustomInit =
    !variable.hasNonConfigurationAttributes && variable.hasSoleArgument("default")

  return shouldRemoveCustomInit ? variable.fixItRemoveCustomInit : nil
}

private func diagnoseAccessibilityLeak(
  customSettings: VariableCustomSettings?,
  variable: VariableDeclSyntax,
  targetAccessLevel: AccessLevelModifier
) -> Diagnostic? {
  let effectiveAccessLevel = customSettings?.accessLevel ?? variable.accessLevel

  guard
    targetAccessLevel > effectiveAccessLevel,
    !variable.isFullyInitializedLet
  else { return nil }

  let customAccess = variable.customConfigurationArguments?
    .first?
    .expression
    .as(MemberAccessExprSyntax.self)

  let targetNode =
    customAccess?._syntaxNode
    ?? (variable.modifiers.isEmpty ? variable._syntaxNode : variable.modifiers._syntaxNode)

  var fixWithCustomInitAccess: FixIt? {
    var customAttribute =
      variable.customConfigurationAttribute ?? AttributeSyntax(stringLiteral: "@Init() ")
    if customAttribute.arguments == nil {
      customAttribute = AttributeSyntax(
        stringLiteral: "@\(customAttribute.attributeName.trimmedDescription)() "
      )
    }

    let existingArguments =
      customAttribute.arguments?
      .as(LabeledExprListSyntax.self)
      ?? LabeledExprListSyntax()

    let customAccessLevelExpr = LabeledExprSyntax(
      label: nil,
      expression: MemberAccessExprSyntax(
        name: TokenSyntax(stringLiteral: "\(targetAccessLevel)")
      ),
      trailingComma: existingArguments.isEmpty ? nil : .commaToken(trailingTrivia: .space)
    )

    let newArguments =
      [customAccessLevelExpr]
      + existingArguments
      .trimmingPrefix(while: { $0.expression.as(MemberAccessExprSyntax.self) != nil })

    customAttribute.arguments = .argumentList(newArguments)
    customAttribute.leadingTrivia = variable.leadingTrivia

    var newVariable = variable
    newVariable.leadingTrivia = Trivia()
    newVariable.attributes = [.attribute(customAttribute)]

    return FixIt(
      message: MacroExpansionFixItMessage(
        "Add '@\(customAttribute.attributeName.trimmedDescription)(.\(targetAccessLevel))'"),
      changes: [
        FixIt.Change.replace(
          oldNode: Syntax(variable), newNode: Syntax(newVariable)
        )
      ]
    )
  }

  var fixWithAccessModifier: FixIt? {
    // Check if custom configuration attribute has an access level that would override
    if let customAttribute = variable.customConfigurationAttribute,
      MemberwiseInitMacro.extractConfiguredAccessLevel(from: customAttribute) != nil
    {
      return nil
    }

    var newVariable = variable

    func modifyOrAddAccessLevel(to modifiers: DeclModifierListSyntax?) -> DeclModifierListSyntax {
      var modified = false
      let newModifiers =
        modifiers?.map { modifier -> DeclModifierSyntax in
          if modifier.name.text == effectiveAccessLevel.rawValue {
            modified = true
            return
              modifier
              .with(\.name, TokenSyntax(stringLiteral: targetAccessLevel.rawValue))
              .with(\.trailingTrivia, .space)
          }
          return modifier
        } ?? []

      if !modified {
        let additionalModifier = DeclModifierSyntax(
          name: TokenSyntax(stringLiteral: targetAccessLevel.rawValue)
            .with(\.trailingTrivia, .space)
        )
        return [additionalModifier] + (modifiers ?? [])
      }

      return DeclModifierListSyntax(newModifiers)
    }

    newVariable.leadingTrivia = Trivia()
    newVariable.modifiers = modifyOrAddAccessLevel(to: newVariable.modifiers)
    newVariable.leadingTrivia = variable.leadingTrivia

    let message =
      if variable.modifiers.isEmpty {
        "Add '\(targetAccessLevel)' access level"
      } else {
        "Replace '\(variable.modifiers.trimmedDescription)' access with '\(targetAccessLevel)'"
      }

    return FixIt(
      message: MacroExpansionFixItMessage(message),
      changes: [
        FixIt.Change.replace(
          oldNode: Syntax(variable), newNode: Syntax(newVariable)
        )
      ]
    )
  }

  var fixWithCustomInitIgnore: FixIt? {
    var customAttribute = AttributeSyntax(stringLiteral: "@Init(.ignore) ")

    var newVariable = variable.with(\.leadingTrivia, Trivia())
    customAttribute.leadingTrivia = variable.leadingTrivia

    newVariable.attributes = [.attribute(customAttribute)]

    let message =
      if variable.isFullyInitialized {
        "Add '\(customAttribute.trimmedDescription)'"
      } else {
        "Add '\(customAttribute.trimmedDescription)' and a default value"
      }

    newVariable.bindings = PatternBindingListSyntax(
      newVariable.bindings.map { patternBinding in
        guard patternBinding.initializer == nil else { return patternBinding }

        var newBinding = patternBinding
        newBinding.initializer = InitializerClauseSyntax(
          equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
          value: EditorPlaceholderExprSyntax(
            placeholder: TokenSyntax(stringLiteral: "\u{3C}#value#\u{3E}")
          )
        )

        return newBinding
      }
    )

    return FixIt(
      message: MacroExpansionFixItMessage(message),
      changes: [
        FixIt.Change.replace(
          oldNode: Syntax(variable), newNode: Syntax(newVariable)
        )
      ]
    )
  }

  let fixIts: [FixIt] = [
    fixWithCustomInitAccess,
    fixWithAccessModifier,
    fixWithCustomInitIgnore,
  ].compactMap { $0 }

  return Diagnostic(
    node: targetNode,
    message: MacroExpansionErrorMessage(
      """
      @MemberwiseInit(.\(targetAccessLevel)) would leak access to '\(effectiveAccessLevel)' property
      """
    ),
    fixIts: fixIts
  )
}

// MARK: - Diagnose [PropertyBinding] and [MemberProperty]

func customInitLabelDiagnosticsFor(bindings: [PropertyBinding]) -> [Diagnostic] {
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
        customSettings.diagnosticOnLabelValue(
          MacroExpansionErrorMessage("Label '\(label)' conflicts with another label")
        )
      )
    }
  }

  return diagnostics
}

func customInitLabelDiagnosticsFor(properties: [MemberProperty]) -> [Diagnostic] {
  var diagnostics: [Diagnostic] = []

  let propertiesByName = Dictionary(grouping: properties, by: { $0.name })

  // Diagnose custom label conflicts with a property
  for property in properties {
    guard
      let propertyCustomSettings = property.customSettings,
      let label = propertyCustomSettings.label,
      let duplicates = propertiesByName[label],
      duplicates.contains(where: { $0 != property })
    else { continue }

    diagnostics.append(
      propertyCustomSettings.diagnosticOnLabelValue(
        MacroExpansionErrorMessage("Label '\(label)' conflicts with a property name")
      )
    )
  }

  return diagnostics
}

// MARK: Fix-its

extension VariableDeclSyntax {
  func fixItRemoveDefault(defaultValue: String) -> FixIt? {
    guard
      let customAttribute = self.customConfigurationAttribute,
      let arguments = self.customConfigurationArguments
    else { return nil }

    var newAttribute = customAttribute
    let newArguments = arguments.filter { $0.label?.text != "default" }
    newAttribute.arguments = newArguments.as(AttributeSyntax.Arguments.self)
    if newArguments.count == 0 {
      let trailingTrivia = newAttribute.trailingTrivia
      newAttribute.leftParen = nil
      newAttribute.rightParen = nil
      newAttribute.trailingTrivia = trailingTrivia
    }

    return FixIt(
      message: MacroExpansionFixItMessage("Remove 'default: \(defaultValue)'"),
      changes: [
        FixIt.Change.replace(
          oldNode: Syntax(customAttribute),
          newNode: Syntax(newAttribute))
      ]
    )
  }

  var fixItRemoveCustomInit: FixIt? {
    guard let customAttribute = self.customConfigurationAttribute else { return nil }

    let newVariable = AttributeRemover(
      removingWhere: {
        ["Init", "InitWrapper", "InitRaw"].contains($0.attributeName.trimmedDescription)
      }
    ).rewrite(self)

    return FixIt(
      message: MacroExpansionFixItMessage("Remove '\(customAttribute.trimmedDescription)'"),
      changes: [
        FixIt.Change.replace(
          oldNode: Syntax(self), newNode: Syntax(newVariable)
        )
      ]
    )
  }

  var fixItRemoveInitializer: FixIt? {
    guard
      self.bindings.count == 1,
      let firstBinding = self.bindings.first,
      let firstBindingInitializer = firstBinding.initializer
    else { return nil }

    var newFirstBinding = firstBinding.with(\.initializer, nil)

    if firstBinding.typeAnnotation == nil {
      let inferredTypeSyntax = firstBindingInitializer.value.inferredTypeSyntax

      newFirstBinding.typeAnnotation = TypeAnnotationSyntax(
        colon: .colonToken(trailingTrivia: .space),
        type: inferredTypeSyntax
          ?? TypeSyntax(
            MissingTypeSyntax(placeholder: TokenSyntax(stringLiteral: "\u{3C}#Type#\u{3E}")))
      )
      newFirstBinding.pattern = newFirstBinding.pattern.trimmed
    }

    var newNode = self.detached
    newNode.bindings = .init(arrayLiteral: newFirstBinding)

    return FixIt(
      message: MacroExpansionFixItMessage(
        "Remove '\(firstBindingInitializer.trimmedDescription)'"
      ),
      changes: [
        FixIt.Change.replace(
          oldNode: Syntax(self), newNode: Syntax(newNode)
        )
      ]
    )
  }
}

// MARK: - Extensions

extension LabeledExprListSyntax {
  fileprivate func trimmingPrefix(
    while predicate: (LabeledExprListSyntax.Element) throws -> Bool
  ) rethrows -> LabeledExprListSyntax {
    var endIndex = self.startIndex

    while endIndex != self.endIndex, try predicate(self[endIndex]) {
      formIndex(after: &endIndex)
    }

    if endIndex == self.startIndex {
      return self
    } else {
      var modifiedSyntaxList = self
      modifiedSyntaxList.removeSubrange(self.startIndex..<endIndex)
      return modifiedSyntaxList
    }
  }
}
