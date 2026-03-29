import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

public struct UncheckedMemberwiseInitMacro: MemberMacro {
  #if canImport(SwiftSyntax601)
    public static func expansion(
      of node: AttributeSyntax,
      providingMembersOf decl: some DeclGroupSyntax,
      conformingTo protocols: [TypeSyntax],
      in context: some MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
      try expansionImpl(of: node, providingMembersOf: decl, in: context)
    }
  #else
    public static func expansion<D, C>(
      of node: AttributeSyntax,
      providingMembersOf decl: D,
      in context: C
    ) throws -> [SwiftSyntax.DeclSyntax]
    where D: DeclGroupSyntax, C: MacroExpansionContext {
      try expansionImpl(of: node, providingMembersOf: decl, in: context)
    }
  #endif

  private static func expansionImpl(
    of node: AttributeSyntax,
    providingMembersOf decl: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [SwiftSyntax.DeclSyntax] {
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
    let optionalsDefaultNil: Bool =
      MemberwiseInitMacro.extractLabeledBoolArgument("optionalsDefaultNil", from: node) ?? false

    let properties = try collectUncheckedMemberProperties(
      from: decl.memberBlock.members
    )

    return [
      DeclSyntax(
        MemberwiseInitFormatter.formatInitializer(
          properties: properties,
          accessLevel: accessLevel,
          optionalsDefaultNil: optionalsDefaultNil
        )
      )
    ]
  }

  private static func collectUncheckedMemberProperties(
    from memberBlockItemList: MemberBlockItemListSyntax
  ) throws -> [MemberProperty] {
    memberBlockItemList.flatMap { member -> [MemberProperty] in
      guard let variable = member.decl.as(VariableDeclSyntax.self),
        !variable.isComputedProperty,
        variable.modifiersExclude([.static, .lazy]),
        let binding = variable.bindings.first
      else { return [] }

      let customSettings = MemberwiseInitMacro.extractVariableCustomSettings(from: variable)
      if customSettings?.ignore == true {
        return []
      }

      // Handle tuple destructuring
      if let tuplePattern = binding.pattern.as(TuplePatternSyntax.self),
        let tupleType = binding.typeAnnotation?.type.as(TupleTypeSyntax.self)
      {
        let patternElements = Array(tuplePattern.elements)
        let typeElements = Array(tupleType.elements)
        guard patternElements.count == typeElements.count else { return [] }

        let initializerValues: [ExprSyntax?]
        if let tupleExpr = binding.initializer?.value.as(TupleExprSyntax.self),
          tupleExpr.elements.count == patternElements.count
        {
          initializerValues = tupleExpr.elements.map { $0.expression }
        } else {
          initializerValues = Array(repeating: nil, count: patternElements.count)
        }

        return zip(patternElements, zip(typeElements, initializerValues)).compactMap {
          patternElement, typeAndInit in
          let (typeElement, initValue) = typeAndInit
          guard
            let name = patternElement.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
          else { return nil }
          return MemberProperty(
            accessLevel: variable.accessLevel,
            customSettings: customSettings,
            initializerValue: initValue,
            keywordToken: variable.bindingSpecifier.tokenKind,
            name: name,
            type: typeElement.type.trimmed
          )
        }
      }

      guard
        let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
        let type = binding.typeAnnotation?.type ?? binding.initializer?.value.inferredTypeSyntax
      else { return [] }

      return [
        MemberProperty(
          accessLevel: variable.accessLevel,
          customSettings: customSettings,
          initializerValue: binding.initializer?.value,
          keywordToken: variable.bindingSpecifier.tokenKind,
          name: name,
          type: type.trimmed
        )
      ]
    }
  }
}
