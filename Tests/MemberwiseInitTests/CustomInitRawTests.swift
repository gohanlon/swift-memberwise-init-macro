import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

final class CustomInitRawTests: XCTestCase {
  override func invokeTest() {
    // NB: Waiting for swift-macro-testing PR to support explicit indentationWidth: https://github.com/pointfreeco/swift-macro-testing/pull/8
    withMacroTesting(
      //indentationWidth: .spaces(2),
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

  // FIXME: Exclusively applicable fix-its aren't testable: https://github.com/pointfreeco/swift-macro-testing/issues/14
  func testDefaultOnInitializedLet() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @InitRaw(default: 42) let number = 0
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
      @MemberwiseInit
      struct S {
        let number = 0
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
    }
  }

  func testType() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @InitRaw(type: Q) var v: T
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
        @InitRaw(type: Q<R>) var v: T
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
        @InitRaw(.public, assignee: "self.foo", default: nil, escaping: true, label: "_", type: Q<T>?)
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

  // TODO: Add fix-it diagnostic when provided type is a Metatype
  //  func testTypeAsMetatype_FailsWithDiagnostic() {
  //    assertMacro(record: true) {
  //      """
  //      @MemberwiseInit
  //      struct S {
  //        @Init(type: Q.self) var v: T
  //      }
  //      """
  //    } diagnostics: {
  //      """
  //      @MemberwiseInit
  //      struct S {
  //        @Init(type: Q.self) var v: T
  //            ┬─────────────────
  //            ╰─ 🛑 Invalid use of metatype 'Q.self'. Expected a type, not its metatype.
  //            ╰─ 🛑 Remove '.self'; type is expected, not a metatype.
  //      }
  //      """
  //    }
  //  }
}
