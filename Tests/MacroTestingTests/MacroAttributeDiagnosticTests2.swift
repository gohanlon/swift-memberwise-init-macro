//// Come back and check this work after two PRs land or are otherwise resolved:
//// - Update FixItApplier
//// - Multi-FixIt support

//import MacroTesting
//import SwiftDiagnostics
//import SwiftSyntax
//import SwiftSyntaxBuilder
//import SwiftSyntaxMacros
//import SwiftSyntaxMacrosTestSupport
//import XCTest
//
//// TODO: i am here
//// This doesn't actually have to do with the diagnostic being on the AttributeSyntax node, as I originally though.
//// This has to do with the combination of diagnostics/types/severities.
//// For example, adding a "note" changes the behavior, but not completely.
//// It actually fixes the crash, but the expansion is still wrong.
////
//// Need to show permutations/combinations:
//// - Diagnostic
//// - Diagnostic, FixIt
//// - Diagnostic, FixIt, Note
//
//// Change tests to this style, to ease undertanding of what's being tested
///*
//enum TestMacro: MemberMacro {
//  public static func expansion(
//    of node: AttributeSyntax,
//    providingMembersOf declaration: some DeclGroupSyntax,
//    in context: some MacroExpansionContext
//  ) throws -> [DeclSyntax] {
////        context.diagnose(.error)
////        context.diagnose(.errorWithFixit)
////        context.diagnose(.errorWithFixit + .note)
////        context.diagnose(.warning)
////        context.diagnose(.warningWithFixit)
////        context.diagnose(.warningWithFixit + .note)
//
// //        context.diagnose(.error)
// //        context.diagnose(.error(fixit: .error) + .note)
// //        context.diagnose(.error(fixit: .error))
// //        context.diagnose(.error(fixit: .warning))
// //        context.diagnose(.error(fixit: .warning) + .note)
//
// //        context.diagnose(.warning)
// //        context.diagnose(.warning(fixit: .error) + .note)
// //        context.diagnose(.warning(fixit: .error))
// //        context.diagnose(.warning(fixit: .warning))
// //        context.diagnose(.warning(fixit: .warning) + .note)
//
//    return []
//  }
//}
//*/
//
//enum MacroAttributeDiagnosticEmitterMacro2: MemberMacro {
//  public static func expansion(
//    of node: AttributeSyntax,
//    providingMembersOf declaration: some DeclGroupSyntax,
//    in context: some MacroExpansionContext
//  ) throws -> [DeclSyntax] {
//    context.diagnose(
//      Diagnostic(
//        node: node.attributeName,
//        message: SimpleDiagnosticMessage(
//          message: "This is the first diagnostic.",
//          diagnosticID: MessageID(domain: "domain", id: "diagnostic1"),
//          severity: .error
//        )
//      )
//    )
//
//    return []
//  }
//}
//
//enum MacroAttributeDiagnosticAndFixitEmitterMacro2: MemberMacro {
//  public static func expansion(
//    of node: AttributeSyntax,
//    providingMembersOf declaration: some DeclGroupSyntax,
//    in context: some MacroExpansionContext
//  ) throws -> [DeclSyntax] {
//    let firstFixIt = FixIt(
//      message: SimpleDiagnosticMessage(
//        message: "This is the first fix-it.",
//        diagnosticID: MessageID(domain: "domain", id: "fixit"),
//        severity: .warning
//      ),
//      changes: [
//        //        .replace(oldNode: Syntax(declaration), newNode: Syntax(declaration))  // no-op, testMacroAttributeDiagnosticAndFixitEmitter still crashes
//        .replace(oldNode: Syntax(node), newNode: Syntax(node))  // no-op
//      ]
//    )
//
//    context.diagnose(
//      Diagnostic(
//        node: node.attributeName,
//        message: SimpleDiagnosticMessage(
//          message: "This is the first diagnostic.",
//          diagnosticID: MessageID(domain: "domain", id: "diagnostic2"),
//          severity: .error
//        ),
//        fixIts: [firstFixIt]
//      )
//    )
//    //    context.diagnose(
//    //      Diagnostic(
//    //        node: node.attributeName,
//    //        message: SimpleDiagnosticMessage(
//    //          message: "This is the second diagnostic, it's a note.",
//    //          diagnosticID: MessageID(domain: "domain", id: "diagnostic3"),
//    //          severity: .note)))
//
//    return []
//  }
//}
//
//final class MacroAttributeDiagnosticTests2: XCTestCase {
//  // No fixit, with prexisting "expansion": no crash.
//  // See next `testMacroAttributeDiagnosticEmitter_After` for expanded `assertMacro`.
//  func testMacroAttributeDiagnosticEmitter_Before() {
//    assertMacro([MacroAttributeDiagnosticEmitterMacro2.self]) {
//      """
//      @MacroAttributeDiagnosticEmitter
//      struct S {
//      }
//      """
//    } expansion: {
//      """
//      struct S {
//      }
//      """
//    }
//  }
//
//  // Correctly expanded `assertMacro` from above `testMacroAttributeDiagnosticEmitter_Before`.
//  // But, this test fails: 'failed - Expected macro expansion, but there was none'
//  func testMacroAttributeDiagnosticEmitter_After() {
//    assertMacro([MacroAttributeDiagnosticEmitterMacro2.self]) {
//      """
//      @MacroAttributeDiagnosticEmitter
//      struct S {
//      }
//      """
//    } diagnostics: {
//      """
//      @MacroAttributeDiagnosticEmitter
//       ┬──────────────────────────────
//       ╰─ 🛑 This is the first diagnostic.
//      struct S {
//      }
//      """
//    } expansion: {
//      """
//      struct S {
//      }
//      """
//    }
//  }
//
//  // 🛑 🛑 🛑 Will crash
//  // Has fixit and existing "expansion", so it will crash.
//  func testMacroAttributeDiagnosticAndFixitEmitter() {
//    assertMacro([MacroAttributeDiagnosticAndFixitEmitterMacro2.self]) {
//      """
//      @MacroAttributeDiagnosticAndFixitEmitter
//      struct S {
//      }
//      """
//    } expansion: {
//      """
//      struct S {
//      }
//      """
//    }
//  }
//
//  // TODO: This assertMacro expands correctly, despite preexisting expansion ...wha?
//  // And after it expands correctly, it passes.
//  // This must be a huge clue.
//  // Maybe because it has not diagnostics of "error" severity? I don't think so?
//  //  DiagnosticsAndFixitsEmitterMacro
//  func testMacroAttributeDiagnosticAndFixitEmitterASDF() {
//    assertMacro([DiagnosticsAndFixitsEmitterMacro.self]) {
//      """
//      @DiagnosticsAndFixitsEmitter
//      struct S {
//      }
//      """
//      //    } diagnostics: {
//      //      """
//      //      @DiagnosticsAndFixitsEmitter
//      //       ┬──────────────────────────
//      //       ├─ ⚠️ This is the first diagnostic.
//      //       │  ✏️ This is the first fix-it.
//      //       │  ✏️ This is the second fix-it.
//      //       ╰─ ℹ️ This is the second diagnostic, it's a note.
//      //      struct S {
//      //      }
//      //      """
//    } expansion: {
//      """
//      struct S {
//      }
//      """
//    }
//  }
//
//  // Here, `assertMacro` expands but is wrong: "expansion" is blank.
//  // * See next `testMacroAttributeDiagnosticAndFixitEmitter_After` for expanded `assertMacro`.
//  func testMacroAttributeDiagnosticAndFixitEmitter_Before() {
//    assertMacro([MacroAttributeDiagnosticAndFixitEmitterMacro2.self]) {
//      """
//      @MacroAttributeDiagnosticAndFixitEmitter
//      struct S {
//      }
//      """
//    }
//  }
//
//  // Incorrectly expanded `assertMacro` from above `testMacroAttributeDiagnosticAndFixitEmitter_Before`.
//  // * In this state, the test doesn't crash (and passes).
//  // * If you manually add the correct non-blank "expansion", the test will fail because it
//  //   differs from blank but it won't crash.
//  func testMacroAttributeDiagnosticAndFixitEmitter_After() {
//    assertMacro([MacroAttributeDiagnosticAndFixitEmitterMacro2.self]) {
//      """
//      @MacroAttributeDiagnosticAndFixitEmitter
//      struct S {
//      }
//      """
//    } diagnostics: {
//      """
//      @MacroAttributeDiagnosticAndFixitEmitter
//       ┬──────────────────────────────────────
//       ╰─ 🛑 This is the first diagnostic.
//          ✏️ This is the first fix-it.
//      struct S {
//      }
//      """
//    } fixes: {
//      """
//      @MacroAttributeDiagnosticAndFixitEmitter
//      """
//    } expansion: {
//      """
//
//      """
//    }
//  }
//
//  // `SwiftSyntaxMacrosTestSupport.assertMacroExpansion` works as expected.
//  // (The compiler/Xcode also work as expected.)
//  func testMacroAttributeDiagnosticAndFixitEmitter_assertMacroExpansion() {
//    assertMacroExpansion(
//      """
//      @MacroAttributeDiagnosticAndFixitEmitter
//      struct S {
//      }
//      """,
//      expandedSource: """
//        struct S {
//        }
//        """,
//      diagnostics: [
//        DiagnosticSpec(
//          message: "This is the first diagnostic.",
//          line: 1,
//          column: 2,
//          fixIts: [
//            FixItSpec(message: "This is the first fix-it.")
//          ]
//        )
//      ],
//      macros: [
//        "MacroAttributeDiagnosticAndFixitEmitter": MacroAttributeDiagnosticAndFixitEmitterMacro2
//          .self
//      ]
//    )
//  }
//}
