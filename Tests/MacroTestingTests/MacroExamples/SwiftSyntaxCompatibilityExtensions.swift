import SwiftSyntax
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax510) && canImport(SwiftSyntax509)
  extension FreestandingMacroExpansionSyntax {
    var arguments: LabeledExprListSyntax {
      get { self.argumentList }
      set { self.argumentList = newValue }
    }
  }
#endif
