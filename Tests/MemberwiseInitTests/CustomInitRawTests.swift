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
        @InitRaw var type: T
      }
      """
    } expansion: {
      """
      struct S {
        var type: T

        internal init(
          type: T
        ) {
          self.type = type
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
        @InitRaw(type: Q) var type: T
      }
      """
    } expansion: {
      """
      struct S {
        var type: T

        internal init(
          type: Q
        ) {
          self.type = type
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
        @InitRaw(type: Q<R>) var type: T
      }
      """
    } expansion: {
      """
      struct S {
        var type: T

        internal init(
          type: Q<R>
        ) {
          self.type = type
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
        @InitRaw(.public, assignee: "self.foo", escaping: true, label: "_", type: Q<T>)
        var initRaw: T
      }
      """
    } expansion: {
      """
      public struct S {
        var initRaw: T

        public init(
          _ initRaw: @escaping Q<T>
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
  //        @Init(type: Q.self) var type: T
  //      }
  //      """
  //    } diagnostics: {
  //      """
  //      @MemberwiseInit
  //      struct S {
  //        @Init(type: Q.self) var type: T
  //            ┬─────────────────
  //            ╰─ 🛑 Invalid use of metatype 'Q.self'. Expected a type, not its metatype.
  //            ╰─ 🛑 Remove '.self'; type is expected, not a metatype.
  //      }
  //      """
  //    }
  //  }
}
