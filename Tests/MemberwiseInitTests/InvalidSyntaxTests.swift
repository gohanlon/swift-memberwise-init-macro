import MacroTesting
import MemberwiseInitMacros
import XCTest

final class InvalidSyntaxTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      indentationWidth: .spaces(2),
      record: .failed,
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "InitRaw": InitMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  func testInvalidRedeclaration_SucceedsWithInvalidCode() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        let x: T
        let x: T
      }
      """
    } expansion: {
      """
      struct S {
        let x: T
        let x: T

        internal init(
          x: T,
          x: T
        ) {
          self.x = x
          self.x = x
        }
      }
      """
    }
  }

  func testInvalidRedeclaration2_SucceedsWithInvalidCode() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        let x, x: T
      }
      """
    } expansion: {
      """
      struct S {
        let x, x: T

        internal init(
          x: T,
          x: T
        ) {
          self.x = x
          self.x = x
        }
      }
      """
    }
  }

  func testInvalidRedeclarationAndCustomLabelConflictsWithPropertyName_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "x") let x: T
        let x: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "x") let x: T
                     ┬──
                     ╰─ 🛑 Label 'x' conflicts with a property name
        let x: T
      }
      """
    } 
  }
}
