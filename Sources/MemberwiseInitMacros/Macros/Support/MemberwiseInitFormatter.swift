import SwiftSyntax
import SwiftSyntaxBuilder

struct MemberwiseInitFormatter {
  static func formatInitializer(
    properties: [MemberProperty],
    accessLevel: AccessLevelModifier,
    deunderscoreParameters: Bool,
    optionalsDefaultNil: Bool?
  ) -> InitializerDeclSyntax {
    let formattedParameters = formatParameters(
      properties: properties,
      deunderscoreParameters: deunderscoreParameters,
      optionalsDefaultNil: optionalsDefaultNil,
      accessLevel: accessLevel
    )

    let formattedInitSignature = "\n\(accessLevel) init(\(formattedParameters))"

    return try! InitializerDeclSyntax(SyntaxNodeString(stringLiteral: formattedInitSignature)) {
      CodeBlockItemListSyntax(
        properties.map { property in
          CodeBlockItemSyntax(
            stringLiteral: formatInitializerAssignmentStatement(
              for: property,
              considering: properties,
              deunderscoreParameters: deunderscoreParameters
            )
          )
        }
      )
    }
  }

  private static func formatParameters(
    properties: [MemberProperty],
    deunderscoreParameters: Bool,
    optionalsDefaultNil: Bool?,
    accessLevel: AccessLevelModifier
  ) -> String {
    guard !properties.isEmpty else { return "" }

    return "\n"
      + properties
      .map { property in
        formatParameter(
          for: property,
          considering: properties,
          deunderscoreParameters: deunderscoreParameters,
          optionalsDefaultNil: optionalsDefaultNil
            ?? MemberwiseInitMacro.defaultOptionalsDefaultNil(
              for: property.keywordToken,
              initAccessLevel: accessLevel
            )
        )
      }
      .joined(separator: ",\n") + "\n"
  }

  private static func formatParameter(
    for property: MemberProperty,
    considering allProperties: [MemberProperty],
    deunderscoreParameters: Bool,
    optionalsDefaultNil: Bool
  ) -> String {
    let defaultValue =
      property.initializerValue.map { " = \($0.description)" }
      ?? property.customSettings?.defaultValue.map { " = \($0)" }
      ?? (optionalsDefaultNil && property.type.isOptionalType ? " = nil" : "")

    let escaping =
      (property.customSettings?.forceEscaping ?? false || property.type.isFunctionType)
      ? "@escaping " : ""

    let label = property.initParameterLabel(
      considering: allProperties, deunderscoreParameters: deunderscoreParameters)

    let parameterName = property.initParameterName(
      considering: allProperties, deunderscoreParameters: deunderscoreParameters)

    return "\(label)\(parameterName): \(escaping)\(property.type.description)\(defaultValue)"
  }

  private static func formatInitializerAssignmentStatement(
    for property: MemberProperty,
    considering allProperties: [MemberProperty],
    deunderscoreParameters: Bool
  ) -> String {
    let assignee =
      switch property.customSettings?.assignee {
      case .none:
        "self.\(property.name)"
      case .wrapper:
        "self._\(property.name)"
      case .raw(let assignee):
        assignee
      }

    let parameterName = property.initParameterName(
      considering: allProperties,
      deunderscoreParameters: deunderscoreParameters
    )
    return "\(assignee) = \(parameterName)"
  }
}
