import SwiftSyntax

// Modified from IanKeen's MacroKit:
// https://github.com/IanKeen/MacroKit/blob/main/Sources/MacroKitMacros/Support/AccessLevelSyntax.swift
//
// Modifications:
// - Declarations can have multiple access level modifiers, e.g. `public private(set)`
//   I'm still not dealing with the "detail" (`set`) in any way
// - Apply Swift's rules concering default access when no access level is explicitly stated (it's not always `internal`):
//   https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol#Custom-Types
// - Added missing DeclGroupSyntax kinds

// TODO: Rules for local DeclGroup's nested within a function definition
// TODO: Rules for local access functions? e.g. `func foo() { func bar() { … } … }`

enum AccessLevelModifier: String, Comparable, CaseIterable, Sendable {
  case `private`
  case `fileprivate`
  case `internal`
  case `public`
  case `open`

  var keyword: Keyword {
    switch self {
    case .private: return .private
    case .fileprivate: return .fileprivate
    case .internal: return .internal
    case .public: return .public
    case .open: return .open
    }
  }

  static func < (lhs: AccessLevelModifier, rhs: AccessLevelModifier) -> Bool {
    let lhs = Self.allCases.firstIndex(of: lhs)!
    let rhs = Self.allCases.firstIndex(of: rhs)!
    return lhs < rhs
  }
}

public protocol AccessLevelSyntax {
  var parent: Syntax? { get }
  var modifiers: DeclModifierListSyntax { get set }
}

extension AccessLevelSyntax {
  var accessLevelModifiers: [AccessLevelModifier]? {
    get {
      let accessLevels = modifiers.lazy.compactMap { AccessLevelModifier(rawValue: $0.name.text) }
      return accessLevels.isEmpty ? nil : Array(accessLevels)
    }
    set {
      guard let newModifiers = newValue else {
        modifiers = []
        return
      }
      let newModifierKeywords = newModifiers.map { DeclModifierSyntax(name: .keyword($0.keyword)) }
      let filteredModifiers = modifiers.filter {
        AccessLevelModifier(rawValue: $0.name.text) == nil
      }
      modifiers = filteredModifiers + newModifierKeywords
    }
  }
}

protocol DeclGroupAccessLevelSyntax: AccessLevelSyntax {
}
extension DeclGroupAccessLevelSyntax {
  public var accessLevel: AccessLevelModifier {
    self.accessLevelModifiers?.first ?? .internal
  }
}

extension ActorDeclSyntax: DeclGroupAccessLevelSyntax {}
extension ClassDeclSyntax: DeclGroupAccessLevelSyntax {}
extension EnumDeclSyntax: DeclGroupAccessLevelSyntax {}
extension StructDeclSyntax: DeclGroupAccessLevelSyntax {}

// NB: MemberwiseInit doesn't need this on FunctionDeclSyntax extension
//extension FunctionDeclSyntax: AccessLevelSyntax {
//  public var accessLevel: AccessLevelModifier {
//    get {
//      // a decl (function, variable) can
//      if let formalModifier = self.accessLevelModifiers?.first {
//        return formalModifier
//      }
//
//      guard let parent = self.parent else { return .internal }
//
//      if let parent = parent as? DeclGroupSyntax {
//        return [parent.declAccessLevel, .internal].min()!
//      } else {
//        return .internal
//      }
//    }
//  }
//}

extension VariableDeclSyntax: AccessLevelSyntax {
  var accessLevel: AccessLevelModifier {
    // TODO: assuming the least access of the modifiers may not be correct, but it suits the special case of MemberwiseInit
    // maybe this is generally okay, since the "set" detail must be given less access than then get? either way, this needs to be made clearer
    self.accessLevelModifiers?.min() ?? inferDefaultAccessLevel(node: self._syntaxNode)
  }
}

private func inferDefaultAccessLevel(node: Syntax?) -> AccessLevelModifier {
  guard let node else { return .internal }
  guard let decl = node.asProtocol(DeclGroupSyntax.self) else {
    return inferDefaultAccessLevel(node: node.parent)
  }

  return [decl.declAccessLevel, .internal].min()!
}

// NB: This extension is sugar to avoid user needing to first cast to a specific kind of decl group syntax
extension DeclGroupSyntax {
  var declAccessLevel: AccessLevelModifier {
    (self as? DeclGroupAccessLevelSyntax)!.accessLevel
  }
}
