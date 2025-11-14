import MacroTesting
import MemberwiseInitMacros
import XCTest

final class CustomInitTests: XCTestCase {
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

  // TODO: For 1.0, diagnostic error on nonsensical @Init
  func testInitializedLet() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init let number = 42
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init let number = 42
        ┬────
        ╰─ ⚠️ @Init can't be applied to already initialized constant
           ✏️ Remove '@Init'
           ✏️ Remove '= 42'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        let number = 42
      }
      """
    } expansion: {
      """
      struct S {
        let number = 42

        internal init() {
        }
      }
      """
    }
  }

  // TODO: For 1.0, diagnostic error on nonsensical @Init. While getter-only computed properties are
  // nonsensical, setter computed properties could be allowed, and perhaps also computed properties with init accessor?
  // TODO: For 0.3.0, diagnostic warning on nonsensical @Init?
  func testComputedProperty() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        var number: Int
        @Init var computed: Int { number * 2 }
      }
      """
    } expansion: {
      """
      struct S {
        var number: Int
        @Init var computed: Int { number * 2 }

        internal init(
          number: Int
        ) {
          self.number = number
        }
      }
      """
    }
  }

  // TODO: For 1.0, diagnostic error on nonsensical @Init
  func testStaticProperty() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init static var staticNumber: Int
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init static var staticNumber: Int
              ┬─────
              ╰─ ⚠️ @Init can't be applied to 'static' members
                 ✏️ Remove '@Init'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        static var staticNumber: Int
      }
      """
    } expansion: {
      """
      struct S {
        static var staticNumber: Int

        internal init() {
        }
      }
      """
    }
  }

  // TODO: For 1.0, diagnostic error on nonsensical @Init
  func testLazyProperty() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 0) lazy var lazyNumber: Int = {
          return 2 * 2
        }()
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(default: 0) lazy var lazyNumber: Int = {
                          ┬───
                          ╰─ ⚠️ @Init can't be applied to 'lazy' members
                             ✏️ Remove '@Init(default: 0)'
          return 2 * 2
        }()
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct S {
        lazy var lazyNumber: Int = {
          return 2 * 2
        }()
      }
      """
    } expansion: {
      """
      struct S {
        lazy var lazyNumber: Int = {
          return 2 * 2
        }()

        internal init() {
        }
      }
      """
    }
  }

  // NB: 'lazy static' is redundant and a compiler error: "'lazy' cannot be used on an already-lazy
  // global". Since the fix is to "Remove 'lazy '", @MemberwiseInit emits its diagnostic on
  // 'static' which is still a mistake to apply @Init to.
  func testLazyStaticProperty() {
    assertMacro {
      """
      @MemberwiseInit
      struct B {
        @Init lazy static var value = 0
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct B {
        @Init lazy static var value = 0
                   ┬─────
                   ╰─ ⚠️ @Init can't be applied to 'static' members
                      ✏️ Remove '@Init'
      }
      """
    } fixes: {
      """
      @MemberwiseInit
      struct B {
        lazy static var value = 0
      }
      """
    } expansion: {
      """
      struct B {
        lazy static var value = 0

        internal init() {
        }
      }
      """
    }
  }
}
