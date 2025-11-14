import MacroTesting
import MemberwiseInitMacros
import XCTest

final class LayeredDiagnosticsTests: XCTestCase {
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

  func testInvalidLabelOnMultipleBindings() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "$foo") let x, y: T
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
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(default: 0, label: "$foo") private let x, y: T
                                         ┬──────
              │           │              ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
              │           │                 ✏️ Add '@Init(.public)'
              │           │                 ✏️ Replace 'private' access with 'public'
              │           │                 ✏️ Add '@Init(.ignore)' and an initializer
                          ┬────────────
              │           ╰─ 🛑 Custom 'label' can't be applied to multiple bindings
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to multiple bindings
                 ✏️ Remove 'default: 0'
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
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "foo") let x: T
        ┬───────────────────────────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and an initializer
        @Init(label: "foo") let y: T
        ┬───────────────────────────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(.public, label: "foo") let x: T
        @Init(.public, label: "foo") let y: T
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
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(label: "y") let x: T
        ┬─────────────────────────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and an initializer
        let y: T
        ┬───────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      @MemberwiseInit(.public)
      struct S {
        @Init(.public, label: "y") let x: T
        @Init(.public) let y: T
      }
      """
    }
  }
}
