//// Come back and check this work after two PRs land or are otherwise resolved:
//// - Update FixItApplier
//// - Multi-FixIt support
//
//import MacroTesting
//import SwiftDiagnostics
//import SwiftSyntax
//import SwiftSyntaxBuilder
//import SwiftSyntaxMacros
//import SwiftSyntaxMacrosTestSupport
//import XCTest
//
//private struct Index {
//  private static var index = 0
//
//  static var next: Int {
//    defer { index += 1 }
//    return index
//  }
//}
//
//extension Diagnostic {
//  fileprivate static func error(on node: AttributeSyntax, fixIts: [FixIt] = []) -> Self {
//    let index = Index.next
//    return Diagnostic(
//      node: node.attributeName,
//      message: SimpleDiagnosticMessage(
//        message: "This is an error diagnostic (#\(index)).",
//        diagnosticID: MessageID(domain: "domain", id: "diagnostic\(index)"),
//        severity: .error
//      ),
//      fixIts: fixIts
//    )
//  }
//
//  fileprivate static func note(on node: AttributeSyntax) -> Self {
//    let index = Index.next
//    return Diagnostic(
//      node: node.attributeName,
//      message: SimpleDiagnosticMessage(
//        message: "This is a note diagnostic (#\(index)).",
//        diagnosticID: MessageID(domain: "domain", id: "diagnostic(#\(index)"),
//        severity: .note
//      )
//    )
//  }
//
//  fileprivate static func warning(on node: AttributeSyntax, fixIts: [FixIt] = []) -> Self {
//    let index = Index.next
//    return Diagnostic(
//      node: node.attributeName,
//      message: SimpleDiagnosticMessage(
//        message: "This is a warning diagnostic (#\(index)).",
//        diagnosticID: MessageID(domain: "domain", id: "diagnostic\(index)"),
//        severity: .warning
//      ),
//      fixIts: fixIts
//    )
//  }
//
//}
//
//extension FixIt {
//  fileprivate static func error(on node: Syntax) -> Self {
//    let index = Index.next
//    return FixIt(
//      message: SimpleDiagnosticMessage(
//        message: "This is a fix-it (#\(index)).",
//        diagnosticID: MessageID(domain: "domain", id: "fixit#\(index)"),
//        severity: .error
//      ),
//      changes: [
//        .replace(oldNode: Syntax(node), newNode: Syntax(node))  // no-op
//      ]
//    )
//  }
//
//  fileprivate static func error(on node: SyntaxProtocol) -> Self {
//    error(on: Syntax(node))
//  }
//}
//
//final class DiagnosticTests: XCTestCase {
//  func testDiagnosticFixit() {
//    enum TestMacro: MemberMacro {
//      public static func expansion(
//        of node: AttributeSyntax,
//        providingMembersOf declaration: some DeclGroupSyntax,
//        in context: some MacroExpansionContext
//      ) throws -> [DeclSyntax] {
//        context.diagnose(
//          .error(
//            on: node,
//            fixIts: [.error(on: node)]  // 👈 will crash with a fixit
//            //            fixIts: [.error(on: declaration)]  // 👈 also crashes
//          )
//        )
//
//        return []
//      }
//    }
//
//    // 🛑 🛑 🛑 When given an "expansion" and macro emits a fixit, `assertMacro` will crash.
//    assertMacro([TestMacro.self]) {
//      """
//      @Test
//      struct S {}
//      """
//    } expansion: {
//      """
//      struct S {}
//      """
//    }
//  }
//
//  func testDiagnosticFixit2() {
//    enum TestMacro: MemberMacro {
//      public static func expansion(
//        of node: AttributeSyntax,
//        providingMembersOf declaration: some DeclGroupSyntax,
//        in context: some MacroExpansionContext
//      ) throws -> [DeclSyntax] {
//        context.diagnose(
//          .error(
//            on: node,
//            fixIts: [.error(on: node)]  // 👈 fixit
//          )
//        )
//
//        return []
//      }
//    }
//
//    // 🛑 `assertMacro` expands with a blank "expansion" string instead of containing "struct S {}".
//    assertMacro([TestMacro.self]) {
//      """
//      @Test
//      struct S {}
//      """
//      //    } diagnostics: {
//      //      """
//      //      @Test
//      //       ┬───
//      //       ╰─ 🛑 This is an error diagnostic (#1).
//      //          ✏️ This is a fix-it (#0).
//      //      struct S {}
//      //      """
//      //    } fixes: {
//      //      """
//      //      @Test
//      //      """
//      //    } expansion: {
//      //      """
//      //
//      //      """
//    }
//  }
//
//  func testDiagnosticFixitNote() {
//    enum TestMacro: MemberMacro {
//      public static func expansion(
//        of node: AttributeSyntax,
//        providingMembersOf declaration: some DeclGroupSyntax,
//        in context: some MacroExpansionContext
//      ) throws -> [DeclSyntax] {
//        context.diagnose(
//          .error(
//            on: node,
//            fixIts: [.error(on: node)]  // 👈 fixit
//          )
//        )
//        context.diagnose(
//          .note(on: node)  // 👈 note
//        )
//
//        return []
//      }
//    }
//
//    // `assertMacro` expands with just "diagnostics", omitting "fixes" and "expansion".
//    assertMacro([TestMacro.self]) {
//      """
//      @Test
//      struct S {}
//      """
//      //    } diagnostics: {
//      //      """
//      //      @Test
//      //       ┬───
//      //       ├─ 🛑 This is an error diagnostic (#1).
//      //       │  ✏️ This is a fix-it (#0).
//      //       ╰─ ℹ️ This is a note diagnostic (#2).
//      //      struct S {}
//      //      """
//    }
//  }
//
//  // This test match the emissions of `DiagnosticsAndFixitsEmitterMacro`, and demonstrates
//  // that `assertMacro` behaves the same with this test setup.
//  func testMirrorDiagnosticsAndFixitsEmitterMacro() {
//    enum TestMacro: MemberMacro {
//      public static func expansion(
//        of node: AttributeSyntax,
//        providingMembersOf declaration: some DeclGroupSyntax,
//        in context: some MacroExpansionContext
//      ) throws -> [DeclSyntax] {
//        context.diagnose(
//          .warning(  // change this to `.error` to only get "diagnostics" instead of "diagnostics" and "expansion". Either way, no "fixes".
//            on: node,
//            fixIts: [
//              .error(on: node),
//              .error(on: node),
//            ]
//          )
//        )
//        context.diagnose(
//          .note(on: node)
//        )
//
//        return []
//      }
//    }
//
//    assertMacro([TestMacro.self]) {
//      """
//      @Test
//      struct S {}
//      """
//      //    } diagnostics: {
//      //      """
//      //      @Test
//      //       ┬───
//      //       ├─ ⚠️ This is a warning diagnostic (#2).
//      //       │  ✏️ This is a fix-it (#0).
//      //       │  ✏️ This is a fix-it (#1).
//      //       ╰─ ℹ️ This is a note diagnostic (#3).
//      //      struct S {}
//      //      """
//      //    } expansion: {
//      //      """
//      //      struct S {}
//      //      """
//    }
//  }
//
//  // The actual DiagnosticsAndFixitsEmitterMacro, for comparison to above.
//  func testDiagnosticsAndFixitsEmitterMacro() {
//    assertMacro([DiagnosticsAndFixitsEmitterMacro.self]) {
//      """
//      @DiagnosticsAndFixitsEmitter
//      struct S {}
//      """
//      //    } diagnostics: {
//      //      """
//      //      @DiagnosticsAndFixitsEmitter
//      //       ┬──────────────────────────
//      //       ├─ ⚠️ This is the first diagnostic.
//      //       │  ✏️ This is the first fix-it.
//      //       │  ✏️ This is the second fix-it.
//      //       ╰─ ℹ️ This is the second diagnostic, it's a note.
//      //      struct S {}
//      //      """
//      //    } expansion: {
//      //      """
//      //      struct S {}
//      //      """
//    }
//  }
//
//  // `SwiftSyntaxMacrosTestSupport.assertMacroExpansion` works as expected.
//  // (The compiler/Xcode also work as expected.)
//  func testDiagnosticFixit_assertMacroExpansion() {
//    enum TestMacro: MemberMacro {
//      public static func expansion(
//        of node: AttributeSyntax,
//        providingMembersOf declaration: some DeclGroupSyntax,
//        in context: some MacroExpansionContext
//      ) throws -> [DeclSyntax] {
//        context.diagnose(
//          .error(
//            on: node,
//            fixIts: [.error(on: node)]  // 👈 fixit
//          )
//        )
//
//        return []
//      }
//    }
//
//    assertMacroExpansion(
//      """
//      @Test
//      struct S {}
//      """,
//      expandedSource: """
//        struct S {}
//        """,
//      diagnostics: [
//        DiagnosticSpec(
//          message: "This is an error diagnostic (#1).",
//          line: 1,
//          column: 2,
//          fixIts: [
//            FixItSpec(message: "This is a fix-it (#0).")
//          ]
//        )
//      ],
//      macros: [
//        "Test": TestMacro.self
//      ]
//    )
//  }
//
//  // This test shows awkward but expected behavior, given the bug that the "expansion" is empty.
//  func testDiagnostic() {
//    enum TestMacro: MemberMacro {
//      public static func expansion(
//        of node: AttributeSyntax,
//        providingMembersOf declaration: some DeclGroupSyntax,
//        in context: some MacroExpansionContext
//      ) throws -> [DeclSyntax] {
//        context.diagnose(
//          .error(on: node)  // 👈 no fixit
//        )
//
//        return []
//      }
//    }
//
//    // Bug: Expanding `assertMacro` omits the "expansion".
//    assertMacro([TestMacro.self]) {
//      """
//      @Test
//      struct S {}
//      """
//      //    } diagnostics: {
//      //      """
//      //      @Test
//      //       ┬───
//      //       ╰─ 🛑 This is an error diagnostic (#0).
//      //      struct S {}
//      //      """
//    }
//
//    // `assertMacro` expands as expected when given the correct "expansion".
//    assertMacro([TestMacro.self]) {
//      """
//      @Test
//      struct S {}
//      """
//      //    } diagnostics: {
//      //      """
//      //      @Test
//      //       ┬───
//      //       ╰─ 🛑 This is an error diagnostic (#1).
//      //      struct S {}
//      //      """
//    } expansion: {
//      """
//      struct S {}
//      """
//    }
//
//    // 🛑 `assertMacro` test failure: : 'failed - Expected macro expansion, but there was none'
//    assertMacro([TestMacro.self]) {
//      """
//      @Test
//      struct S {}
//      """
//    } diagnostics: {
//      """
//      @Test
//       ┬───
//       ╰─ 🛑 This is an error diagnostic (#0).
//      struct S {}
//      """
//    } expansion: {
//      """
//      struct S {}
//      """
//    }
//  }
//
//}
