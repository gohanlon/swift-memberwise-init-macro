import SwiftSyntax
import SwiftSyntaxBuilder

struct MemberwiseInitFormatter {
  static func formatInitializer(
    properties: [MemberProperty],
    accessLevel: AccessLevelModifier,
    optionalsDefaultNil: Bool
  ) -> InitializerDeclSyntax {
    let formattedParameters = formatParameters(
      properties: properties,
      optionalsDefaultNil: optionalsDefaultNil
    )

    let formattedInitSignature = "\n\(accessLevel) init(\(formattedParameters))"

    return try! InitializerDeclSyntax(SyntaxNodeString(stringLiteral: formattedInitSignature)) {
      CodeBlockItemListSyntax(
        properties.map { property in
          CodeBlockItemSyntax(
            stringLiteral: formatInitializerAssignmentStatement(
              for: property,
              considering: properties
            )
          )
        }
      )
    }
  }

  private static func formatParameters(
    properties: [MemberProperty],
    optionalsDefaultNil: Bool
  ) -> String {
    guard !properties.isEmpty else { return "" }

    return "\n"
      + properties
      .map { property in
        formatParameter(
          for: property,
          considering: properties,
          optionalsDefaultNil: optionalsDefaultNil
        )
      }
      .joined(separator: ",\n") + "\n"
  }

  private static func formatParameter(
    for property: MemberProperty,
    considering allProperties: [MemberProperty],
    optionalsDefaultNil: Bool
  ) -> String {
    let defaultValue =
      property.initializerValue.map { " = \($0.description)" }
      ?? property.customSettings?.defaultValue.map { " = \($0)" }
      ?? (optionalsDefaultNil && property.type.isOptionalType ? " = nil" : "")

    let escaping: String
    switch property.customSettings?.escaping {
    case .some(true):
      escaping = "@escaping "
    case .some(false):
      escaping = ""
    case .none:
      escaping = property.type.isFunctionType ? "@escaping " : ""
    }

    let label = property.initParameterLabel(considering: allProperties)

    let parameterName = property.initParameterName(considering: allProperties)

    return "\(label)\(parameterName): \(escaping)\(property.type.description)\(defaultValue)"
  }

  private static func formatInitializerAssignmentStatement(
    for property: MemberProperty,
    considering allProperties: [MemberProperty]
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

    let parameterName = property.initParameterName(considering: allProperties)
    return "\(assignee) = \(parameterName)"
  }
}
