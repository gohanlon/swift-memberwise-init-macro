import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

final class MemberwiseInitInferredTypeTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "Init": InitMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - Simple literals

  func testVarPropertyWithInitializer_NonInferrableType_FailsWithDiagnostic() {
    assertMacro {
      """
      let number = 0
      @MemberwiseInit
      public struct Pedometer {
        var stepsToday = number
      }
      """
    } expansion: {
      """
      let number = 0
      public struct Pedometer {
        var stepsToday = number

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      let number = 0
      @MemberwiseInit
      public struct Pedometer {
        var stepsToday = number
            ┬──────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  func testBooleanLiterals() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var boolTrue = true
        var boolFalse = false
      }
      """##
    } expansion: {
      """
      public struct S {
        var boolTrue = true
        var boolFalse = false

        internal init(
          boolTrue: Bool = true,
          boolFalse: Bool = false
        ) {
          self.boolTrue = boolTrue
          self.boolFalse = boolFalse
        }
      }
      """
    }
  }

  func testIntegerLiterals() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var int = 0
        var intBinary = 0b01010101
        var intOctal = 0o21
        var intHex = 0x1A
      }
      """##
    } expansion: {
      """
      public struct S {
        var int = 0
        var intBinary = 0b01010101
        var intOctal = 0o21
        var intHex = 0x1A

        internal init(
          int: Int = 0,
          intBinary: Int = 0b01010101,
          intOctal: Int = 0o21,
          intHex: Int = 0x1A
        ) {
          self.int = int
          self.intBinary = intBinary
          self.intOctal = intOctal
          self.intHex = intHex
        }
      }
      """
    }
  }

  // NB: Unannotated floating-point literals default to `Double` in Swift.
  func testFloatingPointLiterals() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var float = 0.0
        var floatExponential = 1.25e2
        var floatHex = 0xC.3p0
      }
      """##
    } expansion: {
      """
      public struct S {
        var float = 0.0
        var floatExponential = 1.25e2
        var floatHex = 0xC.3p0

        internal init(
          float: Double = 0.0,
          floatExponential: Double = 1.25e2,
          floatHex: Double = 0xC.3p0
        ) {
          self.float = float
          self.floatExponential = floatExponential
          self.floatHex = floatHex
        }
      }
      """
    }
  }

  func testStringLiterals() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var string1 = ""
        var string2 = """
          Multiline
          String
          """
        var string3 = #"""
          Raw
          Multiline
          String
          """#

        var stringWithQuotes = #"A "quoted" string"#

      }
      """##
    } expansion: {
      ##"""
      public struct S {
        var string1 = ""
        var string2 = """
          Multiline
          String
          """
        var string3 = #"""
          Raw
          Multiline
          String
          """#

        var stringWithQuotes = #"A "quoted" string"#

        internal init(
          string1: String = "",
          string2: String = """
              Multiline
              String
              """,
          string3: String = #"""
              Raw
              Multiline
              String
              """#,
          stringWithQuotes: String = #"A "quoted" string"#
        ) {
          self.string1 = string1
          self.string2 = string2
          self.string3 = string3
          self.stringWithQuotes = stringWithQuotes
        }

      }
      """##
    }
  }

  // NB: Explicit type takes precedence over the expression-inferred type.
  func testCharacterLiteral() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var char: Character = "A"
      }
      """##
    } expansion: {
      """
      public struct S {
        var char: Character = "A"

        internal init(
          char: Character = "A"
        ) {
          self.char = char
        }
      }
      """
    }
  }

  func testVarHavingTwoBindingsInitializedWithLiterals() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var a = "", b = 0
      }
      """##
    } expansion: {
      """
      public struct S {
        var a = "", b = 0

        internal init(
          a: String = "",
          b: Int = 0
        ) {
          self.a = a
          self.b = b
        }
      }
      """
    }
  }

  func testVarHavingTwoBindings_WithTypeAnnotationAndWithLiteral() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var a: String, b = 0
      }
      """##
    } expansion: {
      """
      public struct S {
        var a: String, b = 0

        internal init(
          a: String,
          b: Int = 0
        ) {
          self.a = a
          self.b = b
        }
      }
      """
    }
  }

  // NB: Compiler error: 'Type annotation missing in pattern'
  func testVarHavingTwoBindings_WithoutTypeAnnotationAndWithLiteral_NoExcessiveDiagnostic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var a, b = 0
      }
      """##
    } expansion: {
      """
      public struct S {
        var a, b = 0

        internal init(
          b: Int = 0
        ) {
          self.b = b
        }
      }
      """
    }
  }

  // MARK: - Simple `as` expressions

  func testVarPropertyWithInitializerAs() {
    assertMacro {
      """
      enum T { case foo }
      @MemberwiseInit
      public struct S {
        var value = .foo as T
      }
      """
    } expansion: {
      """
      enum T { case foo }
      public struct S {
        var value = .foo as T

        internal init(
          value: T = .foo as T
        ) {
          self.value = value
        }
      }
      """
    }
  }

  // NB: `x: Float = 1 as Float`: `as Float` is unnecessary (always?), but does no harm.
  func testVarPropertyHavingTwoBindingssWithInitializerAs() {
    assertMacro {
      """
      @MemberwiseInit
      public struct S {
        var x = 1 as Float, y = 2 as Float
      }
      """
    } expansion: {
      """
      public struct S {
        var x = 1 as Float, y = 2 as Float

        internal init(
          x: Float = 1 as Float,
          y: Float = 2 as Float
        ) {
          self.x = x
          self.y = y
        }
      }
      """
    }
  }

  // MARK: - Array expressions

  func testArrayLiteral() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var array = [1, 2, 3]
      }
      """##
    } expansion: {
      """
      public struct S {
        var array = [1, 2, 3]

        internal init(
          array: [Int] = [1, 2, 3]
        ) {
          self.array = array
        }
      }
      """
    }
  }

  func testArrayLiteralPromotedToDouble() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var array = [1, 2.0]
      }
      """##
    } expansion: {
      """
      public struct S {
        var array = [1, 2.0]

        internal init(
          array: [Double] = [1, 2.0]
        ) {
          self.array = array
        }
      }
      """
    }
  }

  func testArrayOfAsDouble() {
    assertMacro {
      ##"""
      @MemberwiseInit
      struct Q {
        var array = [1 as Double, 2 as Double]
      }
      """##
    } expansion: {
      """
      struct Q {
        var array = [1 as Double, 2 as Double]

        internal init(
          array: [Double] = [1 as Double, 2 as Double]
        ) {
          self.array = array
        }
      }
      """
    }
  }

  // FIXME: Diagnostic is excessive on already invalid syntax.
  func testArrayOfAsIntAndAsDouble_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      struct S {
        var array = [1 as Int, 2 as Double]
      }
      """##
    } expansion: {
      """
      struct S {
        var array = [1 as Int, 2 as Double]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        var array = [1 as Int, 2 as Double]
            ┬──────────────────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  func testNestedArrayLiteralPromotedToDouble() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var array = [[1, 2.0], [3.0, 4]]
      }
      """##
    } expansion: {
      """
      public struct S {
        var array = [[1, 2.0], [3.0, 4]]

        internal init(
          array: [[Double]] = [[1, 2.0], [3.0, 4]]
        ) {
          self.array = array
        }
      }
      """
    }
  }

  func testNonLiteralArray_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      let number = 2
      @MemberwiseInit
      public struct S {
        var array = [1, number, 3]
      }
      """##
    } expansion: {
      """
      let number = 2
      public struct S {
        var array = [1, number, 3]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      let number = 2
      @MemberwiseInit
      public struct S {
        var array = [1, number, 3]
            ┬─────────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  // NB: Xcode and SwiftSyntax prefer `[T] ()`, but swift-format prefers `[T]()`.
  // The node is copied unchanged from the property declaration and SwiftSyntax is adding trivia.
  func testArrayWithExplicitTypeInitializer() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var array = [String]()
      }
      """##
    } expansion: {
      """
      public struct S {
        var array = [String]()

        internal init(
          array: [String] = [String] ()
        ) {
          self.array = array
        }
      }
      """
    }
  }

  // FIXME: Diagnostic is excessive on already invalid syntax, but we can only detect special cases.
  func testRaggedLiteralArray_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var array = [1, "foo", 3]
      }
      """##
    } expansion: {
      """
      public struct S {
        var array = [1, "foo", 3]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      public struct S {
        var array = [1, "foo", 3]
            ┬────────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  func testRaggedLiteralArrayWithAsAny() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var array = [1, "foo", 3] as [Any]
      }
      """##
    } expansion: {
      """
      public struct S {
        var array = [1, "foo", 3] as [Any]

        internal init(
          array: [Any] = [1, "foo", 3] as [Any]
        ) {
          self.array = array
        }
      }
      """
    }
  }

  // MARK: - Dictionary expressions

  func testDictionaryLiteral() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var dictionary = ["key1": 1, "key2": 2]
      }
      """##
    } expansion: {
      """
      public struct S {
        var dictionary = ["key1": 1, "key2": 2]

        internal init(
          dictionary: [String: Int] = ["key1": 1, "key2": 2]
        ) {
          self.dictionary = dictionary
        }
      }
      """
    }
  }

  func testDictionary_LiteralKeysNonLiteralValues_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      let foo = "foo"
      let bar = "bar"
      @MemberwiseInit
      public struct S {
        var dictionary = ["key1": foo, "key2": bar]
      }
      """##
    } expansion: {
      """
      let foo = "foo"
      let bar = "bar"
      public struct S {
        var dictionary = ["key1": foo, "key2": bar]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      let foo = "foo"
      let bar = "bar"
      @MemberwiseInit
      public struct S {
        var dictionary = ["key1": foo, "key2": bar]
            ┬──────────────────────────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  func testDictionary_NonLiteralKeysLiteralValues_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      let bar = "bar"
      @MemberwiseInit
      public struct S {
        var dictionary = ["foo": 1, bar: 2]
      }
      """##
    } expansion: {
      """
      let bar = "bar"
      public struct S {
        var dictionary = ["foo": 1, bar: 2]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      let bar = "bar"
      @MemberwiseInit
      public struct S {
        var dictionary = ["foo": 1, bar: 2]
            ┬──────────────────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  func testDictionaryLiteralPromotedToDoubleDouble() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var dictionary = [1: 2.0, 3.0: 4]
      }
      """##
    } expansion: {
      """
      public struct S {
        var dictionary = [1: 2.0, 3.0: 4]

        internal init(
          dictionary: [Double: Double] = [1: 2.0, 3.0: 4]
        ) {
          self.dictionary = dictionary
        }
      }
      """
    }
  }

  func testDictionaryOfAsDoubleAsDouble() {
    assertMacro {
      ##"""
      @MemberwiseInit
      struct Q {
        var array = [1 as Double: 2 as Double]
      }
      """##
    } expansion: {
      """
      struct Q {
        var array = [1 as Double: 2 as Double]

        internal init(
          array: [Double: Double] = [1 as Double: 2 as Double]
        ) {
          self.array = array
        }
      }
      """
    }
  }

  // FIXME: Diagnostic is excessive on already invalid syntax.
  // Compiler error: Heterogeneous collection literal could only be inferred to '[AnyHashable : Double]'; add explicit type annotation if this is intentional
  func testDictionaryOfAsIntAndAsDoubleNotPromoted_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      struct S {
        var array = [1 as Int: 2 as Double, 1.0: 2]
      }
      """##
    } expansion: {
      """
      struct S {
        var array = [1 as Int: 2 as Double, 1.0: 2]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        var array = [1 as Int: 2 as Double, 1.0: 2]
            ┬──────────────────────────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  // NB: Xcode and SwiftSyntax prefer `[K : V] ()`, but swift-format prefers `[K : V]()`.
  // The node is copied unchanged from the property declaration and SwiftSyntax is adding trivia.
  // I tried detaching the syntax node, to no effect.
  func testDictionaryWithExplicitTypeInitializer() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var dictionary = [String: Int]()
      }
      """##
    } expansion: {
      """
      public struct S {
        var dictionary = [String: Int]()

        internal init(
          dictionary: [String: Int] = [String: Int] ()
        ) {
          self.dictionary = dictionary
        }
      }
      """
    }
  }

  // FIXME: Diagnostic is excessive on already invalid syntax.
  // Compiler error: Heterogeneous collection literal could only be inferred to '[AnyHashable : Any]'; add explicit type annotation if this is intentional
  func testRaggedLiteralDictionary_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var dictionary = ["foo": 1, 3: "bar"]
      }
      """##
    } expansion: {
      """
      public struct S {
        var dictionary = ["foo": 1, 3: "bar"]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      public struct S {
        var dictionary = ["foo": 1, 3: "bar"]
            ┬────────────────────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  func testRaggedLiteralDictionaryWithAsAnyHashableAny() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var dictionary = ["foo": 1, 3: "bar"] as [AnyHashable: Any]
      }
      """##
    } expansion: {
      """
      public struct S {
        var dictionary = ["foo": 1, 3: "bar"] as [AnyHashable: Any]

        internal init(
          dictionary: [AnyHashable: Any] = ["foo": 1, 3: "bar"] as [AnyHashable: Any]
        ) {
          self.dictionary = dictionary
        }
      }
      """
    }
  }

  // MARK: - Tuple expressions

  func testTupleLiteral() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var tuple = (1, "Hello", true)
      }
      """##
    } expansion: {
      """
      public struct S {
        var tuple = (1, "Hello", true)

        internal init(
          tuple: (Int, String, Bool) = (1, "Hello", true)
        ) {
          self.tuple = tuple
        }
      }
      """
    }
  }

  func testNonLiteralTuple_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      let name = "Blob"
      @MemberwiseInit
      public struct S {
        var tuple = (1, name, true)
      }
      """##
    } expansion: {
      """
      let name = "Blob"
      public struct S {
        var tuple = (1, name, true)

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      let name = "Blob"
      @MemberwiseInit
      public struct S {
        var tuple = (1, name, true)
            ┬──────────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  func testNonLiteralTupleAs() {
    assertMacro {
      ##"""
      let name = "Blob"
      @MemberwiseInit
      public struct S {
        var tuple = (1, name, true) as (Int, String, Bool)
      }
      """##
    } expansion: {
      """
      let name = "Blob"
      public struct S {
        var tuple = (1, name, true) as (Int, String, Bool)

        internal init(
          tuple: (Int, String, Bool) = (1, name, true) as (Int, String, Bool)
        ) {
          self.tuple = tuple
        }
      }
      """
    }
  }

  // MARK: - Nested expressions

  func testNestedArrayLiteral() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var array = [[1, 2], [20, 30]]
      }
      """##
    } expansion: {
      """
      public struct S {
        var array = [[1, 2], [20, 30]]

        internal init(
          array: [[Int]] = [[1, 2], [20, 30]]
        ) {
          self.array = array
        }
      }
      """
    }
  }

  func testNestedDictionaryLiteral() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var dictionary = ["key1": ["subkey1": 10], "key2": ["subkey2": 20]]
      }
      """##
    } expansion: {
      """
      public struct S {
        var dictionary = ["key1": ["subkey1": 10], "key2": ["subkey2": 20]]

        internal init(
          dictionary: [String: [String: Int]] = ["key1": ["subkey1": 10], "key2": ["subkey2": 20]]
        ) {
          self.dictionary = dictionary
        }
      }
      """
    }
  }

  func testNestedTupleLiteral() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var tuple = (1, ("Hello", true))
      }
      """##
    } expansion: {
      """
      public struct S {
        var tuple = (1, ("Hello", true))

        internal init(
          tuple: (Int, (String, Bool)) = (1, ("Hello", true))
        ) {
          self.tuple = tuple
        }
      }
      """
    }
  }

  // MARK: - Prefix operators

  func testPrefixOperators() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct PrefixOperatorStruct {
        var negatedInt = -5
        var notBool = !true
        var bitwiseNotInt = ~0b0011
      }
      """##
    } expansion: {
      """
      public struct PrefixOperatorStruct {
        var negatedInt = -5
        var notBool = !true
        var bitwiseNotInt = ~0b0011

        internal init(
          negatedInt: Int = -5,
          notBool: Bool = !true,
          bitwiseNotInt: Int = ~0b0011
        ) {
          self.negatedInt = negatedInt
          self.notBool = notBool
          self.bitwiseNotInt = bitwiseNotInt
        }
      }
      """
    }
  }

  // MARK: - Infix operators

  func testRangeLiteral() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var intClosedRange = 1...5
        var intHalfOpenRange = 1..<5
        var doubleClosedRange = 1.0...5.0
        var doubleHalfOpenRange = 1.0..<5.0
        var stringClosedRange = "a"..."z"
        var stringHalfOpenRange = "a"..<"z"
      }
      """##
    } expansion: {
      """
      public struct S {
        var intClosedRange = 1...5
        var intHalfOpenRange = 1..<5
        var doubleClosedRange = 1.0...5.0
        var doubleHalfOpenRange = 1.0..<5.0
        var stringClosedRange = "a"..."z"
        var stringHalfOpenRange = "a"..<"z"

        internal init(
          intClosedRange: ClosedRange<Int> = 1 ... 5,
          intHalfOpenRange: Range<Int> = 1 ..< 5,
          doubleClosedRange: ClosedRange<Double> = 1.0 ... 5.0,
          doubleHalfOpenRange: Range<Double> = 1.0 ..< 5.0,
          stringClosedRange: ClosedRange<String> = "a" ... "z",
          stringHalfOpenRange: Range<String> = "a" ..< "z"
        ) {
          self.intClosedRange = intClosedRange
          self.intHalfOpenRange = intHalfOpenRange
          self.doubleClosedRange = doubleClosedRange
          self.doubleHalfOpenRange = doubleHalfOpenRange
          self.stringClosedRange = stringClosedRange
          self.stringHalfOpenRange = stringHalfOpenRange
        }
      }
      """
    }
  }

  func testMixedRangeLiteralPromoted() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var closedRange = 1...5.0
        var halfOpenRange = 1.0..<5
      }
      """##
    } expansion: {
      """
      public struct S {
        var closedRange = 1...5.0
        var halfOpenRange = 1.0..<5

        internal init(
          closedRange: ClosedRange<Double> = 1 ... 5.0,
          halfOpenRange: Range<Double> = 1.0 ..< 5
        ) {
          self.closedRange = closedRange
          self.halfOpenRange = halfOpenRange
        }
      }
      """
    }
  }

  func testNonLiteralRange_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      let start = 0
      @MemberwiseInit
      public struct S {
        var range = start...5
      }
      """##
    } expansion: {
      """
      let start = 0
      public struct S {
        var range = start...5

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      let start = 0
      @MemberwiseInit
      public struct S {
        var range = start...5
            ┬────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  func testBitwiseInfixOpertors() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var bitwiseAnd = 0b1010 & 0b0101
        var bitwiseOr = 0b1010 | 0b0101
        var bitwiseXor = 0b1010 ^ 0b0101
        var leftShift = 1 << 2
        var rightShift = 4 >> 1
      }
      """##
    } expansion: {
      """
      public struct S {
        var bitwiseAnd = 0b1010 & 0b0101
        var bitwiseOr = 0b1010 | 0b0101
        var bitwiseXor = 0b1010 ^ 0b0101
        var leftShift = 1 << 2
        var rightShift = 4 >> 1

        internal init(
          bitwiseAnd: Int = 0b1010 & 0b0101,
          bitwiseOr: Int = 0b1010 | 0b0101,
          bitwiseXor: Int = 0b1010 ^ 0b0101,
          leftShift: Int = 1 << 2,
          rightShift: Int = 4 >> 1
        ) {
          self.bitwiseAnd = bitwiseAnd
          self.bitwiseOr = bitwiseOr
          self.bitwiseXor = bitwiseXor
          self.leftShift = leftShift
          self.rightShift = rightShift
        }
      }
      """
    }
  }

  // FIXME: Diagnostic is excessive on already invalid syntax.
  func testBitwiseInfixOpertorsWithNonInt_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var bitwiseAnd = 0b1010 & 1.0
      }
      """##
    } expansion: {
      """
      public struct S {
        var bitwiseAnd = 0b1010 & 1.0

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      public struct S {
        var bitwiseAnd = 0b1010 & 1.0
            ┬────────────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  func testBooleanInfixOperators() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var equalTo = 1 == 1
        var notEqualTo = 1 != 2
        var greaterThan = 3 > 2
        var lessThan = 2 < 3
        var greaterThanOrEqualTo = 3 >= 3
        var lessThanOrEqualTo = 2 <= 3
        var logicalAnd = true && false
        var logicalOr = false || true
      }
      """##
    } expansion: {
      """
      public struct S {
        var equalTo = 1 == 1
        var notEqualTo = 1 != 2
        var greaterThan = 3 > 2
        var lessThan = 2 < 3
        var greaterThanOrEqualTo = 3 >= 3
        var lessThanOrEqualTo = 2 <= 3
        var logicalAnd = true && false
        var logicalOr = false || true

        internal init(
          equalTo: Bool = 1 == 1,
          notEqualTo: Bool = 1 != 2,
          greaterThan: Bool = 3 > 2,
          lessThan: Bool = 2 < 3,
          greaterThanOrEqualTo: Bool = 3 >= 3,
          lessThanOrEqualTo: Bool = 2 <= 3,
          logicalAnd: Bool = true && false,
          logicalOr: Bool = false || true
        ) {
          self.equalTo = equalTo
          self.notEqualTo = notEqualTo
          self.greaterThan = greaterThan
          self.lessThan = lessThan
          self.greaterThanOrEqualTo = greaterThanOrEqualTo
          self.lessThanOrEqualTo = lessThanOrEqualTo
          self.logicalAnd = logicalAnd
          self.logicalOr = logicalOr
        }
      }
      """
    }
  }

  func testIntegerInfixArithmetic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var intPlus = 1 + 2
        var intMinus = 5 - 3
        var intTimes = 4 * 2
        var intDivide = 8 / 4
        var modulo = 10 % 3
      }
      """##
    } expansion: {
      """
      public struct S {
        var intPlus = 1 + 2
        var intMinus = 5 - 3
        var intTimes = 4 * 2
        var intDivide = 8 / 4
        var modulo = 10 % 3

        internal init(
          intPlus: Int = 1 + 2,
          intMinus: Int = 5 - 3,
          intTimes: Int = 4 * 2,
          intDivide: Int = 8 / 4,
          modulo: Int = 10 % 3
        ) {
          self.intPlus = intPlus
          self.intMinus = intMinus
          self.intTimes = intTimes
          self.intDivide = intDivide
          self.modulo = modulo
        }
      }
      """
    }
  }

  // FIXME: Diagnostic is excessive on already invalid syntax.
  func testModuloOpertorWithNonInt_FailsWithDiagnostic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var modulo = 10 % 3.0
      }
      """##
    } expansion: {
      """
      public struct S {
        var modulo = 10 % 3.0

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      public struct S {
        var modulo = 10 % 3.0
            ┬────────────────
            ╰─ 🛑 @MemberwiseInit requires a type annotation.
      }
      """
    }
  }

  // NB: Unannotated floating-point literals default to `Double` in Swift.
  func testFloatInfixArithmetic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var floatPlus = 1.0 + 2.0
        var floatMinus = 5.0 - 3.0
        var floatTimes = 4.0 * 2.0
        var floatDivide = 8.0 / 4.0
      }
      """##
    } expansion: {
      """
      public struct S {
        var floatPlus = 1.0 + 2.0
        var floatMinus = 5.0 - 3.0
        var floatTimes = 4.0 * 2.0
        var floatDivide = 8.0 / 4.0

        internal init(
          floatPlus: Double = 1.0 + 2.0,
          floatMinus: Double = 5.0 - 3.0,
          floatTimes: Double = 4.0 * 2.0,
          floatDivide: Double = 8.0 / 4.0
        ) {
          self.floatPlus = floatPlus
          self.floatMinus = floatMinus
          self.floatTimes = floatTimes
          self.floatDivide = floatDivide
        }
      }
      """
    }
  }

  func testMixedTypesInfixArithmetic() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var mixedPlus = 1.0 + 2
        var mixedMinus = 5 - 3.0
        var mixedTimes = 4 * 2.0
        var mixedDivide = 8.0 / 4
      }
      """##
    } expansion: {
      """
      public struct S {
        var mixedPlus = 1.0 + 2
        var mixedMinus = 5 - 3.0
        var mixedTimes = 4 * 2.0
        var mixedDivide = 8.0 / 4

        internal init(
          mixedPlus: Double = 1.0 + 2,
          mixedMinus: Double = 5 - 3.0,
          mixedTimes: Double = 4 * 2.0,
          mixedDivide: Double = 8.0 / 4
        ) {
          self.mixedPlus = mixedPlus
          self.mixedMinus = mixedMinus
          self.mixedTimes = mixedTimes
          self.mixedDivide = mixedDivide
        }
      }
      """
    }
  }

  func testIntegerInfixComparisons() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var intEquals = 1 == 2
        var intNotEquals = 1 != 2
        var intLessThan = 1 < 2
        var intLessThanOrEqual = 1 <= 2
        var intGreaterThan = 1 > 2
        var intGreaterThanOrEqual = 1 >= 2
      }
      """##
    } expansion: {
      """
      public struct S {
        var intEquals = 1 == 2
        var intNotEquals = 1 != 2
        var intLessThan = 1 < 2
        var intLessThanOrEqual = 1 <= 2
        var intGreaterThan = 1 > 2
        var intGreaterThanOrEqual = 1 >= 2

        internal init(
          intEquals: Bool = 1 == 2,
          intNotEquals: Bool = 1 != 2,
          intLessThan: Bool = 1 < 2,
          intLessThanOrEqual: Bool = 1 <= 2,
          intGreaterThan: Bool = 1 > 2,
          intGreaterThanOrEqual: Bool = 1 >= 2
        ) {
          self.intEquals = intEquals
          self.intNotEquals = intNotEquals
          self.intLessThan = intLessThan
          self.intLessThanOrEqual = intLessThanOrEqual
          self.intGreaterThan = intGreaterThan
          self.intGreaterThanOrEqual = intGreaterThanOrEqual
        }
      }
      """
    }
  }

  func testFloatInfixComparisons() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var floatEquals = 1.0 == 2.0
        var floatNotEquals = 1.0 != 2.0
        var floatLessThan = 1.0 < 2.0
        var floatLessThanOrEqual = 1.0 <= 2.0
        var floatGreaterThan = 1.0 > 2.0
        var floatGreaterThanOrEqual = 1.0 >= 2.0
      }
      """##
    } expansion: {
      """
      public struct S {
        var floatEquals = 1.0 == 2.0
        var floatNotEquals = 1.0 != 2.0
        var floatLessThan = 1.0 < 2.0
        var floatLessThanOrEqual = 1.0 <= 2.0
        var floatGreaterThan = 1.0 > 2.0
        var floatGreaterThanOrEqual = 1.0 >= 2.0

        internal init(
          floatEquals: Bool = 1.0 == 2.0,
          floatNotEquals: Bool = 1.0 != 2.0,
          floatLessThan: Bool = 1.0 < 2.0,
          floatLessThanOrEqual: Bool = 1.0 <= 2.0,
          floatGreaterThan: Bool = 1.0 > 2.0,
          floatGreaterThanOrEqual: Bool = 1.0 >= 2.0
        ) {
          self.floatEquals = floatEquals
          self.floatNotEquals = floatNotEquals
          self.floatLessThan = floatLessThan
          self.floatLessThanOrEqual = floatLessThanOrEqual
          self.floatGreaterThan = floatGreaterThan
          self.floatGreaterThanOrEqual = floatGreaterThanOrEqual
        }
      }
      """
    }
  }

  func testMixedTypesInfixComparisons() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        var mixedEquals = 1 == 1.0
        var mixedNotEquals = 1 != 1.0
        var mixedLessThan = 1 < 2.0
        var mixedLessThanOrEqual = 1 <= 2.0
        var mixedGreaterThan = 3 > 2.0
        var mixedGreaterThanOrEqual = 3 >= 2.0
      }
      """##
    } expansion: {
      """
      public struct S {
        var mixedEquals = 1 == 1.0
        var mixedNotEquals = 1 != 1.0
        var mixedLessThan = 1 < 2.0
        var mixedLessThanOrEqual = 1 <= 2.0
        var mixedGreaterThan = 3 > 2.0
        var mixedGreaterThanOrEqual = 3 >= 2.0

        internal init(
          mixedEquals: Bool = 1 == 1.0,
          mixedNotEquals: Bool = 1 != 1.0,
          mixedLessThan: Bool = 1 < 2.0,
          mixedLessThanOrEqual: Bool = 1 <= 2.0,
          mixedGreaterThan: Bool = 3 > 2.0,
          mixedGreaterThanOrEqual: Bool = 3 >= 2.0
        ) {
          self.mixedEquals = mixedEquals
          self.mixedNotEquals = mixedNotEquals
          self.mixedLessThan = mixedLessThan
          self.mixedLessThanOrEqual = mixedLessThanOrEqual
          self.mixedGreaterThan = mixedGreaterThan
          self.mixedGreaterThanOrEqual = mixedGreaterThanOrEqual
        }
      }
      """
    }
  }

  func testNestedInfix() {
    assertMacro {
      ##"""
      @MemberwiseInit
      public struct S {
        // Arithmetic expressions
        var sum = (1 + 2) + 3
        var mixedTypesSum = 1 + 2.0 + 3
        var complexArithmetic = (1 + 2) * (3 / 4) - 5.0

        // Comparison expressions
        var nestedComparison = (1 + 2) > (3 - 1)
        var complexComparison = (1.0 <= 2) && (3.0 == 3)

        // Boolean expressions
        var nestedBoolean = (true || false) && !(false)
        var complexBoolean = (1 > 2) || ((3 <= 4) && true)

        // Mixed expressions
        var mixedArithmeticComparison = (1 + 2) == 3
        var mixedArithmeticBoolean = ((1 + 2) > 3) && true
        var complexMixed = ((1 + 2) > 3) && ((4 <= 5) || (3 == 3))

        // Nested mixed expressions
        var nestedMixed = ((1 + 2) * 3) >= (4 / 2) && ((true || false) && !(false))
      }
      """##
    } expansion: {
      """
      public struct S {
        // Arithmetic expressions
        var sum = (1 + 2) + 3
        var mixedTypesSum = 1 + 2.0 + 3
        var complexArithmetic = (1 + 2) * (3 / 4) - 5.0

        // Comparison expressions
        var nestedComparison = (1 + 2) > (3 - 1)
        var complexComparison = (1.0 <= 2) && (3.0 == 3)

        // Boolean expressions
        var nestedBoolean = (true || false) && !(false)
        var complexBoolean = (1 > 2) || ((3 <= 4) && true)

        // Mixed expressions
        var mixedArithmeticComparison = (1 + 2) == 3
        var mixedArithmeticBoolean = ((1 + 2) > 3) && true
        var complexMixed = ((1 + 2) > 3) && ((4 <= 5) || (3 == 3))

        // Nested mixed expressions
        var nestedMixed = ((1 + 2) * 3) >= (4 / 2) && ((true || false) && !(false))

        internal init(
          sum: Int = (1 + 2) + 3,
          mixedTypesSum: Double = 1 + 2.0 + 3,
          complexArithmetic: Double = (1 + 2) * (3 / 4) - 5.0,
          nestedComparison: Bool = (1 + 2) > (3 - 1),
          complexComparison: Bool = (1.0 <= 2) && (3.0 == 3),
          nestedBoolean: Bool = (true || false) && !(false),
          complexBoolean: Bool = (1 > 2) || ((3 <= 4) && true),
          mixedArithmeticComparison: Bool = (1 + 2) == 3,
          mixedArithmeticBoolean: Bool = ((1 + 2) > 3) && true,
          complexMixed: Bool = ((1 + 2) > 3) && ((4 <= 5) || (3 == 3)),
          nestedMixed: Bool = ((1 + 2) * 3) >= (4 / 2) && ((true || false) && !(false))
        ) {
          self.sum = sum
          self.mixedTypesSum = mixedTypesSum
          self.complexArithmetic = complexArithmetic
          self.nestedComparison = nestedComparison
          self.complexComparison = complexComparison
          self.nestedBoolean = nestedBoolean
          self.complexBoolean = complexBoolean
          self.mixedArithmeticComparison = mixedArithmeticComparison
          self.mixedArithmeticBoolean = mixedArithmeticBoolean
          self.complexMixed = complexMixed
          self.nestedMixed = nestedMixed
        }
      }
      """
    }
  }

}
