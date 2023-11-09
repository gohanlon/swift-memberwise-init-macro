import SwiftSyntax

extension AttributeListSyntax {
  func contains(attributeNamed name: String) -> Bool {
    return self.contains {
      $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == name
    }
  }
}

extension VariableDeclSyntax {
  func modifiersExclude(_ keywords: [Keyword]) -> Bool {
    return !self.modifiers.containsAny(of: keywords.map { TokenSyntax.keyword($0) })
  }
}

extension DeclModifierListSyntax {
  fileprivate func containsAny(of tokens: [TokenSyntax]) -> Bool {
    return self.contains { modifier in
      tokens.contains { $0.text == modifier.name.text }
    }
  }
}

extension PatternBindingSyntax {
  var isComputedProperty: Bool {
    guard let accessors = self.accessorBlock?.accessors else { return false }

    switch accessors {
    case .accessors(let accessors):
      let tokenKinds = accessors.compactMap { $0.accessorSpecifier.tokenKind }
      let propertyObservers: [TokenKind] = [.keyword(.didSet), .keyword(.willSet)]

      return !tokenKinds.allSatisfy(propertyObservers.contains)

    case .getter(_):
      return true
    }
  }
}

// TODO: I've been bitten by a case where SwiftSyntax MacroSystem gives me a result that's different from Xcode/Swift.
// Write a script that extracts all the test cases into a main.swift to test that Xcode can build them.
// Maybe leverage swift-macro-testing?

// TODO: infix expressions need to support nesting, generally need to be rethought in light of type promotion and `commonType`
// TODO: .ternaryExpr having "then" and "else" expressions as inferrable types
// TODO: Consider .isExpr, .prefixOperatorExpr, switchExpr, .tryExpr
// TODO: Maybe .ifExpr where implicit or explicit return type is inferrable?
// TODO: Maybe .closureExpr where return type is inferrable?
// TODO: Maybe .nilCoalescing, but I think no:
// let x2 = Optional(1.0)
// let y2 = x2 ?? 2 // y2 is promoted to `Double`

extension TypeSyntax {
  var isFunctionType: Bool {
    // NB: Check for `FunctionTypeSyntax` directly or when wrapped within `AttributedTypeSyntax`,
    // e.g., `@Sendable () -> Void`.
    return self.is(FunctionTypeSyntax.self)
      || (self.as(AttributedTypeSyntax.self)?.baseType.is(FunctionTypeSyntax.self) ?? false)
  }
}

extension TypeSyntax {
  var isOptionalType: Bool {
    self.as(OptionalTypeSyntax.self) != nil
  }
}

extension PatternSyntax {
  var isTuplePattern: Bool {
    self.as(TuplePatternSyntax.self) != nil
  }
}

private indirect enum ExprInferrableType: Equatable, CustomStringConvertible {
  case array(ExprInferrableType)
  case arrayTypeInitializer(elementType: String)
  case `as`(type: String)
  case bool
  case closedRange(ExprInferrableType)
  case dictionary(key: ExprInferrableType, value: ExprInferrableType)
  case dictionaryTypeInitializer(keyType: String, valueType: String)
  case double
  case int
  case range(ExprInferrableType)
  case string
  case tuple([ExprInferrableType])

  var description: String {
    switch self {

    case .array(let elementType):
      return "[\(elementType.description)]"

    case .arrayTypeInitializer(let elementType):
      return "[\(elementType)]"

    case .as(let type):
      return type

    case .bool:
      return "Bool"

    case .closedRange(let containedType):
      return "ClosedRange<\(containedType.description)>"

    case .dictionary(let keyType, let valueType):
      // NB: swift-format prefers `[Key: Value]`, but Xcode uses `[Key : Value]`.
      return "[\(keyType.description): \(valueType.description)]"

    case .dictionaryTypeInitializer(let keyType, let valueType):
      return "[\(keyType): \(valueType)]"

    case .double:
      return "Double"

    case .int:
      return "Int"

    case .range(let containedType):
      return "Range<\(containedType.description)>"

    case .string:
      return "String"

    case .tuple(let elementTypes):
      let typeDescriptions = elementTypes.map(\.description).joined(separator: ", ")
      return "(\(typeDescriptions))"
    }
  }

  var typeSyntax: TypeSyntax {
    TypeSyntax(stringLiteral: self.description)
  }
}

enum InfixOperator {
  enum ArithmeticOperator: String {
    case addition = "+"
    case subtraction = "-"
    case multiplication = "*"
    case division = "/"
    case modulo = "%"
  }

  enum BitwiseOperator: String {
    case bitwiseAnd = "&"
    case bitwiseOr = "|"
    case bitwiseXor = "^"
    case bitwiseShiftLeft = "<<"
    case bitwiseShiftRight = ">>"
  }

