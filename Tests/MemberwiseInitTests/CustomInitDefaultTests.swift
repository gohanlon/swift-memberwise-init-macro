import MacroTesting
import MemberwiseInitMacros
import XCTest

// TODO: Carefully consider whether to allow @Init(default:) to be applied to multiple bindings

final class CustomInitDefaultTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      indentationWidth: .spaces(2),
      record: .missing,
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

  // TODO: For 1.0, strengthen by rejecting @Init on already initialized let (not just on '@Init(default:)')
  func testInitializedLet() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let number = 0
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let number = 0
              ┬──────────
              ╰─ 🛑 @Init can't be applied to already initialized constant
                 ✏️ Remove '@Init(default: 42)'
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

  func testInitializedLetCustomLabel() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42, label: "_") let number = 0
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42, label: "_") let number = 0
              ┬───────────
              ╰─ 🛑 @Init can't be applied to already initialized constant
                 ✏️ Remove '@Init(default: 42, label: "_")'
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

  func testInitializedVar() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var number = 0
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var number = 0
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to already initialized variable
                 ✏️ Remove '@Init(default: 42)'
                 ✏️ Remove '= 0'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        var number = 0
      }
      """
    } expansion: {
      """
      struct S {
        var number = 0

        internal init(
          number: Int = 0
        ) {
          self.number = number
        }
      }
      """
    }
  }

  func testAttributedInitializedLet() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init(default: 42) let number = 0
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init(default: 42) let number = 0
                       ┬──────────
                       ╰─ 🛑 @Init can't be applied to already initialized constant
                          ✏️ Remove '@Init(default: 42)'
                          ✏️ Remove '= 0'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        @Binding let number = 0
      }
      """
    } expansion: {
      """
      struct S {
        @Binding let number = 0

        internal init() {
        }
      }
      """
    }
  }

  func testAttributedInitializedLet2() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init(default: T.q) let number = T.t
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init(default: T.q) let number = T.t
                       ┬───────────
                       ╰─ 🛑 @Init can't be applied to already initialized constant
                          ✏️ Remove '@Init(default: T.q)'
                          ✏️ Remove '= T.t'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        @Binding let number = T.t
      }
      """
    } expansion: {
      """
      struct S {
        @Binding let number = T.t

        internal init() {
        }
      }
      """
    }
  }

  func testAttributedInitializedVar() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init(default: 42) var number = 0
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init(default: 42) var number = 0
                       ┬──────────
                       ╰─ 🛑 Custom 'default' can't be applied to already initialized variable
                          ✏️ Remove 'default: 42'
                          ✏️ Remove '= 0'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init var number = 0
      }
      """
    } expansion: {
      """
      struct S {
        @Binding @Init var number = 0

        internal init(
          number: Int = 0
        ) {
          self.number = number
        }
      }
      """
    }
  }

  func testAttributedInitializedVar2() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init(default: T.q) var number = T.t
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init(default: T.q) var number = T.t
                       ┬───────────
                       ╰─ 🛑 Custom 'default' can't be applied to already initialized variable
                          ✏️ Remove 'default: T.q'
                          ✏️ Remove '= T.t'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        @Binding @Init var number = T.t
      }
      """
    } 
  }

  // TODO: This test doesn't fit perfectly here because it touches on label
  func testInitializedVarCustomLabel() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42, label: "_") var number = 0
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42, label: "_") var number = 0
              ┬───────────
              ╰─ 🛑 Custom 'default' can't be applied to already initialized variable
                 ✏️ Remove 'default: 42'
                 ✏️ Remove '= 0'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "_") var number = 0
      }
      """
    } expansion: {
      """
      struct S {
        @Init(label: "_") var number = 0

        internal init(
          _ number: Int = 0
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
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let x, y: Int
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to multiple bindings
                 ✏️ Remove '@Init(default: 42)'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        let x, y: Int
      }
      """
    } expansion: {
      """
      struct S {
        let x, y: Int

        internal init(
          x: Int,
          y: Int
        ) {
          self.x = x
          self.y = y
        }
      }
      """
    }
    //    } expansion: {
    //      """
    //      struct S {
    //        @Init(default: 42) let x, y: Int
    //
    //        internal init(
    //          x: Int = 42,
    //          y: Int = 42
    //        ) {
    //          self.x = x
    //          self.y = y
    //        }
    //      }
    //      """
  }

  func testVarWithMultipleBindings() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var x, y: Int
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var x, y: Int
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to multiple bindings
                 ✏️ Remove '@Init(default: 42)'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        var x, y: Int
      }
      """
    } expansion: {
      """
      struct S {
        var x, y: Int

        internal init(
          x: Int,
          y: Int
        ) {
          self.x = x
          self.y = y
        }
      }
      """
    }
    //    } expansion: {
    //      """
    //      struct S {
    //        @Init(default: 42) var x, y: Int
    //
    //        internal init(
    //          x: Int = 42,
    //          y: Int = 42
    //        ) {
    //          self.x = x
    //          self.y = y
    //        }
    //      }
    //      """
  }

  func testLetWithFirstBindingInitialized() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let x = 0, y: Int
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let x = 0, y: Int
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to multiple bindings
                 ✏️ Remove '@Init(default: 42)'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        let x = 0, y: Int
      }
      """
    } expansion: {
      """
      struct S {
        let x = 0, y: Int

        internal init(
          y: Int
        ) {
          self.y = y
        }
      }
      """
    }
    //    } expansion: {
    //      """
    //      struct S {
    //        @Init(default: 42) let x = 0, y: Int
    //
    //        internal init(
    //          y: Int = 42
    //        ) {
    //          self.y = y
    //        }
    //      }
    //      """
  }

  func testVarWithFirstBindingInitialized() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var x = 0, y: Int
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) var x = 0, y: Int
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to multiple bindings
                 ✏️ Remove '@Init(default: 42)'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        var x = 0, y: Int
      }
      """
    } expansion: {
      """
      struct S {
        var x = 0, y: Int

        internal init(
          x: Int = 0,
          y: Int
        ) {
          self.x = x
          self.y = y
        }
      }
      """
    }
    //    } expansion: {
    //      """
    //      struct S {
    //        @Init(default: 42) var x = 0, y: Int
    //
    //        internal init(
    //          x: Int = 0,
    //          y: Int = 42
    //        ) {
    //          self.x = x
    //          self.y = y
    //        }
    //      }
    //      """
  }

  func testLetWithRaggedBindings() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let x: Int, isOn: Bool
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42) let x: Int, isOn: Bool
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to multiple bindings
                 ✏️ Remove '@Init(default: 42)'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        let x: Int, isOn: Bool
      }
      """
    } expansion: {
      """
      struct S {
        let x: Int, isOn: Bool

        internal init(
          x: Int,
          isOn: Bool
        ) {
          self.x = x
          self.isOn = isOn
        }
      }
      """
    }
    //    } expansion: {
    //      """
    //      struct S {
    //        @Init(default: 42) let x: Int, isOn: Bool
    //
    //        internal init(
    //          x: Int = 42,
    //          isOn: Bool = 42
    //        ) {
    //          self.x = x
    //          self.isOn = isOn
    //        }
    //      }
    //      """
  }
}
