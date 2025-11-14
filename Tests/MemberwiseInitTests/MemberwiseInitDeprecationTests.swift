import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class MemberwiseInitDeprecationTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      indentationWidth: .spaces(2),
      record: .missing,
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "Init": InitMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // Deprecated; remove in 1.0
  func testDotEscaping1() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(.escaping) var value: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(.escaping) var value: T
              ┬────────
              ╰─ ⚠️ @Init(.escaping) is deprecated
                 ✏️ Replace '@Init(.escaping)' with '@Init(escaping: true)'
      }
      """
    } fixes: {
      """
      @Init(.escaping) var value: T
            ┬────────
            ╰─ ⚠️ @Init(.escaping) is deprecated

      ✏️ Replace '@Init(.escaping)' with '@Init(escaping: true)'
      @MemberwiseInit
      struct S {
        @Init(escaping: true) var value: T
      }
      """
    } expansion: {
      """
      struct S {
        var value: T
      
        internal init(
          value: @escaping T
        ) {
          self.value = value
        }
      }
      """
    }
  }

  // Deprecated; remove in 1.0
  func testDotEscaping2() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(.public, .escaping) var value: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(.public, .escaping) var value: T
              ┬─────────────────
              ╰─ ⚠️ @Init(.escaping) is deprecated
                 ✏️ Replace '@Init(.escaping)' with '@Init(escaping: true)'
      }
      """
    } fixes: {
      """
      @Init(.public, .escaping) var value: T
            ┬─────────────────
            ╰─ ⚠️ @Init(.escaping) is deprecated

      ✏️ Replace '@Init(.escaping)' with '@Init(escaping: true)'
      @MemberwiseInit
      struct S {
        @Init(.public, escaping: true) var value: T
      }
      """
    } expansion: {
      """
      struct S {
        var value: T
      
        internal init(
          value: @escaping T
        ) {
          self.value = value
        }
      }
      """
    }
  }

  // Deprecated; remove in 1.0
  func testDotEscaping3() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(.escaping, label: "_") var value: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(.escaping, label: "_") var value: T
              ┬────────────────────
              ╰─ ⚠️ @Init(.escaping) is deprecated
                 ✏️ Replace '@Init(.escaping)' with '@Init(escaping: true)'
      }
      """
    } fixes: {
      """
      @Init(.escaping, label: "_") var value: T
            ┬────────────────────
            ╰─ ⚠️ @Init(.escaping) is deprecated

      ✏️ Replace '@Init(.escaping)' with '@Init(escaping: true)'
      @MemberwiseInit
      struct S {
        @Init(escaping: true, label: "_") var value: T
      }
      """
    } expansion: {
      """
      struct S {
        var value: T
      
        internal init(
          _ value: @escaping T
        ) {
          self.value = value
        }
      }
      """
    }
  }

  // Deprecated; remove in 1.0
  func testDotEscaping4() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(.public, .escaping, label: "_") var value: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(.public, .escaping, label: "_") var value: T
              ┬─────────────────────────────
              ╰─ ⚠️ @Init(.escaping) is deprecated
                 ✏️ Replace '@Init(.escaping)' with '@Init(escaping: true)'
      }
      """
    } fixes: {
      """
      @Init(.public, .escaping, label: "_") var value: T
            ┬─────────────────────────────
            ╰─ ⚠️ @Init(.escaping) is deprecated

      ✏️ Replace '@Init(.escaping)' with '@Init(escaping: true)'
      @MemberwiseInit
      struct S {
        @Init(.public, escaping: true, label: "_") var value: T
      }
      """
    } expansion: {
      """
      struct S {
        var value: T
      
        internal init(
          _ value: @escaping T
        ) {
          self.value = value
        }
      }
      """
    }
  }
}