  enum LogicalOperator: String {
    case equality = "=="
    case inequality = "!="
    case lessThan = "<"
    case greaterThan = ">"
    case lessThanOrEqual = "<="
    case greaterThanOrEqual = ">="
    case logicalAnd = "&&"
    case logicalOr = "||"
  }

  enum RangeOperator: String {
    case closedRange = "..."
    case halfOpenRange = "..<"
  }

  case arithmetic(ArithmeticOperator)
  case bitwise(BitwiseOperator)
  case logical(LogicalOperator)
  case range(RangeOperator)

  init?(rawValue: String) {
    let type: Self? =
      if let arithmeticOp = ArithmeticOperator(rawValue: rawValue) {
        .arithmetic(arithmeticOp)
      } else if let bitwiseOp = BitwiseOperator(rawValue: rawValue) {
        .bitwise(bitwiseOp)
      } else if let logicalOp = LogicalOperator(rawValue: rawValue) {
        .logical(logicalOp)
      } else if let rangeOp = RangeOperator(rawValue: rawValue) {
        .range(rangeOp)
      } else {
        nil
      }
    guard let type else { return nil }
    self = type
  }
}

extension ExprSyntax {
  var inferredTypeSyntax: TypeSyntax? {
    self.inferredType?.typeSyntax
  }

