import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

final class CustomInitWrapperTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      indentationWidth: .spaces(2),
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "Init": InitMacro.self,
        "InitWrapper": InitMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  func testType() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @InitWrapper(type: Q<T>.self)
        var v: T
      }
      """
    } expansion: {
      """
      struct S {
        var v: T

        internal init(
          v: Q<T>
        ) {
          self._v = v
        }
      }
      """
    }
  }

  func testEscaping() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @InitWrapper(escaping: true, type: Q<T>.self)
        var v: T
      }
      """
    } expansion: {
      """
      struct S {
        var v: T

        internal init(
          v: @escaping Q<T>
        ) {
          self._v = v
        }
      }
      """
    }
  }

  func testLabel() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @InitWrapper(label: "_", type: Q<T>.self)
        var v: T
      }
      """
    } expansion: {
      """
      struct S {
        var v: T

        internal init(
          _ v: Q<T>
        ) {
          self._v = v
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
        @InitWrapper(.public, default: Q<T>(), escaping: true, label: "_", type: Q<T>.self)
        var v: T
      }
      """
    } expansion: {
      """
      public struct S {
        var v: T

        public init(
          _ v: @escaping Q<T> = Q<T>()
        ) {
          self._v = v
        }
      }
      """
    }
  }
}
