import MacroTesting
import XCTest

final class WarningMacroTests: BaseTestCase {
  override func invokeTest() {
    withMacroTesting(macros: ["myWarning": WarningMacro.self]) {
      super.invokeTest()
    }
  }

  func testExpansionWithValidStringLiteralEmitsWarning() {
    assertMacro {
      """
      #myWarning("This is a warning")
      """
    } expansion: {
      """
      ()
      """
    } diagnostics: {
      """
      #myWarning("This is a warning")
      ┬──────────────────────────────
      ╰─ ⚠️ This is a warning
      """
    }
  }

  func testExpansionWithInvalidExpressionEmitsError() {
    assertMacro {
      """
      #myWarning(42)
      """
    } diagnostics: {
      """
      #myWarning(42)
      ┬─────────────
      ╰─ 🛑 #myWarning macro requires a string literal
      """
    }
  }

  func testExpansionWithStringInterpolationEmitsError() {
    assertMacro {
      #"""
      #myWarning("Say hello \(number) times!")
      """#
    } diagnostics: {
      #"""
      #myWarning("Say hello \(number) times!")
      ┬───────────────────────────────────────
      ╰─ 🛑 #myWarning macro requires a string literal
      """#
    }
  }
}