  private var inferredType: ExprInferrableType? {
    switch self.kind {
    case .arrayExpr:
      guard let arrayExpr = self.as(ArrayExprSyntax.self) else { return nil }

      let elementTypes = arrayExpr.elements.compactMap { $0.expression.inferredType }
      guard
        elementTypes.count == arrayExpr.elements.count,
        let firstType = elementTypes.first,
        let inferredArrayType = elementTypes.dropFirst().reduce(firstType, { commonType($0, $1) })
      else { return nil }
      return .array(inferredArrayType)

    case .asExpr:
      guard let asExpr = self.as(AsExprSyntax.self) else { return nil }
      return .as(type: asExpr.type.trimmedDescription)

    case .booleanLiteralExpr:
      return .bool

    case .dictionaryExpr:
      guard let dictionaryExpr = self.as(DictionaryExprSyntax.self) else { return nil }

      let keyValuePairs =
        dictionaryExpr.content
        .as(DictionaryElementListSyntax.self)?
        .compactMap { ($0.key.inferredType, $0.value.inferredType) }
        ?? []

      guard !keyValuePairs.isEmpty else { return nil }

      let initialKeyTypes = keyValuePairs.map(\.0)
      let initialValueTypes = keyValuePairs.map(\.1)

      guard
        let firstKeyType = initialKeyTypes.first,
        let firstValueType = initialValueTypes.first,
        let inferredKeyType = initialKeyTypes.dropFirst().reduce(
          firstKeyType, { commonType($0, $1) }),
        let inferredValueType = initialValueTypes.dropFirst().reduce(
          firstValueType, { commonType($0, $1) })
      else { return nil }

      return .dictionary(key: inferredKeyType, value: inferredValueType)

    case .floatLiteralExpr:
      return .double

    case .functionCallExpr:
      guard let functionCallExpr = self.as(FunctionCallExprSyntax.self) else { return nil }

      // NB: `[Type]()`
      if let arrayExpr = functionCallExpr.calledExpression.as(ArrayExprSyntax.self) {
        let typeString = arrayExpr.elements
          .first?
          .expression
          .as(DeclReferenceExprSyntax.self)?
          .baseName
          .trimmedDescription
        guard let typeString else { return nil }
        return .arrayTypeInitializer(elementType: typeString)
      }

      // NB: `[KeyType : ValueType]()`
      if let dictionaryExpr = functionCallExpr.calledExpression.as(DictionaryExprSyntax.self) {
        guard let type = dictionaryExpr.content.as(DictionaryElementListSyntax.self)?.first
        else { return nil }

        return .dictionaryTypeInitializer(
          keyType: type.key.trimmedDescription,
          valueType: type.value.trimmedDescription
        )
      }

      return nil

    case .infixOperatorExpr:
      guard
        let infixOperatorExpr = self.as(InfixOperatorExprSyntax.self),
        let lhsType = infixOperatorExpr.leftOperand.as(ExprSyntax.self)?.inferredType,
        let rhsType = infixOperatorExpr.rightOperand.as(ExprSyntax.self)?.inferredType,
        let operation = InfixOperator(rawValue: infixOperatorExpr.operator.trimmedDescription),
        let inferredType = resultTypeOfInfixOperation(
          lhs: lhsType,
          rhs: rhsType,
          operation: operation
        )
      else { return nil }
      return inferredType

    case .integerLiteralExpr:
      return .int

    case .stringLiteralExpr, .simpleStringLiteralExpr, .simpleStringLiteralSegmentList,
      .stringLiteralSegmentList:
      return .string

    case .tupleExpr:
      guard let tupleExpr = self.as(TupleExprSyntax.self) else { return nil }
      let elementTypes = tupleExpr.elements.compactMap { $0.expression.inferredType }
      guard elementTypes.count == tupleExpr.elements.count
      else { return nil }
      return .tuple(elementTypes)

    case .token, .accessorBlock, .accessorDeclList, .accessorDecl, .accessorEffectSpecifiers,
      .accessorParameters, .actorDecl, .arrayElementList, .arrayElement, .arrayType, .arrowExpr,
      .assignmentExpr, .associatedTypeDecl, .attributeList, .attribute, .attributedType,
      .availabilityArgumentList, .availabilityArgument, .availabilityCondition,
      .availabilityLabeledArgument, .awaitExpr, .backDeployedAttributeArguments,
      .binaryOperatorExpr, .borrowExpr, .breakStmt, .canImportExpr, .canImportVersionInfo,
      .catchClauseList, .catchClause, .catchItemList, .catchItem, .classDecl, .classRestrictionType,
      .closureCaptureClause, .closureCaptureList, .closureCaptureSpecifier, .closureCapture,
      .closureExpr, .closureParameterClause, .closureParameterList, .closureParameter,
      .closureShorthandParameterList, .closureShorthandParameter, .closureSignature,
      .codeBlockItemList, .codeBlockItem, .codeBlock, .compositionTypeElementList,
      .compositionTypeElement, .compositionType, .conditionElementList, .conditionElement,
      .conformanceRequirement, .consumeExpr, .continueStmt, .conventionAttributeArguments,
      .conventionWitnessMethodAttributeArguments, .copyExpr, .declModifierDetail, .declModifierList,
      .declModifier, .declNameArgumentList, .declNameArgument, .declNameArguments,
      .declReferenceExpr, .deferStmt, .deinitializerDecl, .deinitializerEffectSpecifiers,
      .derivativeAttributeArguments, .designatedTypeList, .designatedType, .dictionaryElementList,
      .dictionaryElement, .dictionaryType, .differentiabilityArgumentList,
      .differentiabilityArgument, .differentiabilityArguments,
      .differentiabilityWithRespectToArgument, .differentiableAttributeArguments,
      .discardAssignmentExpr, .discardStmt, .doStmt, .documentationAttributeArgumentList,
      .documentationAttributeArgument, .dynamicReplacementAttributeArguments,
      .editorPlaceholderDecl, .editorPlaceholderExpr, .effectsAttributeArgumentList, .enumCaseDecl,
      .enumCaseElementList, .enumCaseElement, .enumCaseParameterClause, .enumCaseParameterList,
      .enumCaseParameter, .enumDecl, .exposeAttributeArguments, .exprList, .expressionPattern,
      .expressionSegment, .expressionStmt, .extensionDecl, .fallThroughStmt, .forStmt,
      .forceUnwrapExpr, .functionDecl, .functionEffectSpecifiers, .functionParameterClause,
      .functionParameterList, .functionParameter, .functionSignature, .functionType,
      .genericArgumentClause, .genericArgumentList, .genericArgument, .genericParameterClause,
      .genericParameterList, .genericParameter, .genericRequirementList, .genericRequirement,
      .genericSpecializationExpr, .genericWhereClause, .guardStmt, .identifierPattern,
      .identifierType, .ifConfigClauseList, .ifConfigClause, .ifConfigDecl, .ifExpr,
      .implementsAttributeArguments, .implicitlyUnwrappedOptionalType, .importDecl,
      .importPathComponentList, .importPathComponent, .inOutExpr, .inheritanceClause,
      .inheritedTypeList, .inheritedType, .initializerClause, .initializerDecl, .isExpr,
      .isTypePattern, .keyPathComponentList, .keyPathComponent, .keyPathExpr,
      .keyPathOptionalComponent, .keyPathPropertyComponent, .keyPathSubscriptComponent,
      .labeledExprList, .labeledExpr, .labeledSpecializeArgument, .labeledStmt, .layoutRequirement,
      .macroDecl, .macroExpansionDecl, .macroExpansionExpr, .matchingPatternCondition,
      .memberAccessExpr, .memberBlockItemList, .memberBlockItem, .memberBlock, .memberType,
      .metatypeType, .missingDecl, .missingExpr, .missingPattern, .missingStmt, .missing,
      .missingType, .multipleTrailingClosureElementList, .multipleTrailingClosureElement,
      .namedOpaqueReturnType, .nilLiteralExpr, .objCSelectorPieceList, .objCSelectorPiece,
      .opaqueReturnTypeOfAttributeArguments, .operatorDecl, .operatorPrecedenceAndTypes,
      .optionalBindingCondition, .optionalChainingExpr, .optionalType,
      .originallyDefinedInAttributeArguments, .packElementExpr, .packElementType,
      .packExpansionExpr, .packExpansionType, .patternBindingList, .patternBinding, .patternExpr,
      .platformVersionItemList, .platformVersionItem, .platformVersion, .postfixIfConfigExpr,
      .postfixOperatorExpr, .poundSourceLocationArguments, .poundSourceLocation,
      .precedenceGroupAssignment, .precedenceGroupAssociativity, .precedenceGroupAttributeList,
      .precedenceGroupDecl, .precedenceGroupNameList, .precedenceGroupName,
      .precedenceGroupRelation, .prefixOperatorExpr, .primaryAssociatedTypeClause,
      .primaryAssociatedTypeList, .primaryAssociatedType, .protocolDecl, .regexLiteralExpr,
      .repeatStmt, .returnClause, .returnStmt, .sameTypeRequirement, .sequenceExpr, .someOrAnyType,
      .sourceFile, .specializeAttributeArgumentList, .specializeAvailabilityArgument,
      .specializeTargetFunctionArgument, .stringSegment, .structDecl, .subscriptCallExpr,
      .subscriptDecl, .superExpr, .suppressedType, .switchCaseItemList, .switchCaseItem,
      .switchCaseLabel, .switchCaseList, .switchCase, .switchDefaultLabel, .switchExpr,
      .ternaryExpr, .throwStmt, .tryExpr, .tuplePatternElementList, .tuplePatternElement,
      .tuplePattern, .tupleTypeElementList, .tupleTypeElement, .tupleType, .typeAliasDecl,
      .typeAnnotation, .typeEffectSpecifiers, .typeExpr, .typeInitializerClause,
      .unavailableFromAsyncAttributeArguments, .underscorePrivateAttributeArguments,
      .unexpectedNodes, .unresolvedAsExpr, .unresolvedIsExpr, .unresolvedTernaryExpr,
      .valueBindingPattern, .variableDecl, .versionComponentList, .versionComponent, .versionTuple,
      .whereClause, .whileStmt, .wildcardPattern, .yieldStmt, .yieldedExpressionList,
      .yieldedExpression, .yieldedExpressionsClause:
      return nil
    }
  }
}

