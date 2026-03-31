import MacroTesting
import MemberwiseInitMacros
import XCTest

// NB: @Init(default:) on multiple bindings is intentionally rejected — applying a single default
// value across multiple bindings is ambiguous and error-prone.

final class CustomInitDefaultTests: XCTestCase {
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
    } expansion: {
      """
      struct S {
        @Init(default: 42) let number = 0

        internal init() {
        }
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
      @Init(default: 42) let number = 0
            ┬──────────
            ╰─ 🛑 @Init can't be applied to already initialized constant

      ✏️ Remove '@Init(default: 42)'
      @MemberwiseInit
      struct S {
        let number = 0
      }

      ✏️ Remove '= 0'
      @MemberwiseInit
      struct S {
        @Init(default: 42) let number: Int
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
    } expansion: {
      """
      struct S {
        @Init(default: 42, label: "_") let number = 0

        internal init() {
        }
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
      @Init(default: 42, label: "_") let number = 0
            ┬───────────
            ╰─ 🛑 @Init can't be applied to already initialized constant

      ✏️ Remove '@Init(default: 42, label: "_")'
      @MemberwiseInit
      struct S {
        let number = 0
      }

      ✏️ Remove '= 0'
      @MemberwiseInit
      struct S {
        @Init(default: 42, label: "_") let number: Int
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
    } expansion: {
      """
      struct S {
        @Init(default: 42) var number = 0

        internal init() {
        }
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
      @Init(default: 42) var number = 0
            ┬──────────
            ╰─ 🛑 Custom 'default' can't be applied to already initialized variable

      ✏️ Remove '@Init(default: 42)'
      @MemberwiseInit
      struct S {
        var number = 0
      }

      ✏️ Remove '= 0'
      @MemberwiseInit
      struct S {
        @Init(default: 42) var number: Int
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
    } expansion: {
      """
      struct S {
        @Binding @Init(default: 42) let number = 0

        internal init() {
        }
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
      @Binding @Init(default: 42) let number = 0
                     ┬──────────
                     ╰─ 🛑 @Init can't be applied to already initialized constant

      ✏️ Remove '@Init(default: 42)'
      @MemberwiseInit
      struct S {
        @Binding let number = 0
      }

      ✏️ Remove '= 0'
      @MemberwiseInit
      struct S {
        @Binding @Init(default: 42) let number: Int
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
    } expansion: {
      """
      struct S {
        @Binding @Init(default: T.q) let number = T.t

        internal init() {
        }
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
      @Binding @Init(default: T.q) let number = T.t
                     ┬───────────
                     ╰─ 🛑 @Init can't be applied to already initialized constant

      ✏️ Remove '@Init(default: T.q)'
      @MemberwiseInit
      struct S {
        @Binding let number = T.t
      }

      ✏️ Remove '= T.t'
      @MemberwiseInit
      struct S {
        @Binding @Init(default: T.q) let number: <#Type#>
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
    } expansion: {
      """
      struct S {
        @Binding @Init(default: 42) var number = 0

        internal init() {
        }
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
      @Binding @Init(default: 42) var number = 0
                     ┬──────────
                     ╰─ 🛑 Custom 'default' can't be applied to already initialized variable

      ✏️ Remove 'default: 42'
      @MemberwiseInit
      struct S {
        @Binding @Init var number = 0
      }

      ✏️ Remove '= 0'
      @MemberwiseInit
      struct S {
        @Binding @Init(default: 42) var number: Int
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
    } expansion: {
      """
      struct S {
        @Binding @Init(default: T.q) var number = T.t

        internal init() {
        }
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
      @Binding @Init(default: T.q) var number = T.t
                     ┬───────────
                     ╰─ 🛑 Custom 'default' can't be applied to already initialized variable

      ✏️ Remove 'default: T.q'
      @MemberwiseInit
      struct S {
        @Binding @Init var number = T.t
      }

      ✏️ Remove '= T.t'
      @MemberwiseInit
      struct S {
        @Binding @Init(default: T.q) var number: <#Type#>
      }
      """
    }
  }

  func testInitializedVarCustomLabel() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 42, label: "_") var number = 0
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 42, label: "_") var number = 0

        internal init() {
        }
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
      @Init(default: 42, label: "_") var number = 0
            ┬───────────
            ╰─ 🛑 Custom 'default' can't be applied to already initialized variable

      ✏️ Remove 'default: 42'
      @MemberwiseInit
      struct S {
        @Init(label: "_") var number = 0
      }

      ✏️ Remove '= 0'
      @MemberwiseInit
      struct S {
        @Init(default: 42, label: "_") var number: Int
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

        internal init() {
        }
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
      @Init(default: 42) let x, y: Int
            ┬──────────
            ╰─ 🛑 Custom 'default' can't be applied to multiple bindings

      ✏️ Remove '@Init(default: 42)'
      @MemberwiseInit
      struct S {
        let x, y: Int
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
    } expansion: {
      """
      struct S {
        @Init(default: 42) var x, y: Int

        internal init() {
        }
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
      @Init(default: 42) var x, y: Int
            ┬──────────
            ╰─ 🛑 Custom 'default' can't be applied to multiple bindings

      ✏️ Remove '@Init(default: 42)'
      @MemberwiseInit
      struct S {
        var x, y: Int
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
    } expansion: {
      """
      struct S {
        @Init(default: 42) let x = 0, y: Int

        internal init() {
        }
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
      @Init(default: 42) let x = 0, y: Int
            ┬──────────
            ╰─ 🛑 Custom 'default' can't be applied to multiple bindings

      ✏️ Remove '@Init(default: 42)'
      @MemberwiseInit
      struct S {
        let x = 0, y: Int
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
    } expansion: {
      """
      struct S {
        @Init(default: 42) var x = 0, y: Int

        internal init() {
        }
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
      @Init(default: 42) var x = 0, y: Int
            ┬──────────
            ╰─ 🛑 Custom 'default' can't be applied to multiple bindings

      ✏️ Remove '@Init(default: 42)'
      @MemberwiseInit
      struct S {
        var x = 0, y: Int
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
    } expansion: {
      """
      struct S {
        @Init(default: 42) let x: Int, isOn: Bool

        internal init() {
        }
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
      @Init(default: 42) let x: Int, isOn: Bool
            ┬──────────
            ╰─ 🛑 Custom 'default' can't be applied to multiple bindings

      ✏️ Remove '@Init(default: 42)'
      @MemberwiseInit
      struct S {
        let x: Int, isOn: Bool
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
