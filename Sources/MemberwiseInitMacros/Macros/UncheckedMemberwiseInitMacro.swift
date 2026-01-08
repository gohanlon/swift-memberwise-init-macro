import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

public struct UncheckedMemberwiseInitMacro: MemberMacro {
  public static func expansion<D, C>(
    of node: AttributeSyntax,
    providingMembersOf decl: D,
    in context: C
  ) throws -> [SwiftSyntax.DeclSyntax]
  where D: DeclGroupSyntax, C: MacroExpansionContext {
    guard [SwiftSyntax.SyntaxKind.classDecl, .structDecl, .actorDecl].contains(decl.kind) else {
      throw MacroExpansionErrorMessage(
        """
        @_UncheckedMemberwiseInit can only be attached to a struct, class, or actor; \
        not to \(decl.descriptiveDeclKind(withArticle: true)).
        """
      )
    }

    let accessLevel =
      MemberwiseInitMacro.extractConfiguredAccessLevel(from: node) ?? .internal
    let optionalsDefaultNil: Bool? =
      MemberwiseInitMacro.extractLabeledBoolArgument("_optionalsDefaultNil", from: node)
    let deunderscoreParameters: Bool =
      MemberwiseInitMacro.extractLabeledBoolArgument("_deunderscoreParameters", from: node) ?? false

    let properties = try collectUncheckedMemberProperties(
      from: decl.memberBlock.members
    )

    return [
      DeclSyntax(
        MemberwiseInitFormatter.formatInitializer(
          properties: properties,
          accessLevel: accessLevel,
          deunderscoreParameters: deunderscoreParameters,
          optionalsDefaultNil: optionalsDefaultNil
        )
      )
    ]
  }

  private static func collectUncheckedMemberProperties(
    from memberBlockItemList: MemberBlockItemListSyntax
  ) throws -> [MemberProperty] {
    memberBlockItemList.compactMap { member -> MemberProperty? in
      guard let variable = member.decl.as(VariableDeclSyntax.self),
        !variable.isComputedProperty,
        variable.modifiersExclude([.static, .lazy]),
        let binding = variable.bindings.first,
        let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
        let type = binding.typeAnnotation?.type ?? binding.initializer?.value.inferredTypeSyntax
      else { return nil }

      let customSettings = MemberwiseInitMacro.extractVariableCustomSettings(from: variable)
      if customSettings?.ignore == true {
        return nil
      }

      return MemberProperty(
        accessLevel: variable.accessLevel,
        customSettings: customSettings,
        initializerValue: binding.initializer?.value,
        keywordToken: variable.bindingSpecifier.tokenKind,
        name: name,
        type: type.trimmed
      )
    }
  }
}