private func commonType(
  _ first: ExprInferrableType?,
  _ second: ExprInferrableType?
) -> ExprInferrableType? {
  guard let firstType = first, let secondType = second else { return nil }

  switch (firstType, secondType) {
  case (.as(let firstElementType), .as(let secondElementType)):
    return firstElementType == secondElementType ? firstType : nil

  case (.int, .double), (.double, .int):
    return .double

  case (.int, .int):
    return .int

  case (.double, .double):
    return .double

  case (.string, .string):
    return .string

  case (.bool, .bool):
    return .bool

  case (.array(let firstElementType), .array(let secondElementType)):
    if let commonElementType = commonType(firstElementType, secondElementType) {
      return .array(commonElementType)
    }

  case (
    .dictionary(let firstKeyType, let firstValueType),
    .dictionary(let secondKeyType, let secondValueType)
  ):
    if let commonKeyType = commonType(firstKeyType, secondKeyType),
      let commonValueType = commonType(firstValueType, secondValueType)
    {
      return .dictionary(key: commonKeyType, value: commonValueType)
    }

  case (.closedRange(let firstContainedType), .closedRange(let secondContainedType)):
    if let commonContainedType = commonType(firstContainedType, secondContainedType) {
      return .closedRange(commonContainedType)
    }

  case (.range(let firstContainedType), .range(let secondContainedType)):
    if let commonContainedType = commonType(firstContainedType, secondContainedType) {
      return .range(commonContainedType)
    }

  default:
    return nil
  }

  return nil
}

private func resultTypeOfInfixOperation(
  lhs: ExprInferrableType,
  rhs: ExprInferrableType,
  operation: InfixOperator
) -> ExprInferrableType? {
  switch operation {
  case .logical(_):
    return .bool

  case .arithmetic(let op):
    switch op {
    case .addition, .subtraction, .multiplication, .division:
      return commonType(lhs, rhs)

    case .modulo:
      return (lhs, rhs) == (.int, .int) ? .int : nil
    }

  case .range(let op):
    guard let type = commonType(lhs, rhs) else { return nil }
    return switch op {
    case .closedRange:
      ExprInferrableType.closedRange(type)

    case .halfOpenRange:
      .range(type)
    }

  case .bitwise(_):
    guard lhs == .int && rhs == .int else { return nil }
    return .int
  }
}
