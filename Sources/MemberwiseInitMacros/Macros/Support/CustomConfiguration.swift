import SwiftSyntax

extension VariableDeclSyntax {
  var customConfigurationAttributes: [AttributeSyntax] {
    self.attributes
      .compactMap { $0.as(AttributeSyntax.self) }
      .filter {
        ["Init", "InitWrapper", "InitRaw"].contains($0.attributeName.trimmedDescription)
      }
  }

  var customConfigurationAttribute: AttributeSyntax? {
    self.customConfigurationAttributes.first
  }

  var hasCustomConfigurationAttribute: Bool {
    !self.customConfigurationAttributes.isEmpty
  }

  var customConfigurationArguments: LabeledExprListSyntax? {
    self.customConfigurationAttribute?
      .arguments?
      .as(LabeledExprListSyntax.self)
  }
}

extension LabeledExprListSyntax {
  func firstWhereLabel(_ label: String) -> Element? {
    first(where: { $0.label?.text == label })
  }
}

extension AttributeSyntax {
  var isInitWrapper: Bool {
    self.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "InitWrapper"
  }
}
