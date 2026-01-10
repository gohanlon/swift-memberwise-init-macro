import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

func deprecationDiagnostics(
  node: AttributeSyntax,
  declaration decl: some DeclGroupSyntax
) -> [Diagnostic] {
  return diagnoseDeunderscoreParameters(node) + diagnoseDotEscaping(decl)
}

private func diagnoseDeunderscoreParameters(_ node: AttributeSyntax) -> [Diagnostic] {
  guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
    return []
  }

  guard
    let argument = arguments.first(where: { $0.label?.text == "_deunderscoreParameters" })
  else {
    return []
  }

  return [
    Diagnostic(
      node: argument,
      message: MacroExpansionWarningMessage(
        "_deunderscoreParameters is deprecated; use @Init(label:) on individual properties instead"
      )
    )
  ]
}

private func diagnoseDotEscaping<D: DeclGroupSyntax>(_ decl: D) -> [Diagnostic] {
  guard let decl = decl.as(StructDeclSyntax.self) else { return [] }

  return decl.memberBlock.members.compactMap { element -> Diagnostic? in
    guard
      let oldConfiguration = element.decl
        .as(VariableDeclSyntax.self)?
        .customConfigurationArguments
    else { return nil }

    var configuration = oldConfiguration

    let dotEscapingIndex = configuration.firstIndex(
      where: {
        $0.expression
          .as(MemberAccessExprSyntax.self)?
          .declName.baseName.text == "escaping"
      }
    )
    guard let dotEscapingIndex else { return nil }

    configuration.remove(at: dotEscapingIndex)

    let newIndex =
      configuration.firstIndex(where: { $0.label?.text == "label" })
      ?? configuration.endIndex

    let newEscaping = LabeledExprSyntax(
      label: .identifier("escaping"),
      colon: .colonToken(trailingTrivia: .space),
      expression: BooleanLiteralExprSyntax(booleanLiteral: true),
      trailingComma: newIndex != configuration.endIndex ? .commaToken(trailingTrivia: .space) : nil
    )

    configuration.insert(newEscaping, at: newIndex)

    return Diagnostic(
      node: oldConfiguration,
      message: MacroExpansionWarningMessage(
        """
        @Init(.escaping) is deprecated
        """
      ),
      fixIt: FixIt(
        message: MacroExpansionFixItMessage(
          "Replace '@Init(.escaping)' with '@Init(escaping: true)'"
        ),
        changes: [
          FixIt.Change.replace(
            oldNode: Syntax(oldConfiguration),
            newNode: Syntax(configuration)
          )
        ]
      )
    )
  }
}
