import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

final class UncheckedMemberwiseInitTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      indentationWidth: .spaces(2),
      record: .missing,
      macros: [
        "_UncheckedMemberwiseInit": UncheckedMemberwiseInitMacro.self
      ]
    ) {
      super.invokeTest()
    }
  }

  func testBasicStruct() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.internal)
      struct S {
        var number: Int
        let text: String
      }
      """
    } expansion: {
      """
      struct S {
        var number: Int
        let text: String

        internal init(
          number: Int,
          text: String
        ) {
          self.number = number
          self.text = text
        }
      }
      """
    }
  }

  func testClassWithAccessLevels() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.public)
      class C {
        private var privateVar: Int
        public let publicLet: String
        var defaultVar: Double
      }
      """
    } expansion: {
      """
      class C {
        private var privateVar: Int
        public let publicLet: String
        var defaultVar: Double

        public init(
          privateVar: Int,
          publicLet: String,
          defaultVar: Double
        ) {
          self.privateVar = privateVar
          self.publicLet = publicLet
          self.defaultVar = defaultVar
        }
      }
      """
    }
  }

  func testActorWithComputedProperties() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.internal)
      actor A {
        var storedProperty: Int
        let constant: String
        var computedProperty: Double {
          get { return Double(storedProperty) }
        }
      }
      """
    } expansion: {
      """
      actor A {
        var storedProperty: Int
        let constant: String
        var computedProperty: Double {
          get { return Double(storedProperty) }
        }

        internal init(
          storedProperty: Int,
          constant: String
        ) {
          self.storedProperty = storedProperty
          self.constant = constant
        }
      }
      """
    }
  }

  func testStructWithStaticAndLazyProperties() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.fileprivate)
      struct S {
        var normal: Int
        static var staticVar: String = ""
        lazy var lazyVar: Double = 0.0
      }
      """
    } expansion: {
      """
      struct S {
        var normal: Int
        static var staticVar: String = ""
        lazy var lazyVar: Double = 0.0

        fileprivate init(
          normal: Int
        ) {
          self.normal = normal
        }
      }
      """
    }
  }

  func testStructWithOptionals() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.internal, _optionalsDefaultNil: true)
      struct S {
        var optionalInt: Int?
        var optionalString: String?
        var nonOptional: Double
      }
      """
    } expansion: {
      """
      struct S {
        var optionalInt: Int?
        var optionalString: String?
        var nonOptional: Double

        internal init(
          optionalInt: Int? = nil,
          optionalString: String? = nil,
          nonOptional: Double
        ) {
          self.optionalInt = optionalInt
          self.optionalString = optionalString
          self.nonOptional = nonOptional
        }
      }
      """
    }
  }

  func testStructWithDeunderscoreParameters() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.internal, _deunderscoreParameters: true)
      struct S {
        var _internalName: String
        var normalName: Int
      }
      """
    } expansion: {
      """
      struct S {
        var _internalName: String
        var normalName: Int

        internal init(
          internalName: String,
          normalName: Int
        ) {
          self._internalName = internalName
          self.normalName = normalName
        }
      }
      """
    }
  }

  func testDefaultAccessLevelWhenMissing() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit
      struct S {
        var value: Int
      }
      """
    } expansion: {
      """
      struct S {
        var value: Int

        internal init(
          value: Int
        ) {
          self.value = value
        }
      }
      """
    }
  }

  func testInferredTypeFromInitializer() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit
      struct S {
        var inferred = 42
        var explicit: Double = 3.14
      }
      """
    } expansion: {
      """
      struct S {
        var inferred = 42
        var explicit: Double = 3.14

        internal init(
          inferred: Int = 42,
          explicit: Double = 3.14
        ) {
          self.inferred = inferred
          self.explicit = explicit
        }
      }
      """
    }
  }

  func testErrorOnInvalidDeclaration() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.internal)
      enum E {
        case a, b, c
      }
      """
    } diagnostics: {
      """
      @_UncheckedMemberwiseInit(.internal)
      ┬───────────────────────────────────
      ╰─ 🛑 @_UncheckedMemberwiseInit can only be attached to a struct, class, or actor; not to an enum.
      enum E {
        case a, b, c
      }
      """
    }
  }

  func testInitIgnore() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.public)
      struct S {
        @Init(.ignore) var ignored: Int = 42
        var normal: String
      }
      """
    } expansion: {
      """
      struct S {
        @Init(.ignore) var ignored: Int = 42
        var normal: String

        public init(
          normal: String
        ) {
          self.normal = normal
        }
      }
      """
    }
  }

  func testInitLabel() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.public)
      struct S {
        @Init(label: "_") var name: String
      }
      """
    } expansion: {
      """
      struct S {
        @Init(label: "_") var name: String

        public init(
          _ name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  func testInitInternalOnPrivateProperty() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.public)
      struct S {
        @Init(.internal) private var internalProperty: Int
        var publicProperty: String
      }
      """
    } expansion: {
      """
      struct S {
        @Init(.internal) private var internalProperty: Int
        var publicProperty: String

        public init(
          internalProperty: Int,
          publicProperty: String
        ) {
          self.internalProperty = internalProperty
          self.publicProperty = publicProperty
        }
      }
      """
    }
  }

  // NB: Unlike `@MemberwiseInit`, `@_UncheckedMemberwiseInit` naively includes attributed properties by default
  func testWithPropertyWrapper() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.public)
      struct S {
        @Clamping(0...100) var percentage: Int
      }
      """
    } expansion: {
      """
      struct S {
        @Clamping(0...100) var percentage: Int

        public init(
          percentage: Int
        ) {
          self.percentage = percentage
        }
      }
      """
    }
  }

  func testWithInitIgnoreAndDefaultValue() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.public)
      struct S {
        @Init(.ignore) var ignored: Int = 42
        var normal: String
        var withDefault: Double = 3.14
      }
      """
    } expansion: {
      """
      struct S {
        @Init(.ignore) var ignored: Int = 42
        var normal: String
        var withDefault: Double = 3.14

        public init(
          normal: String,
          withDefault: Double = 3.14
        ) {
          self.normal = normal
          self.withDefault = withDefault
        }
      }
      """
    }
  }

  func testEscaping() {
    assertMacro {
      """
      public typealias CompletionHandler = () -> Void

      @_UncheckedMemberwiseInit
      struct APIRequest: Sendable {
       let onSuccess: (Data) -> Void
       let onFailure: @MainActor @Sendable (Error) -> Void
       @Init(escaping: true) var customEscaping: CompletionHandler
      }
      """
    } expansion: {
      """
      public typealias CompletionHandler = () -> Void
      struct APIRequest: Sendable {
       let onSuccess: (Data) -> Void
       let onFailure: @MainActor @Sendable (Error) -> Void
       @Init(escaping: true) var customEscaping: CompletionHandler

        internal init(
          onSuccess: @escaping (Data) -> Void,
          onFailure: @escaping @MainActor @Sendable (Error) -> Void,
          customEscaping: @escaping CompletionHandler
        ) {
          self.onSuccess = onSuccess
          self.onFailure = onFailure
          self.customEscaping = customEscaping
        }
      }
      """
    }
  }
}
