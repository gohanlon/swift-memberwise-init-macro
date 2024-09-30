//import Foundation
////import SwiftCompilerPlugin
//import SwiftDiagnostics
//import SwiftOperators
//import SwiftSyntax
//import SwiftSyntaxBuilder
//import SwiftSyntaxMacroExpansion
//import SwiftSyntaxMacros
//
//public struct InitMacro: PeerMacro {
//  public static func expansion(
//    of node: SwiftSyntax.AttributeSyntax,
//    providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
//    in context: some SwiftSyntaxMacros.MacroExpansionContext
//  ) throws -> [SwiftSyntax.DeclSyntax] {
//    return []
//  }
//}
//
//public struct MemberwiseInitMacro: MemberMacro {
//  public static func expansion<D, C>(
//    of node: AttributeSyntax,
//    providingMembersOf decl: D,
//    in context: C
//  ) throws -> [SwiftSyntax.DeclSyntax]
//  where D: DeclGroupSyntax, C: MacroExpansionContext {
//    guard [SwiftSyntax.SyntaxKind.classDecl, .structDecl, .actorDecl].contains(decl.kind) else {
//      throw MacroExpansionErrorMessage(
//        """
//        @MemberwiseInit can only be attached to a struct, class, or actor; \
//        not to \(decl.descriptiveDeclKind(withArticle: true)).
//        """
//      )
//    }
//
//    deprecationDiagnostics(node: node, declaration: decl)
//      .forEach(context.diagnose)
//
//    let configuredAccessLevel: AccessLevelModifier? = extractConfiguredAccessLevel(from: node)
//    let optionalsDefaultNil: Bool? =
//      extractLabeledBoolArgument("_optionalsDefaultNil", from: node)
//    let deunderscoreParameters: Bool =
//      extractLabeledBoolArgument("_deunderscoreParameters", from: node) ?? false
//
//    let accessLevel = configuredAccessLevel ?? .internal
//    let (properties, diagnostics) = try collectMemberPropertiesAndDiagnostics(
//      from: decl.memberBlock.members,
//      targetAccessLevel: accessLevel
//    )
//    diagnostics.forEach { context.diagnose($0) }
//
//    func formatParameters() -> String {
//      guard !properties.isEmpty else { return "" }
//
//      return "\n"
//        + properties
//        .map { property in
//          formatParameter(
//            for: property,
//            considering: properties,
//            deunderscoreParameters: deunderscoreParameters,
//            optionalsDefaultNil: optionalsDefaultNil
//              ?? defaultOptionalsDefaultNil(
//                for: property.keywordToken,
//                initAccessLevel: accessLevel
//              )
//          )
//        }
//        .joined(separator: ",\n")
//        + "\n"
//    }
//
//    let formattedInitSignature = "\n\(accessLevel) init(\(formatParameters()))"
//    return [
//      DeclSyntax(
//        try InitializerDeclSyntax(SyntaxNodeString(stringLiteral: formattedInitSignature)) {
//          CodeBlockItemListSyntax(
//            properties
//              .map { property in
//                CodeBlockItemSyntax(
//                  stringLiteral: formatInitializerAssignmentStatement(
//                    for: property,
//                    considering: properties,
//                    deunderscoreParameters: deunderscoreParameters
//                  )
//                )
//              }
//          )
//        }
//      )
//    ]
//  }
//
//  private static func extractConfiguredAccessLevel(
//    from node: AttributeSyntax
//  ) -> AccessLevelModifier? {
//    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self)
//    else { return nil }
//
//    // NB: Search for the first argument whose name matches an access level name
//    for labeledExprSyntax in arguments {
//      if let identifier = labeledExprSyntax.expression.as(MemberAccessExprSyntax.self)?.declName,
//        let accessLevel = AccessLevelModifier(rawValue: identifier.baseName.trimmedDescription)
//      {
//        return accessLevel
//      }
//    }
//
//    return nil
//  }
//
//  private static func extractLabeledBoolArgument(
//    _ label: String,
//    from node: AttributeSyntax
//  ) -> Bool? {
//    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self)
//    else { return nil }
//
//    let argument = arguments.filter { labeledExprSyntax in
//      labeledExprSyntax.label?.text == label
//    }.first
//
//    guard let argument else { return nil }
//    return argument.expression.as(BooleanLiteralExprSyntax.self)?.literal.text == "true"
//  }
//
//  private static func collectMemberPropertiesAndDiagnostics(
//    from memberBlockItemList: MemberBlockItemListSyntax,
//    targetAccessLevel: AccessLevelModifier
//  ) throws -> ([MemberProperty], [Diagnostic]) {
//    let (variables, variableDiagnostics) = collectMemberVariables(
//      from: memberBlockItemList,
//      targetAccessLevel: targetAccessLevel
//    )
//
//    let bindings = collectPropertyBindings(variables: variables)
//    let bindingDiagnostics = customInitLabelDiagnosticsFor(bindings: bindings)
//
//    var (properties, memberDiagnostics) = collectMemberProperties(bindings: bindings)
//    memberDiagnostics += customInitLabelDiagnosticsFor(properties: properties)
//
//    return (properties, variableDiagnostics + bindingDiagnostics + memberDiagnostics)
//  }
//
//  private static func collectMemberVariables(
//    from memberBlockItemList: MemberBlockItemListSyntax,
//    targetAccessLevel: AccessLevelModifier
//  ) -> ([MemberVariable], [Diagnostic]) {
//    memberBlockItemList
//      .reduce(
//        into: (
//          variables: [MemberVariable](),
//          diagnostics: [Diagnostic]()
//        )
//      ) { acc, member in
//        guard
//          let variable = member.decl.as(VariableDeclSyntax.self),
//          variable.attributes.isEmpty || variable.hasCustomConfigurationAttribute,
//          !variable.isComputedProperty
//        else { return }
//
//        if let diagnostics = diagnoseMultipleConfigurations(variable: variable) {
//          acc.diagnostics += diagnostics
//          return
//        }
//
//        let customSettings = extractVariableCustomSettings(from: variable)
//        if let customSettings, customSettings.ignore {
//          return
//        }
//
//        let diagnostics = diagnoseVariableDecl(
//          customSettings: customSettings,
//          variable: variable,
//          targetAccessLevel: targetAccessLevel
//        )
//        guard diagnostics.isEmpty else {
//          acc.diagnostics += diagnostics
//          return
//        }
//
//        guard variable.modifiersExclude([.static, .lazy]) else { return }
//
//        acc.variables.append(
//          MemberVariable(
//            customSettings: customSettings,
//            syntax: variable
//          )
//        )
//      }
//  }
//
//  private static func collectPropertyBindings(variables: [MemberVariable]) -> [PropertyBinding] {
//    variables.flatMap { variable -> [PropertyBinding] in
//      variable.bindings
//        .reversed()
//        .reduce(
//          into: (
//            bindings: [PropertyBinding](),
//            typeFromTrailingBinding: TypeSyntax?.none
//          )
//        ) { acc, binding in
//          acc.bindings.append(
//            PropertyBinding(
//              typeFromTrailingBinding: acc.typeFromTrailingBinding,
//              syntax: binding,
//              variable: variable
//            )
//          )
//          acc.typeFromTrailingBinding =
//            binding.typeAnnotation?.type ?? acc.typeFromTrailingBinding
//        }
//        .bindings
//        .reversed()
//    }
//  }
//
//  private static func collectMemberProperties(
//    bindings: [PropertyBinding]
//  ) -> (
//    members: [MemberProperty],
//    diagnostics: [Diagnostic]
//  ) {
//    bindings.reduce(
//      into: (
//        members: [MemberProperty](),
//        diagnostics: [Diagnostic]()
//      )
//    ) { acc, propertyBinding in
//      if propertyBinding.isInitializedLet {
//        return
//      }
//
//      if propertyBinding.isInitializedVarWithoutType {
//        acc.diagnostics.append(
//          propertyBinding.diagnostic(
//            MacroExpansionErrorMessage("@MemberwiseInit requires a type annotation.")  // TODO: fix-it
//          )
//        )
//        return
//      }
//      if propertyBinding.isTuplePattern {
//        acc.diagnostics.append(
//          propertyBinding.diagnostic(
//            MacroExpansionErrorMessage(
//              """
//              @MemberwiseInit does not support tuple destructuring for property declarations. \
//              Use multiple declarations instead.
//              """
//            )
//          )
//        )
//
//        return
//      }
//
//      guard
//        let name = propertyBinding.name,
//        let effectiveType = propertyBinding.effectiveType
//      else { return }
//
//      let newProperty = MemberProperty(
//        accessLevel: propertyBinding.variable.accessLevel,
//        customSettings: propertyBinding.variable.customSettings,
//        initializerValue: propertyBinding.initializerValue,
//        keywordToken: propertyBinding.variable.keywordToken,
//        name: name,
//        type: effectiveType.trimmed
//      )
//      acc.members.append(newProperty)
//    }
//  }
//
//  private static func extractVariableCustomSettings(
//    from variable: VariableDeclSyntax
//  ) -> VariableCustomSettings? {
//    guard let customConfigurationAttribute = variable.customConfigurationAttribute else {
//      return nil
//    }
//
//    let customConfiguration = variable.customConfigurationArguments
//
//    let configuredValues =
//      customConfiguration?.compactMap {
//        $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.trimmedDescription
//      }
//
//    let configuredAccessLevel =
//      configuredValues?
//      .compactMap(AccessLevelModifier.init(rawValue:))
//      .first
//
//    let configuredAssignee: VariableCustomSettings.Assignee? =
//      (customConfigurationAttribute.isInitWrapper ? .wrapper : nil)
//      ?? customConfiguration?
//      .firstWhereLabel("assignee")?
//      .expression
//      .trimmedStringLiteral
//      .map(VariableCustomSettings.Assignee.raw)
//
//    let configuredForceEscaping =
//      (customConfiguration?
//        .firstWhereLabel("escaping")?
//        .expression
//        .as(BooleanLiteralExprSyntax.self)?
//        .literal
//        .text == "true")
//      || configuredValues?.contains("escaping") ?? false  // Deprecated; remove in 1.0
//
//    let configuredIgnore = configuredValues?.contains("ignore") ?? false
//
//    let configuredDefault =
//      customConfiguration?
//      .firstWhereLabel("default")?
//      .expression
//      .trimmedDescription
//
//    let configuredLabel =
//      customConfiguration?
//      .firstWhereLabel("label")?
//      .expression
//      .trimmedStringLiteral
//
//    let configuredType =
//      customConfiguration?
//      .firstWhereLabel("type")?
//      .expression
//      .trimmedDescription
//
//    // TODO: Is it possible for invalid type syntax to be provided for an `Any.Type` parameter?
//    // NB: All expressions satisfying the `Any.Type` parameter type are parsable to TypeSyntax.
//    let configuredTypeSyntax =
//      configuredType.map(TypeSyntax.init(stringLiteral:))
//
//    return VariableCustomSettings(
//      accessLevel: configuredAccessLevel,
//      assignee: configuredAssignee,
//      defaultValue: configuredDefault,
//      forceEscaping: configuredForceEscaping,
//      ignore: configuredIgnore,
//      label: configuredLabel,
//      type: configuredTypeSyntax,
//      _syntaxNode: customConfigurationAttribute
//    )
//  }
//
//  private static func defaultOptionalsDefaultNil(
//    for bindingKeyword: TokenKind,
//    initAccessLevel: AccessLevelModifier
//  ) -> Bool {
//    guard bindingKeyword == .keyword(.var) else { return false }
//    return switch initAccessLevel {
//    case .private, .fileprivate, .internal:
//      true
//    case .package, .public, .open:
//      false
//    }
//  }
//
//  private static func formatParameter(
//    for property: MemberProperty,
//    considering allProperties: [MemberProperty],
//    deunderscoreParameters: Bool,
//    optionalsDefaultNil: Bool
//  ) -> String {
//    let defaultValue =
//      property.initializerValue.map { " = \($0.description)" }
//      ?? property.customSettings?.defaultValue.map { " = \($0.description)" }
//      ?? (optionalsDefaultNil && property.type.isOptionalType ? " = nil" : "")
//
//    let escaping =
//      (property.customSettings?.forceEscaping ?? false || property.type.isFunctionType)
//      ? "@escaping " : ""
//
//    let label = property.initParameterLabel(
//      considering: allProperties, deunderscoreParameters: deunderscoreParameters)
//
//    let parameterName = property.initParameterName(
//      considering: allProperties, deunderscoreParameters: deunderscoreParameters)
//
//    return "\(label)\(parameterName): \(escaping)\(property.type.description)\(defaultValue)"
//  }
//
//  private static func formatInitializerAssignmentStatement(
//    for property: MemberProperty,
//    considering allProperties: [MemberProperty],
//    deunderscoreParameters: Bool
//  ) -> String {
//    let assignee =
//      switch property.customSettings?.assignee {
//      case .none:
//        "self.\(property.name)"
//      case .wrapper:
//        "self._\(property.name)"
//      case let .raw(assignee):
//        assignee
//      }
//
//    let parameterName = property.initParameterName(
//      considering: allProperties,
//      deunderscoreParameters: deunderscoreParameters
//    )
//    return "\(assignee) = \(parameterName)"
//  }
//}
//
//// Modified from IanKeen's MacroKit:
//// https://github.com/IanKeen/MacroKit/blob/main/Sources/MacroKitMacros/Support/AccessLevelSyntax.swift
////
//// Modifications:
//// - Declarations can have multiple access level modifiers, e.g. `public private(set)`
////   I'm still not dealing with the "detail" (`set`) in any way
//// - Apply Swift's rules concering default access when no access level is explicitly stated (it's not always `internal`):
////   https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol#Custom-Types
//// - Added missing DeclGroupSyntax kinds
//
//// TODO: Rules for local DeclGroup's nested within a function definition
//// TODO: Rules for local access functions? e.g. `func foo() { func bar() { … } … }`
//
//enum AccessLevelModifier: String, Comparable, CaseIterable, Sendable {
//  case `private`
//  case `fileprivate`
//  case `internal`
//  case `package`
//  case `public`
//  case `open`
//
//  var keyword: Keyword {
//    switch self {
//    case .private: return .private
//    case .fileprivate: return .fileprivate
//    case .internal: return .internal
//    case .package: return .package
//    case .public: return .public
//    case .open: return .open
//    }
//  }
//
//  static func < (lhs: AccessLevelModifier, rhs: AccessLevelModifier) -> Bool {
//    let lhs = Self.allCases.firstIndex(of: lhs)!
//    let rhs = Self.allCases.firstIndex(of: rhs)!
//    return lhs < rhs
//  }
//}
//
//public protocol AccessLevelSyntax {
//  var parent: Syntax? { get }
//  var modifiers: DeclModifierListSyntax { get set }
//}
//
//extension AccessLevelSyntax {
//  var accessLevelModifiers: [AccessLevelModifier]? {
//    get {
//      let accessLevels = modifiers.lazy.compactMap { AccessLevelModifier(rawValue: $0.name.text) }
//      return accessLevels.isEmpty ? nil : Array(accessLevels)
//    }
//    set {
//      guard let newModifiers = newValue else {
//        modifiers = []
//        return
//      }
//      let newModifierKeywords = newModifiers.map { DeclModifierSyntax(name: .keyword($0.keyword)) }
//      let filteredModifiers = modifiers.filter {
//        AccessLevelModifier(rawValue: $0.name.text) == nil
//      }
//      modifiers = filteredModifiers + newModifierKeywords
//    }
//  }
//}
//
//protocol DeclGroupAccessLevelSyntax: AccessLevelSyntax {
//}
//extension DeclGroupAccessLevelSyntax {
//  public var accessLevel: AccessLevelModifier {
//    self.accessLevelModifiers?.first ?? .internal
//  }
//}
//
//extension ActorDeclSyntax: DeclGroupAccessLevelSyntax {}
//extension ClassDeclSyntax: DeclGroupAccessLevelSyntax {}
//extension EnumDeclSyntax: DeclGroupAccessLevelSyntax {}
//extension StructDeclSyntax: DeclGroupAccessLevelSyntax {}
//
//// NB: MemberwiseInit doesn't need this on FunctionDeclSyntax extension
////extension FunctionDeclSyntax: AccessLevelSyntax {
////  public var accessLevel: AccessLevelModifier {
////    get {
////      // a decl (function, variable) can
////      if let formalModifier = self.accessLevelModifiers?.first {
////        return formalModifier
////      }
////
////      guard let parent = self.parent else { return .internal }
////
////      if let parent = parent as? DeclGroupSyntax {
////        return [parent.declAccessLevel, .internal].min()!
////      } else {
////        return .internal
////      }
////    }
////  }
////}
//
//extension VariableDeclSyntax: AccessLevelSyntax {
//  var accessLevel: AccessLevelModifier {
//    // TODO: assuming the least access of the modifiers may not be correct, but it suits the special case of MemberwiseInit
//    // maybe this is generally okay, since the "set" detail must be given less access than then get? either way, this needs to be made clearer
//    self.accessLevelModifiers?.min() ?? inferDefaultAccessLevel(node: self._syntaxNode)
//  }
//}
//
//private func inferDefaultAccessLevel(node: Syntax?) -> AccessLevelModifier {
//  guard let node else { return .internal }
//  guard let decl = node.asProtocol(DeclGroupSyntax.self) else {
//    return inferDefaultAccessLevel(node: node.parent)
//  }
//
//  return [decl.declAccessLevel, .internal].min()!
//}
//
//// NB: This extension is sugar to avoid user needing to first cast to a specific kind of decl group syntax
//extension DeclGroupSyntax {
//  var declAccessLevel: AccessLevelModifier {
//    (self as? DeclGroupAccessLevelSyntax)!.accessLevel
//  }
//}
//
///// Removes attributes from a syntax tree while maintaining their surrounding trivia.
//public class AttributeRemover: SyntaxRewriter {
//  let predicate: (AttributeSyntax) -> Bool
//
//  var triviaToAttachToNextToken: Trivia = Trivia()
//
//  /// Initializes an attribute remover with a given predicate to determine which attributes to remove.
//  ///
//  /// - Parameter predicate: A closure that determines whether a given `AttributeSyntax` should be removed.
//  ///   If this closure returns `true` for an attribute, that attribute will be removed.
//  public init(removingWhere predicate: @escaping (AttributeSyntax) -> Bool) {
//    self.predicate = predicate
//  }
//
//  public override func visit(_ nodeList: AttributeListSyntax) -> AttributeListSyntax {
//    var filteredAttributes: [AttributeListSyntax.Element] = []
//
//    for node in nodeList {
//      switch node {
//      case .attribute(let attribute):
//        guard self.predicate(attribute) else {
//          filteredAttributes.append(.attribute(prependAndClearAccumulatedTrivia(to: attribute)))
//          continue
//        }
//
//        var leadingTrivia = attribute.leadingTrivia
//
//        // Don't leave behind an empty line when the attribute being removed is on its own line,
//        // based on the following conditions:
//        //  - Leading trivia ends with a newline followed by arbitrary number of spaces or tabs
//        //  - All leading trivia pieces after the last newline are just whitespace, ensuring
//        //    there are no comments or other non-whitespace characters on the same line
//        //    preceding the attribute.
//        //  - There is no trailing trivia and the next token has leading trivia.
//        if let lastNewline = leadingTrivia.pieces.lastIndex(where: \.isNewline),
//          leadingTrivia.pieces[lastNewline...].allSatisfy(\.isWhitespace),
//          attribute.trailingTrivia.isEmpty,
//          let nextToken = attribute.nextToken(viewMode: .sourceAccurate),
//          !nextToken.leadingTrivia.isEmpty
//        {
//          leadingTrivia = Trivia(pieces: leadingTrivia.pieces[..<lastNewline])
//        }
//
//        // Drop any spaces or tabs from the trailing trivia because there’s no
//        // more attribute they need to separate.
//        let trailingTrivia = attribute.trailingTrivia.trimmingPrefix(while: \.isSpaceOrTab)
//        self.triviaToAttachToNextToken += leadingTrivia + trailingTrivia
//
//        // If the attribute is not separated from the previous attribute by trivia, as in
//        // `@First@Second var x: Int` (yes, that's valid Swift), removing the `@Second`
//        // attribute and dropping all its trivia would cause `@First` and `var` to join
//        // without any trivia in between, which is invalid. In such cases, the trailing trivia
//        // of the attribute is significant and must be retained.
//        if self.triviaToAttachToNextToken.isEmpty,
//          let previousToken = attribute.previousToken(viewMode: .sourceAccurate),
//          previousToken.trailingTrivia.isEmpty
//        {
//          self.triviaToAttachToNextToken = attribute.trailingTrivia
//        }
//
//      case .ifConfigDecl(_):
//        filteredAttributes.append(node)
//      }
//    }
//
//    // Ensure that any horizontal whitespace trailing the attributes list is trimmed if the next
//    // token starts a new line.
//    if let nextToken = nodeList.nextToken(viewMode: .sourceAccurate),
//      nextToken.leadingTrivia.startsWithNewline
//    {
//      if !self.triviaToAttachToNextToken.isEmpty {
//        self.triviaToAttachToNextToken = self.triviaToAttachToNextToken.trimmingSuffix(
//          while: \.isSpaceOrTab)
//      } else if let lastAttribute = filteredAttributes.last {
//        filteredAttributes[filteredAttributes.count - 1].trailingTrivia = lastAttribute
//          .trailingTrivia.trimmingSuffix(while: \.isSpaceOrTab)
//      }
//    }
//    return AttributeListSyntax(filteredAttributes)
//  }
//
//  public override func visit(_ token: TokenSyntax) -> TokenSyntax {
//    return prependAndClearAccumulatedTrivia(to: token)
//  }
//
//  /// Prepends the accumulated trivia to the given node's leading trivia.
//  ///
//  /// To preserve correct formatting after attribute removal, this function reassigns
//  /// significant trivia accumulated from removed attributes to the provided subsequent node.
//  /// Once attached, the accumulated trivia is cleared.
//  ///
//  /// - Parameter node: The syntax node receiving the accumulated trivia.
//  /// - Returns: The modified syntax node with the prepended trivia.
//  private func prependAndClearAccumulatedTrivia<T: SyntaxProtocol>(to syntaxNode: T) -> T {
//    defer { self.triviaToAttachToNextToken = Trivia() }
//    return syntaxNode.with(
//      \.leadingTrivia, self.triviaToAttachToNextToken + syntaxNode.leadingTrivia)
//  }
//}
//
//extension Trivia {
//  fileprivate func trimmingPrefix(
//    while predicate: (TriviaPiece) -> Bool
//  ) -> Trivia {
//    Trivia(pieces: self.drop(while: predicate))
//  }
//
//  fileprivate func trimmingSuffix(
//    while predicate: (TriviaPiece) -> Bool
//  ) -> Trivia {
//    Trivia(
//      pieces: self[...]
//        .reversed()
//        .drop(while: predicate)
//        .reversed()
//    )
//  }
//
//  fileprivate var startsWithNewline: Bool {
//    self.first?.isNewline ?? false
//  }
//}
//
//extension VariableDeclSyntax {
//  var customConfigurationAttributes: [AttributeSyntax] {
//    self.attributes
//      .compactMap { $0.as(AttributeSyntax.self) }
//      .filter {
//        ["Init", "InitWrapper", "InitRaw"].contains($0.attributeName.trimmedDescription)
//      }
//  }
//
//  var customConfigurationAttribute: AttributeSyntax? {
//    self.customConfigurationAttributes.first
//  }
//
//  var hasNonConfigurationAttributes: Bool {
//    self.attributes.filter { attribute in
//      switch attribute {
//      case .attribute:
//        true
//      case .ifConfigDecl:
//        false
//      }
//    }.count != self.customConfigurationAttributes.count
//  }
//
//  var hasCustomConfigurationAttribute: Bool {
//    !self.customConfigurationAttributes.isEmpty
//  }
//
//  var customConfigurationArguments: LabeledExprListSyntax? {
//    self.customConfigurationAttribute?
//      .arguments?
//      .as(LabeledExprListSyntax.self)
//  }
//
//  func hasSoleArgument(_ label: String) -> Bool {
//    guard let arguments = self.customConfigurationArguments else { return false }
//    return arguments.count == 1 && arguments.first?.label?.text == label
//  }
//
//  func includesArgument(_ label: String) -> Bool {
//    guard let arguments = self.customConfigurationArguments else { return false }
//    return arguments.first(where: { $0.label?.text == label }) != nil
//  }
//}
//
//extension LabeledExprListSyntax {
//  func firstWhereLabel(_ label: String) -> Element? {
//    first(where: { $0.label?.text == label })
//  }
//}
//
//extension AttributeSyntax {
//  var isInitWrapper: Bool {
//    self.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "InitWrapper"
//  }
//}
//
//func deprecationDiagnostics(
//  node: AttributeSyntax,
//  declaration decl: some DeclGroupSyntax
//) -> [Diagnostic] {
//  return diagnoseDotEscaping(decl)
//}
//
//private func diagnoseDotEscaping<D: DeclGroupSyntax>(_ decl: D) -> [Diagnostic] {
//  guard let decl = decl.as(StructDeclSyntax.self) else { return [] }
//
//  return decl.memberBlock.members.compactMap { element -> Diagnostic? in
//    guard
//      let configuration = element.decl
//        .as(VariableDeclSyntax.self)?
//        .customConfigurationArguments
//    else { return nil }
//
//    let dotEscapingIndex = configuration.firstIndex(
//      where: {
//        $0.expression
//          .as(MemberAccessExprSyntax.self)?
//          .declName.baseName.text == "escaping"
//      }
//    )
//    guard let dotEscapingIndex else { return nil }
//
//    let newIndex =
//      configuration.firstIndex(where: { $0.label?.text == "label" })
//      .map { configuration.index(before: $0) }
//      ?? configuration.endIndex
//
//    let newEscaping = LabeledExprSyntax(
//      label: .identifier("escaping"),
//      colon: .colonToken(trailingTrivia: .space),
//      expression: BooleanLiteralExprSyntax(booleanLiteral: true),
//      trailingComma: newIndex != configuration.endIndex ? .commaToken(trailingTrivia: .space) : nil
//    )
//
//    var newConfiguration = configuration
//    newConfiguration.remove(at: dotEscapingIndex)
//    newConfiguration.insert(newEscaping, at: newIndex)
//
//    return Diagnostic(
//      node: configuration,
//      message: MacroExpansionWarningMessage(
//        """
//        @Init(.escaping) is deprecated
//        """
//      ),
//      fixIt: FixIt(
//        message: MacroExpansionFixItMessage(
//          "Replace '@Init(.escaping)' with '@Init(escaping: true)'"
//        ),
//        changes: [
//          FixIt.Change.replace(
//            oldNode: Syntax(configuration),
//            newNode: Syntax(newConfiguration)
//          )
//        ]
//      )
//    )
//  }
//}
//
//// MARK: - Diagnose VariableDeclSyntax
//
//func diagnoseMultipleConfigurations(variable: VariableDeclSyntax) -> [Diagnostic]? {
//  guard variable.customConfigurationAttributes.count > 1 else { return nil }
//
//  return variable.customConfigurationAttributes.dropFirst().map { attribute in
//    Diagnostic(
//      node: attribute,
//      message: MacroExpansionErrorMessage(
//        "Multiple @Init configurations are not supported by @MemberwiseInit"
//      )
//    )
//  }
//}
//
//func diagnoseVariableDecl(
//  customSettings: VariableCustomSettings?,
//  variable: VariableDeclSyntax,
//  targetAccessLevel: AccessLevelModifier
//) -> [Diagnostic] {
//  let customSettingsDiagnostics =
//    customSettings.map { settings in
//      if let diagnostic = diagnoseInitOnInitializedLet(customSettings: settings, variable: variable)
//      {
//        return [diagnostic]
//      }
//
//      if let diagnostic = diagnoseMemberModifiers(customSettings: settings, variable: variable) {
//        return [diagnostic]
//      }
//
//      return [
//        diagnoseVariableLabel(customSettings: settings, variable: variable),
//        diagnoseDefaultValueAppliedToMultipleBindings(
//          customSettings: settings,
//          variable: variable
//        )
//          ?? diagnoseDefaultValueAppliedToInitialized(customSettings: settings, variable: variable),
//      ].compactMap { $0 }
//    } ?? [Diagnostic]()
//
//  let accessibilityDiagnostics = [
//    diagnoseAccessibilityLeak(
//      customSettings: customSettings,
//      variable: variable,
//      targetAccessLevel: targetAccessLevel
//    )
//  ].compactMap { $0 }
//
//  return customSettingsDiagnostics + accessibilityDiagnostics
//}
//
//private func diagnoseInitOnInitializedLet(
//  customSettings: VariableCustomSettings,
//  variable: VariableDeclSyntax
//) -> Diagnostic? {
//  guard
//    variable.isLet,
//    variable.isFullyInitialized
//  else { return nil }
//
//  let fixIts = [
//    variable.fixItRemoveCustomInit,
//    variable.fixItRemoveInitializer,
//  ].compactMap { $0 }
//
//  var diagnosticMessage: DiagnosticMessage {
//    let attributeName = customSettings.customAttributeName
//
//    let message = "@\(attributeName) can't be applied to already initialized constant"
//
//    // @InitWrapper and @InitRaw can be errors instead of warnings since they haven't seen release.
//    if attributeName != "Init" {
//      return MacroExpansionErrorMessage(message)
//    }
//    // @Init(default:) hasn't seen release, so any misuses that include "default" can be an error.
//    if variable.includesArgument("default") {
//      return MacroExpansionErrorMessage(message)
//    }
//
//    // TODO: For 1.0, @Init can also be an error
//    // Conservatively, make @Init be a warning to tolerate uses relying on @Init being silently ignored.
//    return MacroExpansionWarningMessage(message)
//  }
//
//  return customSettings.diagnosticOnDefault(diagnosticMessage, fixIts: fixIts)
//}
//
//private func diagnoseMemberModifiers(
//  customSettings: VariableCustomSettings,
//  variable: VariableDeclSyntax
//) -> Diagnostic? {
//  let attributeName = customSettings.customAttributeName
//
//  if let modifier = variable.firstModifierWhere(keyword: .static) {
//    return Diagnostic(
//      node: modifier,
//      message: MacroExpansionWarningMessage(
//        "@\(attributeName) can't be applied to 'static' members"),
//      fixIts: [variable.fixItRemoveCustomInit].compactMap { $0 }
//    )
//  }
//
//  if let modifier = variable.firstModifierWhere(keyword: .lazy) {
//    return Diagnostic(
//      node: modifier,
//      message: MacroExpansionWarningMessage("@\(attributeName) can't be applied to 'lazy' members"),
//      fixIts: [variable.fixItRemoveCustomInit].compactMap { $0 }
//    )
//  }
//
//  return nil
//}
//
//private func diagnoseVariableLabel(
//  customSettings: VariableCustomSettings,
//  variable: VariableDeclSyntax
//) -> Diagnostic? {
//  if let label = customSettings.label,
//    label != "_",
//    variable.bindings.count > 1
//  {
//    return customSettings.diagnosticOnLabel(
//      MacroExpansionErrorMessage("Custom 'label' can't be applied to multiple bindings")
//    )
//  }
//
//  if customSettings.label?.isInvalidSwiftLabel ?? false {
//    return customSettings.diagnosticOnLabelValue(MacroExpansionErrorMessage("Invalid label value"))
//  }
//
//  return nil
//}
//
//private func diagnoseDefaultValueAppliedToMultipleBindings(
//  customSettings: VariableCustomSettings,
//  variable: VariableDeclSyntax
//) -> Diagnostic? {
//  guard
//    let defaultValue = customSettings.defaultValue,
//    variable.bindings.count > 1
//  else { return nil }
//
//  let fixIts = [
//    determineRemoveDefaultFixIt(variable: variable, defaultValue: defaultValue),
//    determineRemoveCustomInitFixIt(variable: variable),
//  ].compactMap { $0 }
//
//  return customSettings.diagnosticOnDefault(
//    MacroExpansionErrorMessage("Custom 'default' can't be applied to multiple bindings"),
//    fixIts: fixIts
//  )
//}
//
//private func diagnoseDefaultValueAppliedToInitialized(
//  customSettings: VariableCustomSettings,
//  variable: VariableDeclSyntax
//) -> Diagnostic? {
//  guard
//    let defaultValue = customSettings.defaultValue,
//    variable.isFullyInitialized
//  else { return nil }
//
//  let fixIts = [
//    determineRemoveDefaultFixIt(variable: variable, defaultValue: defaultValue),
//    determineRemoveCustomInitFixIt(variable: variable),
//    variable.fixItRemoveInitializer,
//  ].compactMap { $0 }
//
//  return customSettings.diagnosticOnDefault(
//    MacroExpansionErrorMessage("Custom 'default' can't be applied to already initialized variable"),
//    fixIts: fixIts
//  )
//}
//
//private func determineRemoveDefaultFixIt(
//  variable: VariableDeclSyntax,
//  defaultValue: String
//) -> FixIt? {
//  let shouldRemoveDefault =
//    variable.isVar
//    && (!variable.hasSoleArgument("default") || variable.hasNonConfigurationAttributes)
//    || variable.bindings.count > 1 && !variable.hasSoleArgument("default")
//
//  return shouldRemoveDefault ? variable.fixItRemoveDefault(defaultValue: defaultValue) : nil
//}
//
//private func determineRemoveCustomInitFixIt(
//  variable: VariableDeclSyntax
//) -> FixIt? {
//  let shouldRemoveCustomInit =
//    !variable.hasNonConfigurationAttributes && variable.hasSoleArgument("default")
//
//  return shouldRemoveCustomInit ? variable.fixItRemoveCustomInit : nil
//}
//
//private func diagnoseAccessibilityLeak(
//  customSettings: VariableCustomSettings?,
//  variable: VariableDeclSyntax,
//  targetAccessLevel: AccessLevelModifier
//) -> Diagnostic? {
//  let effectiveAccessLevel = customSettings?.accessLevel ?? variable.accessLevel
//
//  guard
//    targetAccessLevel > effectiveAccessLevel,
//    !variable.isFullyInitializedLet
//  else { return nil }
//
//  let customAccess = variable.customConfigurationArguments?
//    .first?
//    .expression
//    .as(MemberAccessExprSyntax.self)
//
//  let targetNode =
//    customAccess?._syntaxNode
//    ?? (variable.modifiers.isEmpty ? variable._syntaxNode : variable.modifiers._syntaxNode)
//
//  var fixWithCustomInitAccess: FixIt? {
//    var customAttribute =
//      variable.customConfigurationAttribute ?? AttributeSyntax(stringLiteral: "@Init()")
//
//    var newArguments =
//      customAttribute.arguments?
//      .as(LabeledExprListSyntax.self) ?? LabeledExprListSyntax()
//
//    let argumentExpr = LabeledExprSyntax(
//      label: nil,
//      expression: MemberAccessExprSyntax(name: TokenSyntax(stringLiteral: "\(targetAccessLevel)"))
//    )
//    if customAccess != nil {
//      newArguments = [argumentExpr] + newArguments.dropFirst()
//    } else {
//      newArguments = [argumentExpr] + newArguments
//    }
//    customAttribute.arguments = .argumentList(newArguments)
//
//    let leadingTrivia = variable.leadingTrivia
//    customAttribute.leadingTrivia = leadingTrivia
//
//    var newVariable = variable
//    newVariable.leadingTrivia = .space
//    newVariable.attributes = [.attribute(customAttribute)]
//
//    return FixIt(
//      message: MacroExpansionFixItMessage("Add '\(customAttribute.trimmedDescription)'"),
//      changes: [
//        FixIt.Change.replace(
//          oldNode: Syntax(variable), newNode: Syntax(newVariable)
//        )
//      ]
//    )
//  }
//
//  var fixWithAccessModifier: FixIt? {
//    var newVariable = variable
//
//    newVariable.leadingTrivia = Trivia()
//    newVariable.accessLevelModifiers = [targetAccessLevel]
//
//    var modifier = newVariable.modifiers.first!
//    //    modifier.leadingTrivia = variable.leadingTrivia // TODO: This can include comments that we don't want to move
//    if let lastNewline = variable.leadingTrivia.pieces.lastIndex(where: \.isNewline),
//      variable.leadingTrivia.pieces[lastNewline...].allSatisfy(\.isWhitespace)
//    {
//      modifier.leadingTrivia = Trivia(pieces: variable.leadingTrivia.pieces[lastNewline...])
//    }
//
//    modifier.trailingTrivia = .space
//    newVariable.modifiers = [modifier]
//
//    // `let value = 0` — Add 'public' access level
//    // `private let value = 0` — Replace 'private' access with 'public'
//    // `public private(set) var value = 0` (var not let!)
//    // TODO: @MemberwiseInit(.internal) but `public private(set) var value = 0` should yield `public internal(set) var value = 0`
//
//    let message =
//      if !variable.modifiers.isEmpty {
//        "Replace '\(variable.modifiers.trimmedDescription)' access with '\(targetAccessLevel)'"
//      } else {
//        "Add '\(targetAccessLevel)' access level"
//      }
//
//    return FixIt(
//      message: MacroExpansionFixItMessage(message),
//      changes: [
//        FixIt.Change.replace(
//          oldNode: Syntax(variable), newNode: Syntax(newVariable)
//        )
//      ]
//    )
//  }
//
//  var fixWithCustomInitIgnore: FixIt? {
//    var customAttribute =
//      variable.customConfigurationAttribute ?? AttributeSyntax(stringLiteral: "@Init()")
//
//    var newArguments =
//      customAttribute.arguments?
//      .as(LabeledExprListSyntax.self) ?? LabeledExprListSyntax()
//
//    let argumentExpr = LabeledExprSyntax(
//      label: nil,
//      expression: MemberAccessExprSyntax(name: TokenSyntax(stringLiteral: "ignore"))
//    )
//    newArguments = [argumentExpr]
//    customAttribute.arguments = .argumentList(newArguments)
//
//    let leadingTrivia = variable.leadingTrivia
//    customAttribute.leadingTrivia = leadingTrivia
//
//    var newVariable = variable
//    newVariable.leadingTrivia = .space
//    newVariable.attributes = [.attribute(customAttribute)]
//
//    // TODO: `private var x, y: Int`
//    let message =
//      if variable.isFullyInitialized {
//        "Add '\(customAttribute.trimmedDescription)'"
//      } else {
//        "Add '\(customAttribute.trimmedDescription)' and an initializer"
//      }
//
//    // TODO: it would be more correct to "carry" the type annotation backward
//    newVariable.bindings = PatternBindingListSyntax(
//      newVariable.bindings.map { patternBinding in
//        guard patternBinding.initializer == nil else { return patternBinding }
//
//        var newBinding = patternBinding
//        newBinding.initializer = InitializerClauseSyntax(
//          equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
//          value: EditorPlaceholderExprSyntax(
//            placeholder: TokenSyntax(stringLiteral: "\u{3C}#value#\u{3E}")
//          )
//        )
//
//        // I think it's okay to not add a type annotation. It will only be missing on multiple bindings,
//        // and there are many valid ways to initialize a memeber without a type annotation, especially
//        // while being ignored by MemberwiseInit (literals and full inference from the type system).
//        //        newBinding.typeAnnotation = patternBinding.typeAnnotation
//        //        ?? TypeAnnotationSyntax(
//        //          colon: .colonToken(trailingTrivia: .space),
//        //          type: MissingTypeSyntax(placeholder: TokenSyntax(stringLiteral: "\u{3C}#Type#\u{3E}"))
//        //            .as(TypeSyntax.self)!
//        //        )
//        return newBinding
//      }
//    )
//
//    return FixIt(
//      message: MacroExpansionFixItMessage(message),
//      changes: [
//        FixIt.Change.replace(
//          oldNode: Syntax(variable), newNode: Syntax(newVariable)
//        )
//      ]
//    )
//  }
//
//  // TODO: fix to add/replace `@Init(.[targetAccessLevel])`
//  // TODO: fix to add/change access level modifier to match targetAccessLevel
//  // TODO: fix to add `@Init(.ignore)` and `= <Placeholder>` (if not already assigned)
//  let fixIts: [FixIt] = [
//    fixWithCustomInitAccess,
//    fixWithAccessModifier,
//    fixWithCustomInitIgnore,
//  ].compactMap { $0 }
//
//  return Diagnostic(
//    node: targetNode,
//    message: MacroExpansionErrorMessage(
//      """
//      @MemberwiseInit(.\(targetAccessLevel)) would leak access to '\(effectiveAccessLevel)' property
//      """
//    ),
//    fixIts: fixIts
//  )
//}
//
//// MARK: - Diagnose [PropertyBinding] and [MemberProperty]
//
//func customInitLabelDiagnosticsFor(bindings: [PropertyBinding]) -> [Diagnostic] {
//  var diagnostics: [Diagnostic] = []
//
//  let customLabeledBindings = bindings.filter {
//    $0.variable.customSettings?.label != nil
//  }
//
//  // Diagnose custom label conflicts with another custom label
//  var seenCustomLabels: Set<String> = []
//  for binding in customLabeledBindings {
//    guard
//      let customSettings = binding.variable.customSettings,
//      let label = customSettings.label,
//      label != "_"
//    else { continue }
//    defer { seenCustomLabels.insert(label) }
//    if seenCustomLabels.contains(label) {
//      diagnostics.append(
//        customSettings.diagnosticOnLabelValue(
//          MacroExpansionErrorMessage("Label '\(label)' conflicts with another label")
//        )
//      )
//    }
//  }
//
//  return diagnostics
//}
//
//func customInitLabelDiagnosticsFor(properties: [MemberProperty]) -> [Diagnostic] {
//  var diagnostics: [Diagnostic] = []
//
//  let propertiesByName = Dictionary(grouping: properties, by: { $0.name })
//
//  // Diagnose custom label conflicts with a property
//  for property in properties {
//    guard
//      let propertyCustomSettings = property.customSettings,
//      let label = propertyCustomSettings.label,
//      let duplicates = propertiesByName[label],
//      duplicates.contains(where: { $0 != property })
//    else { continue }
//
//    diagnostics.append(
//      propertyCustomSettings.diagnosticOnLabelValue(
//        MacroExpansionErrorMessage("Label '\(label)' conflicts with a property name")
//      )
//    )
//  }
//
//  return diagnostics
//}
//
//// MARK: Fix-its
//
//extension VariableDeclSyntax {
//  func fixItRemoveDefault(defaultValue: String) -> FixIt? {
//    guard
//      let customAttribute = self.customConfigurationAttribute,
//      let arguments = self.customConfigurationArguments
//    else { return nil }
//
//    var newAttribute = customAttribute
//    let newArguments = arguments.filter { $0.label?.text != "default" }
//    newAttribute.arguments = newArguments.as(AttributeSyntax.Arguments.self)
//    if newArguments.count == 0 {
//      newAttribute.leftParen = nil
//      newAttribute.rightParen = nil
//    }
//
//    return FixIt(
//      message: MacroExpansionFixItMessage("Remove 'default: \(defaultValue)'"),
//      changes: [
//        FixIt.Change.replace(
//          oldNode: Syntax(customAttribute),
//          newNode: Syntax(newAttribute))
//      ]
//    )
//  }
//
//  var fixItRemoveCustomInit: FixIt? {
//    guard let customAttribute = self.customConfigurationAttribute else { return nil }
//
//    let newVariable = AttributeRemover(
//      removingWhere: {
//        ["Init", "InitWrapper", "InitRaw"].contains($0.attributeName.trimmedDescription)
//      }
//    ).rewrite(self)
//
//    return FixIt(
//      message: MacroExpansionFixItMessage("Remove '\(customAttribute.trimmedDescription)'"),
//      changes: [
//        FixIt.Change.replace(
//          oldNode: Syntax(self), newNode: Syntax(newVariable)
//        )
//      ]
//    )
//  }
//
//  var fixItRemoveInitializer: FixIt? {
//    guard
//      self.bindings.count == 1,
//      let firstBinding = self.bindings.first,
//      let firstBindingInitializer = firstBinding.initializer
//    else { return nil }
//
//    var newFirstBinding = firstBinding.with(\.initializer, nil)
//
//    if firstBinding.typeAnnotation == nil {
//      let inferredTypeSyntax = firstBindingInitializer.value.inferredTypeSyntax
//
//      newFirstBinding.typeAnnotation = TypeAnnotationSyntax(
//        colon: .colonToken(trailingTrivia: .space),
//        type: inferredTypeSyntax
//          ?? MissingTypeSyntax(placeholder: TokenSyntax(stringLiteral: "\u{3C}#Type#\u{3E}"))
//          .as(TypeSyntax.self)!
//      )
//      newFirstBinding.pattern = newFirstBinding.pattern.trimmed
//    }
//
//    var newNode = self.detached
//    newNode.bindings = .init(arrayLiteral: newFirstBinding)
//
//    return FixIt(
//      message: MacroExpansionFixItMessage(
//        "Remove '\(firstBindingInitializer.trimmedDescription)'"
//      ),
//      changes: [
//        FixIt.Change.replace(
//          oldNode: Syntax(self), newNode: Syntax(newNode)
//        )
//      ]
//    )
//  }
//}
//
//// Potential future enhancements:
//// - .ternaryExpr having "then" and "else" expressions as inferrable types
//// - Consider: .isExpr, switchExpr, .tryExpr, .closureExpr
//
//extension ExprSyntax {
//  var inferredTypeSyntax: TypeSyntax? {
//    self.inferredType?.typeSyntax
//  }
//}
//
//private indirect enum ExprInferrableType: Equatable, CustomStringConvertible {
//  case array(ExprInferrableType)
//  case arrayTypeInitializer(elementType: String)
//  case `as`(type: String)
//  case bool
//  case closedRange(ExprInferrableType)
//  case dictionary(key: ExprInferrableType, value: ExprInferrableType)
//  case dictionaryTypeInitializer(keyType: String, valueType: String)
//  case double
//  case int
//  case range(ExprInferrableType)
//  case string
//  case tuple([ExprInferrableType])
//
//  var description: String {
//    switch self {
//    case .array(let elementType):
//      return "[\(elementType.description)]"
//
//    case .arrayTypeInitializer(let elementType):
//      return "[\(elementType)]"
//
//    case .as(let type):
//      return type
//
//    case .bool:
//      return "Bool"
//
//    case .closedRange(let containedType):
//      return "ClosedRange<\(containedType.description)>"
//
//    case .dictionary(let keyType, let valueType):
//      // NB: swift-format prefers `[Key: Value]`, but Xcode uses `[Key : Value]`.
//      return "[\(keyType.description): \(valueType.description)]"
//
//    case .dictionaryTypeInitializer(let keyType, let valueType):
//      return "[\(keyType): \(valueType)]"
//
//    case .double:
//      return "Double"
//
//    case .int:
//      return "Int"
//
//    case .range(let containedType):
//      return "Range<\(containedType.description)>"
//
//    case .string:
//      return "String"
//
//    case .tuple(let elementTypes):
//      let typeDescriptions = elementTypes.map(\.description).joined(separator: ", ")
//      return "(\(typeDescriptions))"
//    }
//  }
//
//  var unwrapSingleElementTuple: ExprInferrableType? {
//    guard
//      case let .tuple(elementTypes) = self,
//      elementTypes.count == 1
//    else { return nil }
//    return elementTypes.first
//  }
//
//  var typeSyntax: TypeSyntax {
//    TypeSyntax(stringLiteral: self.description)
//  }
//}
//
//enum InfixOperator {
//  enum ArithmeticOperator: String {
//    case addition = "+"
//    case subtraction = "-"
//    case multiplication = "*"
//    case division = "/"
//    case modulo = "%"
//  }
//
//  enum BitwiseOperator: String {
//    case bitwiseAnd = "&"
//    case bitwiseOr = "|"
//    case bitwiseXor = "^"
//    case bitwiseShiftLeft = "<<"
//    case bitwiseShiftRight = ">>"
//  }
//
//  enum LogicalOperator: String {
//    case equality = "=="
//    case inequality = "!="
//    case lessThan = "<"
//    case greaterThan = ">"
//    case lessThanOrEqual = "<="
//    case greaterThanOrEqual = ">="
//    case logicalAnd = "&&"
//    case logicalOr = "||"
//  }
//
//  enum RangeOperator: String {
//    case closedRange = "..."
//    case halfOpenRange = "..<"
//  }
//
//  case arithmetic(ArithmeticOperator)
//  case bitwise(BitwiseOperator)
//  case logical(LogicalOperator)
//  case range(RangeOperator)
//
//  init?(rawValue: String) {
//    let type: Self? =
//      if let arithmeticOp = ArithmeticOperator(rawValue: rawValue) {
//        .arithmetic(arithmeticOp)
//      } else if let bitwiseOp = BitwiseOperator(rawValue: rawValue) {
//        .bitwise(bitwiseOp)
//      } else if let logicalOp = LogicalOperator(rawValue: rawValue) {
//        .logical(logicalOp)
//      } else if let rangeOp = RangeOperator(rawValue: rawValue) {
//        .range(rangeOp)
//      } else {
//        nil
//      }
//    guard let type else { return nil }
//    self = type
//  }
//}
//
//extension ExprSyntax {
//  private var inferredType: ExprInferrableType? {
//    switch self.kind {
//    case .arrayExpr:
//      guard let arrayExpr = self.as(ArrayExprSyntax.self) else { return nil }
//
//      let elementTypes = arrayExpr.elements.compactMap { $0.expression.inferredType }
//      guard
//        elementTypes.count == arrayExpr.elements.count,
//        let firstType = elementTypes.first,
//        let inferredArrayType = elementTypes.dropFirst().reduce(firstType, { commonType($0, $1) })
//      else { return nil }
//      return .array(inferredArrayType)
//
//    case .asExpr:
//      guard let asExpr = self.as(AsExprSyntax.self) else { return nil }
//      return .as(type: asExpr.type.trimmedDescription)
//
//    case .booleanLiteralExpr:
//      return .bool
//
//    case .dictionaryExpr:
//      guard let dictionaryExpr = self.as(DictionaryExprSyntax.self) else { return nil }
//
//      let keyValuePairs =
//        dictionaryExpr.content
//        .as(DictionaryElementListSyntax.self)?
//        .compactMap { ($0.key.inferredType, $0.value.inferredType) }
//        ?? []
//
//      guard !keyValuePairs.isEmpty else { return nil }
//
//      let initialKeyTypes = keyValuePairs.map(\.0)
//      let initialValueTypes = keyValuePairs.map(\.1)
//
//      guard
//        let firstKeyType = initialKeyTypes.first,
//        let firstValueType = initialValueTypes.first,
//        let inferredKeyType = initialKeyTypes.dropFirst().reduce(
//          firstKeyType, { commonType($0, $1) }),
//        let inferredValueType = initialValueTypes.dropFirst().reduce(
//          firstValueType, { commonType($0, $1) })
//      else { return nil }
//
//      return .dictionary(key: inferredKeyType, value: inferredValueType)
//
//    case .floatLiteralExpr:
//      return .double
//
//    case .functionCallExpr:
//      guard let functionCallExpr = self.as(FunctionCallExprSyntax.self) else { return nil }
//
//      // NB: `[Type]()`
//      if let arrayExpr = functionCallExpr.calledExpression.as(ArrayExprSyntax.self) {
//        let typeString = arrayExpr.elements
//          .first?
//          .expression
//          .as(DeclReferenceExprSyntax.self)?
//          .baseName
//          .trimmedDescription
//        guard let typeString else { return nil }
//        return .arrayTypeInitializer(elementType: typeString)
//      }
//
//      // NB: `[KeyType : ValueType]()`
//      if let dictionaryExpr = functionCallExpr.calledExpression.as(DictionaryExprSyntax.self) {
//        guard let type = dictionaryExpr.content.as(DictionaryElementListSyntax.self)?.first
//        else { return nil }
//
//        return .dictionaryTypeInitializer(
//          keyType: type.key.trimmedDescription,
//          valueType: type.value.trimmedDescription
//        )
//      }
//
//      return nil
//
//    case .infixOperatorExpr:
//      guard
//        let infixOperatorExpr = self.as(InfixOperatorExprSyntax.self),
//        let lhsType = infixOperatorExpr.leftOperand.as(ExprSyntax.self)?.inferredType,
//        let rhsType = infixOperatorExpr.rightOperand.as(ExprSyntax.self)?.inferredType,
//        let operation = InfixOperator(rawValue: infixOperatorExpr.operator.trimmedDescription),
//        let inferredType = resultTypeOfInfixOperation(
//          lhs: lhsType,
//          rhs: rhsType,
//          operation: operation
//        )
//      else { return nil }
//      return inferredType
//
//    case .integerLiteralExpr:
//      return .int
//
//    case .prefixOperatorExpr:
//      guard
//        let prefixOperatorExpr = self.as(PrefixOperatorExprSyntax.self)
//      else { return nil }
//      return prefixOperatorExpr.expression.inferredType
//
//    case .sequenceExpr:
//      // NB: SwiftSyntax 509.0.2 represents `1 + 2 + 3` as a tree of InfixOperatorExprSyntax
//      // values, but Swift 5.9.0 represents it as SequenceExprSyntax.
//      guard
//        let sequenceExpr = self.as(SequenceExprSyntax.self),
//        let foldedExpr = try? OperatorTable.standardOperators.foldSingle(sequenceExpr)
//      else { return nil }
//      return foldedExpr.inferredType
//
//    case .stringLiteralExpr, .simpleStringLiteralExpr, .simpleStringLiteralSegmentList,
//      .stringLiteralSegmentList:
//      return .string
//
//    case .tupleExpr:
//      guard let tupleExpr = self.as(TupleExprSyntax.self) else { return nil }
//      let elementTypes = tupleExpr.elements.compactMap { $0.expression.inferredType }
//      guard elementTypes.count == tupleExpr.elements.count
//      else { return nil }
//      return .tuple(elementTypes)
//
//    case .token, .accessorBlock, .accessorDeclList, .accessorDecl, .accessorEffectSpecifiers,
//      .accessorParameters, .actorDecl, .arrayElementList, .arrayElement, .arrayType, .arrowExpr,
//      .assignmentExpr, .associatedTypeDecl, .attributeList, .attribute, .attributedType,
//      .availabilityArgumentList, .availabilityArgument, .availabilityCondition,
//      .availabilityLabeledArgument, .awaitExpr, .backDeployedAttributeArguments,
//      .binaryOperatorExpr, .borrowExpr, .breakStmt, .canImportExpr, .canImportVersionInfo,
//      .catchClauseList, .catchClause, .catchItemList, .catchItem, .classDecl, .classRestrictionType,
//      .closureCaptureClause, .closureCaptureList, .closureCaptureSpecifier, .closureCapture,
//      .closureExpr, .closureParameterClause, .closureParameterList, .closureParameter,
//      .closureShorthandParameterList, .closureShorthandParameter, .closureSignature,
//      .codeBlockItemList, .codeBlockItem, .codeBlock, .compositionTypeElementList,
//      .compositionTypeElement, .compositionType, .conditionElementList, .conditionElement,
//      .conformanceRequirement, .consumeExpr, .continueStmt, .conventionAttributeArguments,
//      .conventionWitnessMethodAttributeArguments, .copyExpr, .declModifierDetail, .declModifierList,
//      .declModifier, .declNameArgumentList, .declNameArgument, .declNameArguments,
//      .declReferenceExpr, .deferStmt, .deinitializerDecl, .deinitializerEffectSpecifiers,
//      .derivativeAttributeArguments, .designatedTypeList, .designatedType, .dictionaryElementList,
//      .dictionaryElement, .dictionaryType, .differentiabilityArgumentList,
//      .differentiabilityArgument, .differentiabilityArguments,
//      .differentiabilityWithRespectToArgument, .differentiableAttributeArguments,
//      .discardAssignmentExpr, .discardStmt, .doStmt, .documentationAttributeArgumentList,
//      .documentationAttributeArgument, .dynamicReplacementAttributeArguments,
//      .editorPlaceholderDecl, .editorPlaceholderExpr, .effectsAttributeArgumentList, .enumCaseDecl,
//      .enumCaseElementList, .enumCaseElement, .enumCaseParameterClause, .enumCaseParameterList,
//      .enumCaseParameter, .enumDecl, .exposeAttributeArguments, .exprList, .expressionPattern,
//      .expressionSegment, .expressionStmt, .extensionDecl, .fallThroughStmt, .forStmt,
//      .forceUnwrapExpr, .functionDecl, .functionEffectSpecifiers, .functionParameterClause,
//      .functionParameterList, .functionParameter, .functionSignature, .functionType,
//      .genericArgumentClause, .genericArgumentList, .genericArgument, .genericParameterClause,
//      .genericParameterList, .genericParameter, .genericRequirementList, .genericRequirement,
//      .genericSpecializationExpr, .genericWhereClause, .guardStmt, .identifierPattern,
//      .identifierType, .ifConfigClauseList, .ifConfigClause, .ifConfigDecl, .ifExpr,
//      .implementsAttributeArguments, .implicitlyUnwrappedOptionalType, .importDecl,
//      .importPathComponentList, .importPathComponent, .inOutExpr, .inheritanceClause,
//      .inheritedTypeList, .inheritedType, .initializerClause, .initializerDecl, .isExpr,
//      .isTypePattern, .keyPathComponentList, .keyPathComponent, .keyPathExpr,
//      .keyPathOptionalComponent, .keyPathPropertyComponent, .keyPathSubscriptComponent,
//      .labeledExprList, .labeledExpr, .labeledSpecializeArgument, .labeledStmt, .layoutRequirement,
//      .macroDecl, .macroExpansionDecl, .macroExpansionExpr, .matchingPatternCondition,
//      .memberAccessExpr, .memberBlockItemList, .memberBlockItem, .memberBlock, .memberType,
//      .metatypeType, .missingDecl, .missingExpr, .missingPattern, .missingStmt, .missing,
//      .missingType, .multipleTrailingClosureElementList, .multipleTrailingClosureElement,
//      .namedOpaqueReturnType, .nilLiteralExpr, .objCSelectorPieceList, .objCSelectorPiece,
//      .opaqueReturnTypeOfAttributeArguments, .operatorDecl, .operatorPrecedenceAndTypes,
//      .optionalBindingCondition, .optionalChainingExpr, .optionalType,
//      .originallyDefinedInAttributeArguments, .packElementExpr, .packElementType,
//      .packExpansionExpr, .packExpansionType, .patternBindingList, .patternBinding, .patternExpr,
//      .platformVersionItemList, .platformVersionItem, .platformVersion, .postfixIfConfigExpr,
//      .postfixOperatorExpr, .poundSourceLocationArguments, .poundSourceLocation,
//      .precedenceGroupAssignment, .precedenceGroupAssociativity, .precedenceGroupAttributeList,
//      .precedenceGroupDecl, .precedenceGroupNameList, .precedenceGroupName,
//      .precedenceGroupRelation, .primaryAssociatedTypeClause, .primaryAssociatedTypeList,
//      .primaryAssociatedType, .protocolDecl, .regexLiteralExpr, .repeatStmt, .returnClause,
//      .returnStmt, .sameTypeRequirement, .someOrAnyType, .sourceFile,
//      .specializeAttributeArgumentList, .specializeAvailabilityArgument,
//      .specializeTargetFunctionArgument, .stringSegment, .structDecl, .subscriptCallExpr,
//      .subscriptDecl, .superExpr, .suppressedType, .switchCaseItemList, .switchCaseItem,
//      .switchCaseLabel, .switchCaseList, .switchCase, .switchDefaultLabel, .switchExpr,
//      .ternaryExpr, .throwStmt, .tryExpr, .tuplePatternElementList, .tuplePatternElement,
//      .tuplePattern, .tupleTypeElementList, .tupleTypeElement, .tupleType, .typeAliasDecl,
//      .typeAnnotation, .typeEffectSpecifiers, .typeExpr, .typeInitializerClause,
//      .unavailableFromAsyncAttributeArguments, .underscorePrivateAttributeArguments,
//      .unexpectedNodes, .unresolvedAsExpr, .unresolvedIsExpr, .unresolvedTernaryExpr,
//      .valueBindingPattern, .variableDecl, .versionComponentList, .versionComponent, .versionTuple,
//      .whereClause, .whileStmt, .wildcardPattern, .yieldStmt, .yieldedExpressionList,
//      .yieldedExpression, .yieldedExpressionsClause:
//      return nil
//    }
//  }
//}
//
//private func commonType(
//  _ first: ExprInferrableType?,
//  _ second: ExprInferrableType?
//) -> ExprInferrableType? {
//  guard let firstType = first, let secondType = second else { return nil }
//
//  switch (firstType, secondType) {
//  case (.as(let firstElementType), .as(let secondElementType)):
//    return firstElementType == secondElementType ? firstType : nil
//
//  case (.int, .double), (.double, .int):
//    return .double
//
//  case (.int, .int):
//    return .int
//
//  case (.double, .double):
//    return .double
//
//  case (.string, .string):
//    return .string
//
//  case (.bool, .bool):
//    return .bool
//
//  case (.array(let firstElementType), .array(let secondElementType)):
//    if let commonElementType = commonType(firstElementType, secondElementType) {
//      return .array(commonElementType)
//    }
//
//  case (
//    .dictionary(let firstKeyType, let firstValueType),
//    .dictionary(let secondKeyType, let secondValueType)
//  ):
//    if let commonKeyType = commonType(firstKeyType, secondKeyType),
//      let commonValueType = commonType(firstValueType, secondValueType)
//    {
//      return .dictionary(key: commonKeyType, value: commonValueType)
//    }
//
//  case (.closedRange(let firstContainedType), .closedRange(let secondContainedType)):
//    if let commonContainedType = commonType(firstContainedType, secondContainedType) {
//      return .closedRange(commonContainedType)
//    }
//
//  case (.range(let firstContainedType), .range(let secondContainedType)):
//    if let commonContainedType = commonType(firstContainedType, secondContainedType) {
//      return .range(commonContainedType)
//    }
//
//  default:
//    return nil
//  }
//
//  return nil
//}
//
//private func resultTypeOfInfixOperation(
//  lhs: ExprInferrableType,
//  rhs: ExprInferrableType,
//  operation: InfixOperator
//) -> ExprInferrableType? {
//  let lhsType = lhs.unwrapSingleElementTuple ?? lhs
//  let rhsType = rhs.unwrapSingleElementTuple ?? rhs
//
//  switch operation {
//  case .logical(_):
//    return .bool
//
//  case .arithmetic(let op):
//    switch op {
//    case .addition, .subtraction, .multiplication, .division:
//      return commonType(lhsType, rhsType)
//
//    case .modulo:
//      return (lhsType, rhsType) == (.int, .int) ? .int : nil
//    }
//
//  case .range(let op):
//    guard let type = commonType(lhsType, rhsType) else { return nil }
//    return switch op {
//    case .closedRange:
//      ExprInferrableType.closedRange(type)
//
//    case .halfOpenRange:
//      .range(type)
//    }
//
//  case .bitwise(_):
//    guard (lhsType, rhsType) == (.int, .int) else { return nil }
//    return .int
//  }
//}
//
//struct VariableCustomSettings: Equatable {
//  enum Assignee: Equatable {
//    case wrapper
//    case raw(String)
//  }
//
//  let accessLevel: AccessLevelModifier?
//  let assignee: Assignee?
//  let defaultValue: String?
//  let forceEscaping: Bool
//  let ignore: Bool
//  let label: String?
//  let type: TypeSyntax?
//  let _syntaxNode: AttributeSyntax
//
//  var customAttributeName: String {
//    self._syntaxNode.attributeName.trimmedDescription
//  }
//
//  func diagnosticOnDefault(_ message: DiagnosticMessage, fixIts: [FixIt] = []) -> Diagnostic {
//    let labelNode = self._syntaxNode
//      .arguments?
//      .as(LabeledExprListSyntax.self)?
//      .firstWhereLabel("default")
//
//    return diagnostic(node: labelNode ?? self._syntaxNode, message: message, fixIts: fixIts)
//  }
//
//  func diagnosticOnLabel(_ message: DiagnosticMessage, fixIts: [FixIt] = []) -> Diagnostic {
//    let labelNode = self._syntaxNode
//      .arguments?
//      .as(LabeledExprListSyntax.self)?
//      .firstWhereLabel("label")
//
//    return diagnostic(node: labelNode ?? self._syntaxNode, message: message, fixIts: fixIts)
//  }
//
//  func diagnosticOnLabelValue(_ message: DiagnosticMessage) -> Diagnostic {
//    let labelValueNode = self._syntaxNode
//      .arguments?
//      .as(LabeledExprListSyntax.self)?
//      .firstWhereLabel("label")?
//      .expression
//
//    return diagnostic(node: labelValueNode ?? self._syntaxNode, message: message)
//  }
//
//  private func diagnostic(
//    node: any SyntaxProtocol,
//    message: DiagnosticMessage,
//    fixIts: [FixIt] = []
//  ) -> Diagnostic {
//    Diagnostic(node: node, message: message, fixIts: fixIts)
//  }
//}
//
//struct PropertyBinding {
//  let typeFromTrailingBinding: TypeSyntax?
//  let syntax: PatternBindingSyntax
//  let variable: MemberVariable
//
//  var effectiveType: TypeSyntax? {
//    variable.customSettings?.type
//      ?? self.syntax.typeAnnotation?.type
//      ?? self.syntax.initializer?.value.inferredTypeSyntax
//      ?? self.typeFromTrailingBinding
//  }
//
//  var initializerValue: ExprSyntax? {
//    self.syntax.initializer?.trimmed.value
//  }
//
//  var isTuplePattern: Bool {
//    self.syntax.pattern.isTuplePattern
//  }
//
//  var name: String? {
//    self.syntax.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
//  }
//
//  var isInitializedVarWithoutType: Bool {
//    self.initializerValue != nil
//      && self.variable.keywordToken == .keyword(.var)
//      && self.effectiveType == nil
//      && self.initializerValue?.inferredTypeSyntax == nil
//  }
//
//  var isInitializedLet: Bool {
//    self.initializerValue != nil && self.variable.keywordToken == .keyword(.let)
//  }
//
//  func diagnostic(_ message: DiagnosticMessage) -> Diagnostic {
//    Diagnostic(node: self.syntax._syntaxNode, message: message)
//  }
//}
//
//struct MemberVariable {
//  let customSettings: VariableCustomSettings?
//  let syntax: VariableDeclSyntax
//
//  var accessLevel: AccessLevelModifier {
//    self.syntax.accessLevel
//  }
//
//  var bindings: PatternBindingListSyntax {
//    self.syntax.bindings
//  }
//
//  var keywordToken: TokenKind {
//    self.syntax.bindingSpecifier.tokenKind
//  }
//}
//
//struct MemberProperty: Equatable {
//  let accessLevel: AccessLevelModifier
//  let customSettings: VariableCustomSettings?
//  let initializerValue: ExprSyntax?
//  let keywordToken: TokenKind
//  let name: String
//  let type: TypeSyntax
//
//  func initParameterLabel(
//    considering allProperties: [MemberProperty],
//    deunderscoreParameters: Bool
//  ) -> String {
//    guard
//      let customSettings = self.customSettings,
//      customSettings.label
//        != self.initParameterName(
//          considering: allProperties,
//          deunderscoreParameters: deunderscoreParameters
//        )
//    else { return "" }
//
//    return customSettings.label.map { "\($0) " } ?? ""
//  }
//
//  func initParameterName(
//    considering allProperties: [MemberProperty],
//    deunderscoreParameters: Bool
//  ) -> String {
//    guard
//      self.customSettings?.label == nil,
//      deunderscoreParameters
//    else { return self.name }
//
//    let potentialName = self.name.hasPrefix("_") ? String(name.dropFirst()) : self.name
//    return allProperties.contains(where: { $0.name == potentialName }) ? self.name : potentialName
//  }
//}
//
//extension String {
//  var isValidSwiftLabel: Bool {
//    let pattern = #"^[_a-zA-Z][_a-zA-Z0-9]*$"#
//    let regex = try! NSRegularExpression(pattern: pattern)
//    let range = NSRange(self.startIndex..<self.endIndex, in: self)
//    return regex.firstMatch(in: self, options: [], range: range) != nil
//  }
//}
//
//extension String {
//  var isInvalidSwiftLabel: Bool {
//    !self.isValidSwiftLabel
//  }
//}
//
//extension VariableDeclSyntax {
//  func modifiersExclude(_ keywords: [Keyword]) -> Bool {
//    return !self.modifiers.containsAny(of: keywords.map { TokenSyntax.keyword($0) })
//  }
//
//  func firstModifierWhere(keyword: Keyword) -> DeclModifierSyntax? {
//    let keywordText = TokenSyntax.keyword(keyword).text
//    return self.modifiers.first { modifier in
//      modifier.name.text == keywordText
//    }
//  }
//}
//
//extension DeclModifierListSyntax {
//  fileprivate func containsAny(of tokens: [TokenSyntax]) -> Bool {
//    return self.contains { modifier in
//      tokens.contains { $0.text == modifier.name.text }
//    }
//  }
//}
//
//extension PatternBindingSyntax {
//  var isComputedProperty: Bool {
//    guard let accessors = self.accessorBlock?.accessors else { return false }
//
//    switch accessors {
//    case .accessors(let accessors):
//      let tokenKinds = accessors.compactMap { $0.accessorSpecifier.tokenKind }
//      let propertyObservers: [TokenKind] = [.keyword(.didSet), .keyword(.willSet)]
//
//      return !tokenKinds.allSatisfy(propertyObservers.contains)
//
//    case .getter(_):
//      return true
//    }
//  }
//}
//
//extension TypeSyntax {
//  var isFunctionType: Bool {
//    // NB: Check for `FunctionTypeSyntax` directly or when wrapped within `AttributedTypeSyntax`,
//    // e.g., `@Sendable () -> Void`.
//    return self.is(FunctionTypeSyntax.self)
//      || (self.as(AttributedTypeSyntax.self)?.baseType.is(FunctionTypeSyntax.self) ?? false)
//  }
//}
//
//extension TypeSyntax {
//  var isOptionalType: Bool {
//    self.as(OptionalTypeSyntax.self) != nil
//  }
//}
//
//extension PatternSyntax {
//  var isTuplePattern: Bool {
//    self.as(TuplePatternSyntax.self) != nil
//  }
//}
//
//extension VariableDeclSyntax {
//  var isComputedProperty: Bool {
//    guard
//      self.bindings.count == 1,
//      let binding = self.bindings.first?.as(PatternBindingSyntax.self)
//    else { return false }
//
//    return self.bindingSpecifier.tokenKind == .keyword(.var) && binding.isComputedProperty
//  }
//
//  var isFullyInitialized: Bool {
//    self.bindings.allSatisfy { $0.initializer != nil }
//  }
//
//  var isFullyInitializedLet: Bool {
//    self.isLet && self.isFullyInitialized
//  }
//
//  var isLet: Bool {
//    self.bindingSpecifier.tokenKind == .keyword(.let)
//  }
//
//  var isVar: Bool {
//    self.bindingSpecifier.tokenKind == .keyword(.var)
//  }
//}
//
//extension ExprSyntax {
//  var trimmedStringLiteral: String? {
//    self.as(StringLiteralExprSyntax.self)?
//      .segments
//      .trimmedDescription
//      .trimmingCharacters(in: .whitespacesAndNewlines)
//  }
//}
//
////extension DeclGroupSyntax {
////  func descriptiveDeclKind(withArticle article: Bool = false) -> String {
////    switch self {
////    case is ActorDeclSyntax:
////      return article ? "an actor" : "actor"
////    case is ClassDeclSyntax:
////      return article ? "a class" : "class"
////    case is ExtensionDeclSyntax:
////      return article ? "an extension" : "extension"
////    case is ProtocolDeclSyntax:
////      return article ? "a protocol" : "protocol"
////    case is StructDeclSyntax:
////      return article ? "a struct" : "struct"
////    case is EnumDeclSyntax:
////      return article ? "an enum" : "enum"
////    default:
////      return "`\(self.kind)`"
////    }
////  }
////}
