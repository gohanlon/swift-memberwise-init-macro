import SwiftSyntax

extension VariableDeclSyntax {
  var customConfiguration: LabeledExprListSyntax? {
    self.attributes
      .first(where: {
        $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Init"
      })?
      .as(AttributeSyntax.self)?
      .arguments?
      .as(LabeledExprListSyntax.self)
  }
}

extension LabeledExprListSyntax {
  func firstWhereLabel(_ label: String) -> Element? {
    first(where: { $0.label?.text == label })
  }
}
