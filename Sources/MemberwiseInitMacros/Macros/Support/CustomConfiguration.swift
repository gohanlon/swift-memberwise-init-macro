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

  var hasNonConfigurationAttributes: Bool {
    self.attributes.filter { attribute in
      switch attribute {
      case .attribute:
        true
      case .ifConfigDecl:
        false
      }
    }.count != self.customConfigurationAttributes.count
  }

  var hasCustomConfigurationAttribute: Bool {
    !self.customConfigurationAttributes.isEmpty
  }

  var customConfigurationArguments: LabeledExprListSyntax? {
    self.customConfigurationAttribute?
      .arguments?
      .as(LabeledExprListSyntax.self)
  }

  func hasSoleArgument(_ label: String) -> Bool {
    guard let arguments = self.customConfigurationArguments else { return false }
    return arguments.count == 1 && arguments.first?.label?.text == label
  }

  func includesArgument(_ label: String) -> Bool {
    guard let arguments = self.customConfigurationArguments else { return false }
    return arguments.first(where: { $0.label?.text == label }) != nil
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
