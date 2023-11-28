import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

final class CustomInitWrapperTests: XCTestCase {
  override func invokeTest() {
    // NB: Waiting for swift-macro-testing PR to support explicit indentationWidth: https://github.com/pointfreeco/swift-macro-testing/pull/8
    withMacroTesting(
      //indentationWidth: .spaces(2),
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
        @InitWrapper(type: Q<T>)
        var initWrapper: T
      }
      """
    } expansion: {
      """
      struct S {
        var initWrapper: T

        internal init(
          initWrapper: Q<T>
        ) {
          self._initWrapper = initWrapper
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
        @InitWrapper(escaping: true, type: Q<T>)
        var initWrapper: T
      }
      """
    } expansion: {
      """
      struct S {
        var initWrapper: T

        internal init(
          initWrapper: @escaping Q<T>
        ) {
          self._initWrapper = initWrapper
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
        @InitWrapper(label: "_", type: Q<T>)
        var initWrapper: T
      }
      """
    } expansion: {
      """
      struct S {
        var initWrapper: T

        internal init(
          _ initWrapper: Q<T>
        ) {
          self._initWrapper = initWrapper
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
        @InitWrapper(.public, escaping: true, label: "_", type: Q<T>)
        var initWrapper: T
      }
      """
    } expansion: {
      """
      public struct S {
        var initWrapper: T

        public init(
          _ initWrapper: @escaping Q<T>
        ) {
          self._initWrapper = initWrapper
        }
      }
      """
    }
  }
}
