import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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

    // @InitWrapper and @InitRaw can be errors instead of warnings since they haven't seen release.
    if attributeName != "Init" {
      return MacroExpansionErrorMessage(message)
    }
    // @Init(default:) hasn't seen release, so any misuses that include "default" can be an error.
    if variable.includesArgument("default") {
      return MacroExpansionErrorMessage(message)
    }

    // TODO: For 1.0, @Init can also be an error
    // Conservatively, make @Init be a warning to tolerate uses relying on @Init being silently ignored.
    return MacroExpansionWarningMessage(message)
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
      message: MacroExpansionWarningMessage(
        "@\(attributeName) can't be applied to 'static' members"
      ),
      fixIts: [variable.fixItRemoveCustomInit].compactMap { $0 }
    )
  }

  if let modifier = variable.firstModifierWhere(keyword: .lazy) {
    return Diagnostic(
      node: modifier,
      message: MacroExpansionWarningMessage("@\(attributeName) can't be applied to 'lazy' members"),
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
        "Add '@\(customAttribute.attributeName.trimmedDescription)(.\(targetAccessLevel))'"
      ),
      changes: [
        FixIt.Change.replace(
          oldNode: Syntax(variable),
          newNode: Syntax(newVariable)
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
          oldNode: Syntax(variable),
          newNode: Syntax(newVariable)
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
        "Add '\(customAttribute.trimmedDescription)' and an initializer"
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
          oldNode: Syntax(variable),
          newNode: Syntax(newVariable)
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
      // TODO: test coverage on @InitRaw(default:) and @InitWrapper(default:), not just @Init(default:)
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
          newNode: Syntax(newAttribute)
        )
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
          oldNode: Syntax(self),
          newNode: Syntax(newVariable)
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
          ?? TypeSyntax.self(
            MissingTypeSyntax(placeholder: TokenSyntax(stringLiteral: "\u{3C}#Type#\u{3E}"))
          )!
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
          oldNode: Syntax(self),
          newNode: Syntax(newNode)
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

// MARK: - Diagnose AttributeSyntax

extension AttributeSyntax {

  func allInlinabilityFixIts(typeAccessLevel: AccessLevelModifier) -> [FixIt] {
    // NB: returning nil when empty to be consistent with Diagnostic's choice of default argument value
    var result: [FixIt] = []
    if let fixItRemoveInlinability {
      result.append(fixItRemoveInlinability)
    }
    if let fixItReplaceUsableFromInlineWithInlinable {
      result.append(fixItReplaceUsableFromInlineWithInlinable)
    }
    if let fixItsMakeAccessLevelCompatibleWithInlinabilityChoice = fixItsMakeAccessLevelCompatibleWithInlinabilityChoice(typeAccessLevel: typeAccessLevel) {
      result.append(contentsOf: fixItsMakeAccessLevelCompatibleWithInlinabilityChoice)
    }

    return result
  }

  var fixItRemoveInlinability: FixIt? {
    guard
      let inlinability = firstArgumentValue(
        interpretableAs: InlinabilityAttribute.self
      ),
      case .argumentList(let originalArgumentList) = arguments
    else {
      return nil
    }

    return FixIt(
      message: MacroExpansionFixItMessage("Remove '.\(inlinability)'."),
      changes: [
        .replace(
          oldNode: Syntax(self),
          newNode: Syntax(
            self.with(
              \.arguments,
              .argumentList(
                originalArgumentList.removingFirstArgumentValue(
                  interpretableAs: InlinabilityAttribute.self
                )
              )
            )
          )
        )
      ]
    )
  }

  var fixItReplaceUsableFromInlineWithInlinable: FixIt? {
    guard
      let inlinability = firstArgumentValue(
        interpretableAs: InlinabilityAttribute.self
      ),
      inlinability == .usableFromInline,
      let accessLevel = firstArgumentValue(interpretableAs: AccessLevelModifier.self),
      [.public, .open].contains(accessLevel),
      case .argumentList(let originalArgumentList) = arguments
    else {
      return nil
    }

    return FixIt(
      message: MacroExpansionFixItMessage(
        "Change '.\(inlinability)' to '.inlinable'."
      ),
      changes: [
        .replace(
          oldNode: Syntax(self),
          newNode: Syntax(
            self.with(
              \.arguments,
              .argumentList(
                originalArgumentList.replacingFirstArgument(
                  interpretableAs: InlinabilityAttribute.self,
                  with: LabeledExprSyntax(expression: ExprSyntax(".inlinable"))
                )
              )
            )
          )
        )
      ]
    )
  }

  func fixItsMakeAccessLevelCompatibleWithInlinabilityChoice(typeAccessLevel: AccessLevelModifier) -> [FixIt]? {
    guard
      let inlinability = firstArgumentValue(interpretableAs: InlinabilityAttribute.self),
      let originalAccessLevel = firstArgumentValue(
        interpretableAs: AccessLevelModifier.self
      ),
      [.private, .fileprivate].contains(originalAccessLevel),
      case .argumentList(let originalArgumentList) = arguments
    else {
      return nil
    }

    let accessLevels: [AccessLevelModifier]
    switch inlinability {
    case .usableFromInline:
      accessLevels = [.internal, .package]
    case .inlinable:
      accessLevels = [.internal, .package, .public, .open]
    }

    return accessLevels
      .lazy
      .filter { $0 <= typeAccessLevel }
      .map { accessLevel in
        FixIt(
          message: MacroExpansionFixItMessage(
            "Change '.\(originalAccessLevel)' to '.\(accessLevel)'."
          ),
          changes: [
            .replace(
              oldNode: Syntax(self),
              newNode: Syntax(
                self.with(
                  \.arguments,
                  .argumentList(
                    originalArgumentList.replacingFirstArgument(
                      interpretableAs: AccessLevelModifier.self,
                      with: LabeledExprSyntax(expression: ExprSyntax(".\(raw: accessLevel)"))
                    )
                  )
                )
              )
            )
          ]
        )
      }
  }

}
