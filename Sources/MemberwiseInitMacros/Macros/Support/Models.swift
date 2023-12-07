import SwiftDiagnostics
import SwiftSyntax

struct VariableCustomSettings: Equatable {
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

  var customAttributeName: String {
    self._syntaxNode.attributeName.trimmedDescription
  }

  func diagnosticOnDefault(_ message: DiagnosticMessage, fixIts: [FixIt] = []) -> Diagnostic {
    let labelNode = self._syntaxNode
      .arguments?
      .as(LabeledExprListSyntax.self)?
      .firstWhereLabel("default")

    return diagnostic(node: labelNode ?? self._syntaxNode, message: message, fixIts: fixIts)
  }

  func diagnosticOnLabel(_ message: DiagnosticMessage, fixIts: [FixIt] = []) -> Diagnostic {
    let labelNode = self._syntaxNode
      .arguments?
      .as(LabeledExprListSyntax.self)?
      .firstWhereLabel("label")

    return diagnostic(node: labelNode ?? self._syntaxNode, message: message, fixIts: fixIts)
  }

  func diagnosticOnLabelValue(_ message: DiagnosticMessage) -> Diagnostic {
    let labelValueNode = self._syntaxNode
      .arguments?
      .as(LabeledExprListSyntax.self)?
      .firstWhereLabel("label")?
      .expression

    return diagnostic(node: labelValueNode ?? self._syntaxNode, message: message)
  }

  private func diagnostic(
    node: any SyntaxProtocol,
    message: DiagnosticMessage,
    fixIts: [FixIt] = []
  ) -> Diagnostic {
    Diagnostic(node: node, message: message, fixIts: fixIts)
  }
}

struct PropertyBinding {
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

  var isTuplePattern: Bool {
    self.syntax.pattern.isTuplePattern
  }

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

  func diagnostic(_ message: DiagnosticMessage) -> Diagnostic {
    Diagnostic(node: self.syntax._syntaxNode, message: message)
  }
}

struct MemberVariable {
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
}

struct MemberProperty: Equatable {
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
