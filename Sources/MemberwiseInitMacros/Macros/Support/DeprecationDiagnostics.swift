import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacroExpansion

func deprecationDiagnostics(
  node: AttributeSyntax,
  declaration decl: some DeclGroupSyntax
) -> [Diagnostic] {
  return diagnoseDotEscaping(decl)
}

private func diagnoseDotEscaping<D: DeclGroupSyntax>(_ decl: D) -> [Diagnostic] {
  guard let decl = decl.as(StructDeclSyntax.self) else { return [] }

  return decl.memberBlock.members.compactMap { element -> Diagnostic? in
    guard
      let configuration = element.decl
        .as(VariableDeclSyntax.self)?
        .customConfigurationArguments
    else { return nil }

    let dotEscapingIndex = configuration.firstIndex(
      where: {
        $0.expression
          .as(MemberAccessExprSyntax.self)?
          .declName.baseName.text == "escaping"
      }
    )
    guard let dotEscapingIndex else { return nil }

    let newIndex =
      configuration.firstIndex(where: { $0.label?.text == "label" })
      .map { configuration.index(before: $0) }
      ?? configuration.endIndex

    let newEscaping = LabeledExprSyntax(
      label: .identifier("escaping"),
      colon: .colonToken(trailingTrivia: .space),
      expression: BooleanLiteralExprSyntax(booleanLiteral: true),
      trailingComma: newIndex != configuration.endIndex ? .commaToken(trailingTrivia: .space) : nil
    )

    var newConfiguration = configuration
    newConfiguration.remove(at: dotEscapingIndex)
    newConfiguration.insert(newEscaping, at: newIndex)

    return Diagnostic(
      node: configuration,
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
            oldNode: Syntax(configuration),
            newNode: Syntax(newConfiguration)
          )
        ]
      )
    )
  }
}
