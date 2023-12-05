import MacroTesting
import MemberwiseInitMacros
import XCTest

final class LayeredDiagnosticsTests: XCTestCase {
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
                          ┬────────────
              │           ╰─ 🛑 Custom 'label' can't be applied to multiple bindings
              ┬──────────
              ╰─ 🛑 Custom 'default' can't be applied to multiple bindings
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
        @Init(label: "foo") let y: T
        ┬───────────────────────────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
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
        let y: T
        ┬───────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
      }
      """
    }
  }
}
