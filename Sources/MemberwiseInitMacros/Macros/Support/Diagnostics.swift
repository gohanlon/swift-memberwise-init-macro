import SwiftDiagnostics
import SwiftSyntax

enum MemberwiseInitMacroDiagnostic: Error, DiagnosticMessage {
  case labelAppliedToMultipleBindings
  case labelConflictsWithProperty(String)
  case labelConflictsWithAnotherLabel(String)
  case invalidDeclarationKind(DeclGroupSyntax)
  case invalidSwiftLabel
  case missingTypeForVarProperty
  case tupleDestructuringInProperty

  private var rawValue: String {
    switch self {
    case .labelAppliedToMultipleBindings:
      ".labelAppliedToMultipleBindings"

    case .invalidDeclarationKind(let declGroup):
      ".invalidDeclarationKind(\(declGroup.kind))"

    case .invalidSwiftLabel:
      ".invalidLabel"

    case .labelConflictsWithProperty(let label):
      ".labelCollidesWithProperty(\(label))"

    case .labelConflictsWithAnotherLabel(let label):
      ".labelCollidesWithAnotherLabel(\(label))"

    case .missingTypeForVarProperty:
      ".missingTypeForVarProperty"

    case .tupleDestructuringInProperty:
      ".tupleUsedInProperty"
    }
  }

  var severity: DiagnosticSeverity { .error }

  var message: String {
    switch self {
    case .labelAppliedToMultipleBindings:
      return """
        Custom 'label' can't be applied to multiple bindings
        """

    case let .invalidDeclarationKind(declGroup):
      return """
        @MemberwiseInit can only be attached to a struct, class, or actor; \
        not to \(declGroup.descriptiveDeclKind(withArticle: true)).
        """

    case .invalidSwiftLabel:
      return "Invalid label value"

    case let .labelConflictsWithProperty(label):
      return "Label '\(label)' conflicts with a property name"

    case let .labelConflictsWithAnotherLabel(label):
      return "Label '\(label)' conflicts with another label"

    case .missingTypeForVarProperty:
      return
        "@MemberwiseInit requires a type annotation."

    case .tupleDestructuringInProperty:
      return """
        @MemberwiseInit does not support tuple destructuring for property declarations. \
        Use multiple declarations instead.
        """
    }
  }

  var diagnosticID: MessageID {
    .init(domain: "MemberwiseInitMacro", id: rawValue)
  }
}

extension DeclGroupSyntax {
  func descriptiveDeclKind(withArticle article: Bool = false) -> String {
    switch self {
    case is ActorDeclSyntax:
      return article ? "an actor" : "actor"
    case is ClassDeclSyntax:
      return article ? "a class" : "class"
    case is ExtensionDeclSyntax:
      return article ? "an extension" : "extension"
    case is ProtocolDeclSyntax:
      return article ? "a protocol" : "protocol"
    case is StructDeclSyntax:
      return article ? "a struct" : "struct"
    case is EnumDeclSyntax:
      return article ? "an enum" : "enum"
    default:
      return "`\(self.kind)`"
    }
  }
}
