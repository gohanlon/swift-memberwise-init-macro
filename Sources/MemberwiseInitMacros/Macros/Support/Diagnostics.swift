import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacroExpansion

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
      [
        diagnoseVariableLabel(customSettings: settings, variable: variable),
        diagnoseDefaultValueAppliedToMultipleBindings(
          customSettings: settings,
          variable: variable
        ),
      ].compactMap { $0 }
    } ?? []

  let accessibilityDiagnostics = [
    diagnoseAccessibilityLeak(
      customSettings: customSettings,
      variable: variable,
      targetAccessLevel: targetAccessLevel
    )
  ].compactMap { $0 }

  return customSettingsDiagnostics + accessibilityDiagnostics
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
    customSettings.defaultValue != nil,
    variable.bindings.count > 1
  else { return nil }

  return customSettings.diagnosticOnDefault(
    MacroExpansionErrorMessage("Custom 'default' can't be applied to multiple bindings")
  )
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

  return Diagnostic(
    node: targetNode,
    message: MacroExpansionErrorMessage(
      """
      @MemberwiseInit(.\(targetAccessLevel)) would leak access to '\(effectiveAccessLevel)' property
      """
    )
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
      propertyCustomSettings.diagnosticOnLabelValue(
        MacroExpansionErrorMessage("Label '\(label)' conflicts with a property name")
      )
    )
  }

  return diagnostics
}
