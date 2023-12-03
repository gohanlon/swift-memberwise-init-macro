import MacroTesting
import MemberwiseInitMacros
import XCTest

final class CustomInitDefaultTests: XCTestCase {
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

  func testLet() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let number: T
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42) let number: T

        internal init(
          number: T = 42
        ) {
          self.number = number
        }
      }
      """
    }
  }

  func testVar() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var number: T
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42) var number: T

        internal init(
          number: T = 42
        ) {
          self.number = number
        }
      }
      """
    }
  }

  // TODO: For 1.0, diagnostic on nonsensical @Init(default:)?
  func testInitializedLet() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let number = 0
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42) let number = 0

        internal init() {
        }
      }
      """
    }
  }

  func testInitializedVar_InitializerWins() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var number = 0
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42) var number = 0

        internal init(
          number: Int = 0
        ) {
          self.number = number
        }
      }
      """
    }
  }

  func testLetWithMultipleBindings() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let x, y: Int
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42) let x, y: Int

        internal init(
          x: Int = 42,
          y: Int = 42
        ) {
          self.x = x
          self.y = y
        }
      }
      """
    }
  }

  func testVarWithMultipleBindings() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var x, y: Int
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42) var x, y: Int

        internal init(
          x: Int = 42,
          y: Int = 42
        ) {
          self.x = x
          self.y = y
        }
      }
      """
    }
  }

  func testLetWithFirstBindingInitialized() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let x = 0, y: Int
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42) let x = 0, y: Int

        internal init(
          y: Int = 42
        ) {
          self.y = y
        }
      }
      """
    }
  }

  func testVarWithFirstBindingInitialized() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var x = 0, y: Int
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42) var x = 0, y: Int

        internal init(
          x: Int = 0,
          y: Int = 42
        ) {
          self.x = x
          self.y = y
        }
      }
      """
    }
  }

  func testLetWithRaggedBindings_SucceedsWithInvalidCode() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let x: Int, isOn: Bool
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42) let x: Int, isOn: Bool

        internal init(
          x: Int = 42,
          isOn: Bool = 42
        ) {
          self.x = x
          self.isOn = isOn
        }
      }
      """
    }
  }
}
