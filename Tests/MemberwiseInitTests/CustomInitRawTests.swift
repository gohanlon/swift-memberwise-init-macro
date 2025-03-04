import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

final class CustomInitRawTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      indentationWidth: .spaces(2),
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "InitRaw": InitMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  func testInitRaw() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @InitRaw var v: T
      }
      """
    } expansion: {
      """
      struct S {
        var v: T

        internal init(
          v: T
        ) {
          self.v = v
        }
      }
      """
    }
  }

  func testDefault() {
    assertMacro {
      """
      @MemberwiseInit
      public struct S<T: Numeric> {
        @InitRaw(default: 0) let number: T
      }
      """
    } expansion: {
      """
      public struct S<T: Numeric> {
        let number: T

        internal init(
          number: T = 0
        ) {
          self.number = number
        }
      }
      """
    }
  }

  func testDefaultOnInitializedLet() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @InitRaw(default: 42) let number = 0
      }
      """
    } expansion: {
      """
      struct S {
        let number = 0

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @InitRaw(default: 42) let number = 0
                 ┬──────────
                 ╰─ 🛑 @InitRaw can't be applied to already initialized constant
                    ✏️ Remove '@InitRaw(default: 42)'
                    ✏️ Remove '= 0'
      }
      """
    } fixes: {
      """
      @InitRaw(default: 42) let number = 0
               ┬──────────
               ╰─ 🛑 @InitRaw can't be applied to already initialized constant

      ✏️ Remove '@InitRaw(default: 42)'
      @MemberwiseInit
      struct S {
        let number = 0
      }

      ✏️ Remove '= 0'
      @MemberwiseInit
      struct S {
        @InitRaw(default: 42) let number: Int
      }
      """
    }
  }

  func testType() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @InitRaw(type: Q.self) var v: T
      }
      """
    } expansion: {
      """
      struct S {
        var v: T

        internal init(
          v: Q
        ) {
          self.v = v
        }
      }
      """
    }
  }

  func testTypeAsGenericExpression() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @InitRaw(type: Q<R>.self) var v: T
      }
      """
    } expansion: {
      """
      struct S {
        var v: T

        internal init(
          v: Q<R>
        ) {
          self.v = v
        }
      }
      """
    }
  }

  func testEverything() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct S {
        @InitRaw(.public, assignee: "self.foo", default: nil, escaping: true, label: "_", type: Q<T>?.self)
        var initRaw: T
      }
      """
    } expansion: {
      """
      public struct S {
        var initRaw: T

        public init(
          _ initRaw: @escaping Q<T>? = nil
        ) {
          self.foo = initRaw
        }
      }
      """
    }
  }

  // NB: In Swift 5.9, you could use `type: Q` without `.self`
  // In Swift 6, you must use `type: Q.self` when referencing types as values
  //
  // @MemberwiseInit doesn't produce warnings/fix-its for the Swift 5.9 syntax because:
  // 1. On Swift 6, the compiler already produces errors with fix-its
  // 2. Adding our own diagnostics would create redundant, noisy warnings alongside compiler errors
  // 3. Both syntax forms produce the correct output with proper parameter types
  func testTypeReferenceCompatibility() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(type: Q) var v: T
      }
      """
    } expansion: {
      """
      struct S {
        @Init(type: Q) var v: T

        internal init(
          v: Q
        ) {
          self.v = v
        }
      }
      """
    }
  }
}
