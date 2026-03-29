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
  return diagnoseDeunderscoreParameters(node)
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
