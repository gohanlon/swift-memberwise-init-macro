import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class MemberwiseInitDeprecationTests: XCTestCase {
  override func invokeTest() {
    // NB: Waiting for swift-macro-testing PR to support explicit indentationWidth: https://github.com/pointfreeco/swift-macro-testing/pull/8
    withMacroTesting(
      //indentationWidth: .spaces(2),
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "_UncheckedMemberwiseInit": UncheckedMemberwiseInitMacro.self,
        "Init": InitMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - _deunderscoreParameters deprecation

  // Deprecated; remove in 1.0
  func testDeunderscoreParametersTrue() {
    assertMacro {
      """
      @MemberwiseInit(_deunderscoreParameters: true)
      struct S {
        let _value: Int
      }
      """
    } expansion: {
      """
      struct S {
        let _value: Int

        internal init(
          value: Int
        ) {
          self._value = value
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(_deunderscoreParameters: true)
                      ┬────────────────────────────
                      ╰─ ⚠️ _deunderscoreParameters is deprecated; use @Init(label:) on individual properties instead
      struct S {
        let _value: Int
      }
      """
    }
  }

  // Deprecated; remove in 1.0
  func testDeunderscoreParametersFalse() {
    assertMacro {
      """
      @MemberwiseInit(_deunderscoreParameters: false)
      struct S {
        let _value: Int
      }
      """
    } expansion: {
      """
      struct S {
        let _value: Int

        internal init(
          _value: Int
        ) {
          self._value = _value
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(_deunderscoreParameters: false)
                      ┬─────────────────────────────
                      ╰─ ⚠️ _deunderscoreParameters is deprecated; use @Init(label:) on individual properties instead
      struct S {
        let _value: Int
      }
      """
    }
  }

  // Deprecated; remove in 1.0
  func testDeunderscoreParametersUncheckedMacro() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(_deunderscoreParameters: true)
      struct S {
        let _value: Int
      }
      """
    } expansion: {
      """
      struct S {
        let _value: Int

        internal init(
          value: Int
        ) {
          self._value = value
        }
      }
      """
    } diagnostics: {
      """
      @_UncheckedMemberwiseInit(_deunderscoreParameters: true)
                                ┬────────────────────────────
                                ╰─ ⚠️ _deunderscoreParameters is deprecated; use @Init(label:) on individual properties instead
      struct S {
        let _value: Int
      }
      """
    }
  }

}
