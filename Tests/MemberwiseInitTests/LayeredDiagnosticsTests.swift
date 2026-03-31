import MacroTesting
import MemberwiseInitMacros
import XCTest

final class LayeredDiagnosticsTests: XCTestCase {
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

  func testInvalidLabelOnMultipleBindings() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "$foo") let x, y: T
      }
      """
    } expansion: {
      """
      struct S {
        @Init(label: "$foo") let x, y: T

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "$foo") let x, y: T
              ┬────────────
              ╰─ 🛑 Custom 'label' can't be applied to multiple bindings
      }
      """
    }
  }

  func testInvalidLabelAndDefaultOnMultipleBindings() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 0, label: "$foo") let x, y: T
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 0, label: "$foo") let x, y: T

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 0, label: "$foo") let x, y: T
                          ┬────────────
              │           ╰─ 🛑 Custom 'label' can't be applied to multiple bindings
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to multiple bindings
                 ✏️ Remove 'default: 0'
      }
      """
    } fixes: {
      """
      @Init(default: 0, label: "$foo") let x, y: T
            ┬──────────
            ╰─ 🛑 Custom 'default' can't be applied to multiple bindings

      ✏️ Remove 'default: 0'
      @MemberwiseInit
      struct S {
        @Init(label: "$foo") let x, y: T
      }
      """
    }
  }

  func testAccessLeakCustomDefaultAndInvalidLabelOnMultipleBindings() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(default: 0, label: "$foo") private let x, y: T
      }
      """
    } expansion: {
      """
      struct S {
        @Init(default: 0, label: "$foo") private let x, y: T

        public init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(default: 0, label: "$foo") private let x, y: T
                                         ┬──────
              │           │              ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
              │           │                 ✏️ Add '@Init(.public)'
              │           │                 ✏️ Replace 'private' access with 'public'
              │           │                 ✏️ Add '@Init(.ignore)' and a default value
                          ┬────────────
              │           ╰─ 🛑 Custom 'label' can't be applied to multiple bindings
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to multiple bindings
                 ✏️ Remove 'default: 0'
      }
      """
    } fixes: {
      """
      @Init(default: 0, label: "$foo") private let x, y: T
            ┬──────────
            ╰─ 🛑 Custom 'default' can't be applied to multiple bindings

      ✏️ Remove 'default: 0'
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "$foo") private let x, y: T
      }

      @Init(default: 0, label: "$foo") private let x, y: T
                                       ┬──────
                                       ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      struct S {
        @Init(.public, default: 0, label: "$foo") private let x, y: T
      }

      ✏️ Replace 'private' access with 'public'
      @MemberwiseInit(.public)
      struct S {
        @Init(default: 0, label: "$foo") public let x, y: T
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit(.public)
      struct S {
        @Init(.ignore) private let x = <#value#>, y: T = <#value#>
      }
      """
    }
  }

  func testAccessLeakAndCustomLabelConflictsWithAnotherLabel() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "foo") let x: T
        @Init(label: "foo") let y: T
      }
      """
    } expansion: {
      """
      struct S {
        @Init(label: "foo") let x: T
        @Init(label: "foo") let y: T

        public init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "foo") let x: T
        ┬───────────────────────────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and a default value
        @Init(label: "foo") let y: T
        ┬───────────────────────────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @Init(label: "foo") let x: T
      ┬───────────────────────────
      ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      struct S {
        @Init(.public, label: "foo") let x: T
        @Init(label: "foo") let y: T
      }

      ✏️ Add 'public' access level
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "foo") public let x: T
        @Init(label: "foo") let y: T
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit(.public)
      struct S {
        @Init(.ignore) let x: T = <#value#>
        @Init(label: "foo") let y: T
      }

      @Init(label: "foo") let y: T
      ┬───────────────────────────
      ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "foo") let x: T
        @Init(.public, label: "foo") let y: T
      }

      ✏️ Add 'public' access level
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "foo") let x: T
        @Init(label: "foo") public let y: T
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "foo") let x: T
        @Init(.ignore) let y: T = <#value#>
      }
      """
    }
  }

  func testAccessLeakAndCustomLabelConflictsWithPropertyName() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "y") let x: T
        let y: T
      }
      """
    } expansion: {
      """
      struct S {
        @Init(label: "y") let x: T
        let y: T

        public init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "y") let x: T
        ┬─────────────────────────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and a default value
        let y: T
        ┬───────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @Init(label: "y") let x: T
      ┬─────────────────────────
      ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      struct S {
        @Init(.public, label: "y") let x: T
        let y: T
      }

      ✏️ Add 'public' access level
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "y") public let x: T
        let y: T
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit(.public)
      struct S {
        @Init(.ignore) let x: T = <#value#>
        let y: T
      }

      let y: T
      ┬───────
      ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "y") let x: T
        @Init(.public) let y: T
      }

      ✏️ Add 'public' access level
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "y") let x: T
        public let y: T
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "y") let x: T
        @Init(.ignore) let y: T = <#value#>
      }
      """
    }
  }
}
