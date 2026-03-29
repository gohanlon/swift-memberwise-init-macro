import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

final class ReadmeTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      indentationWidth: .spaces(2),
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "Init": InitMacro.self,
        "InitWrapper": InitMacro.self,
        "_UncheckedMemberwiseInit": UncheckedMemberwiseInitMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  func testPrivateMakesMacroEmitError() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        private var age: Int? = nil
      }
      """
    } expansion: {
      """
      public struct Person {
        public let name: String
        private var age: Int? = nil

        public init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        private var age: Int? = nil
        ┬──────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
           ✏️ Add '@Init(.public)'
           ✏️ Replace 'private' access with 'public'
           ✏️ Add '@Init(.ignore)'
      }
      """
    } fixes: {
      """
      private var age: Int? = nil
      ┬──────
      ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        @Init(.public) private var age: Int? = nil
      }

      ✏️ Replace 'private' access with 'public'
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        public var age: Int? = nil
      }

      ✏️ Add '@Init(.ignore)'
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        @Init(.ignore) private var age: Int? = nil
      }
      """
    }
  }

  func testIgnoreAge() {
    #if canImport(SwiftSyntax600)
      assertMacro {
        """
          @MemberwiseInit(.public)
          public struct Person {
            public let name: String
            @Init(.ignore) private var age: Int? = nil
          }
        """
      } expansion: {
        """
          public struct Person {
            public let name: String
            private var age: Int? = nil

            public init(
              name: String
            ) {
              self.name = name
            }
          }
        """
      }
    #else
      assertMacro {
        """
          @MemberwiseInit(.public)
          public struct Person {
            public let name: String
            @Init(.ignore) private var age: Int? = nil
          }
        """
      } expansion: {
        """
          
          public struct Person {
            public let name: String
            private var age: Int? = nil

          public init(
            name: String
          ) {
            self.name = name
          }
          }
        """
      }
    #endif
  }

  func testExposeAgePublically() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        @Init(.public) private var age: Int? = nil
      }
      """
    } expansion: {
      """
      public struct Person {
        public let name: String
        private var age: Int? = nil

        public init(
          name: String,
          age: Int? = nil
        ) {
          self.name = name
          self.age = age
        }
      }
      """
    }
  }

  func testBinding() {
    #if canImport(SwiftSyntax600)
      assertMacro {
        """
        @MemberwiseInit
        struct CounterView: View {
          @InitWrapper(type: Binding<Bool>.self)
          @Binding var isOn: Bool

          var body: some View { EmptyView() }
        }
        """
      } expansion: {
        """
        struct CounterView: View {
          @Binding var isOn: Bool

          var body: some View { EmptyView() }

          internal init(
            isOn: Binding<Bool>
          ) {
            self._isOn = isOn
          }
        }
        """
      }
    #else
      assertMacro {
        """
        @MemberwiseInit
        struct CounterView: View {
          @InitWrapper(type: Binding<Bool>.self)
          @Binding var isOn: Bool

          var body: some View { EmptyView() }
        }
        """
      } expansion: {
        """
        struct CounterView: View {
          @Binding 
          var isOn: Bool

          var body: some View { EmptyView() }

          internal init(
            isOn: Binding<Bool>
          ) {
            self._isOn = isOn
          }
        }
        """
      }
    #endif
  }

  func testLabelessParmeters() {
    assertMacro {
      """
      @MemberwiseInit
      struct Point2D {
        @Init(label: "_") let x: Int
        @Init(label: "_") let y: Int
      }
      """
    } expansion: {
      """
      struct Point2D {
        let x: Int
        let y: Int

        internal init(
          _ x: Int,
          _ y: Int
        ) {
          self.x = x
          self.y = y
        }
      }
      """
    }
  }

  func testCustomParameterLabels() {
    assertMacro {
      """
      @MemberwiseInit
      struct Receipt {
        @Init(label: "for") let item: String
      }
      """
    } expansion: {
      """
      struct Receipt {
        let item: String

        internal init(
          for item: String
        ) {
          self.item = item
        }
      }
      """
    }
  }

  func testInferTypeFromPropertyInitializationExpressions() {
    assertMacro {
      """
      @MemberwiseInit
      struct Example {
        var count = 0  // 👈 `Int` is inferred
      }
      """
    } expansion: {
      """
      struct Example {
        var count = 0  // 👈 `Int` is inferred

        internal init(
          count: Int = 0
        ) {
          self.count = count
        }
      }
      """
    }
  }

  func testInferTypeFromPropertyInitializationExpressionsComprehensive() {
    assertMacro {
      """
      @MemberwiseInit
      public struct Example<T: CaseIterable> {
        var string = "", int = 0
        var boolTrue = true

        var mixedDivide = 8.0 / 4  // Double
        var halfOpenRange = 1.0..<5  // Range<Double>

        var arrayTypeInit = [T]()
        var arrayIntLiteral = [1, 2, 3]
        var arrayPromoted = [1, 2.0]  // [Double]
        var nestedArray = [[1, 2], [20, 30]]  // [[Int]]

        var dictionaryTypeInit = [String: T]()
        var dictionaryLiteral = ["key1": 1, "key2": 2]
        var dictionaryPromoted = [1: 2.0, 3.0: 4]  // [Double: Double]
        var nestedDictionary = ["key1": ["subkey1": 10], "key2": ["subkey2": 20]]  // [String: [String: Int]]

        var tuple = (1, ("Hello", true))
        var value = T.allCases.first as T?

        var nestedMixed = ((1 + 2) * 3) >= (4 / 2) && ((true || false) && !(false))  // Bool

        var bitwiseAnd = 0b1010 & 0b0101
        var leftShift = 1 << 2
        var bitwiseNotInt = ~0b0011

        var intBinary = 0b01010101
        var intOctal = 0o21
        var intHex = 0x1A
        var floatExponential = 1.25e2  // Double
        var floatHex = 0xC.3p0  // Double

        var arrayAs = [1, "foo", 3] as [Any]
        var dictionaryAs = ["foo": 1, 3: "bar"] as [AnyHashable: Any]
      }
      """
    } expansion: {
      """
      public struct Example<T: CaseIterable> {
        var string = "", int = 0
        var boolTrue = true

        var mixedDivide = 8.0 / 4  // Double
        var halfOpenRange = 1.0..<5  // Range<Double>

        var arrayTypeInit = [T]()
        var arrayIntLiteral = [1, 2, 3]
        var arrayPromoted = [1, 2.0]  // [Double]
        var nestedArray = [[1, 2], [20, 30]]  // [[Int]]

        var dictionaryTypeInit = [String: T]()
        var dictionaryLiteral = ["key1": 1, "key2": 2]
        var dictionaryPromoted = [1: 2.0, 3.0: 4]  // [Double: Double]
        var nestedDictionary = ["key1": ["subkey1": 10], "key2": ["subkey2": 20]]  // [String: [String: Int]]

        var tuple = (1, ("Hello", true))
        var value = T.allCases.first as T?

        var nestedMixed = ((1 + 2) * 3) >= (4 / 2) && ((true || false) && !(false))  // Bool

        var bitwiseAnd = 0b1010 & 0b0101
        var leftShift = 1 << 2
        var bitwiseNotInt = ~0b0011

        var intBinary = 0b01010101
        var intOctal = 0o21
        var intHex = 0x1A
        var floatExponential = 1.25e2  // Double
        var floatHex = 0xC.3p0  // Double

        var arrayAs = [1, "foo", 3] as [Any]
        var dictionaryAs = ["foo": 1, 3: "bar"] as [AnyHashable: Any]

        internal init(
          string: String = "",
          int: Int = 0,
          boolTrue: Bool = true,
          mixedDivide: Double = 8.0 / 4,
          halfOpenRange: Range<Double> = 1.0 ..< 5,
          arrayTypeInit: [T] = [T](),
          arrayIntLiteral: [Int] = [1, 2, 3],
          arrayPromoted: [Double] = [1, 2.0],
          nestedArray: [[Int]] = [[1, 2], [20, 30]],
          dictionaryTypeInit: [String: T] = [String: T](),
          dictionaryLiteral: [String: Int] = ["key1": 1, "key2": 2],
          dictionaryPromoted: [Double: Double] = [1: 2.0, 3.0: 4],
          nestedDictionary: [String: [String: Int]] = ["key1": ["subkey1": 10], "key2": ["subkey2": 20]],
          tuple: (Int, (String, Bool)) = (1, ("Hello", true)),
          value: T? = T.allCases.first as T?,
          nestedMixed: Bool = ((1 + 2) * 3) >= (4 / 2) && ((true || false) && !(false)),
          bitwiseAnd: Int = 0b1010 & 0b0101,
          leftShift: Int = 1 << 2,
          bitwiseNotInt: Int = ~0b0011,
          intBinary: Int = 0b01010101,
          intOctal: Int = 0o21,
          intHex: Int = 0x1A,
          floatExponential: Double = 1.25e2,
          floatHex: Double = 0xC.3p0,
          arrayAs: [Any] = [1, "foo", 3] as [Any],
          dictionaryAs: [AnyHashable: Any] = ["foo": 1, 3: "bar"] as [AnyHashable: Any]
        ) {
          self.string = string
          self.int = int
          self.boolTrue = boolTrue
          self.mixedDivide = mixedDivide
          self.halfOpenRange = halfOpenRange
          self.arrayTypeInit = arrayTypeInit
          self.arrayIntLiteral = arrayIntLiteral
          self.arrayPromoted = arrayPromoted
          self.nestedArray = nestedArray
          self.dictionaryTypeInit = dictionaryTypeInit
          self.dictionaryLiteral = dictionaryLiteral
          self.dictionaryPromoted = dictionaryPromoted
          self.nestedDictionary = nestedDictionary
          self.tuple = tuple
          self.value = value
          self.nestedMixed = nestedMixed
          self.bitwiseAnd = bitwiseAnd
          self.leftShift = leftShift
          self.bitwiseNotInt = bitwiseNotInt
          self.intBinary = intBinary
          self.intOctal = intOctal
          self.intHex = intHex
          self.floatExponential = floatExponential
          self.floatHex = floatHex
          self.arrayAs = arrayAs
          self.dictionaryAs = dictionaryAs
        }
      }
      """
    }
  }

  func testDefaultValues() {
    assertMacro {
      """
      @MemberwiseInit
      struct UserSettings {
        var theme = "Light"
        var notificationsEnabled = true
      }
      """
    } expansion: {
      """
      struct UserSettings {
        var theme = "Light"
        var notificationsEnabled = true

        internal init(
          theme: String = "Light",
          notificationsEnabled: Bool = true
        ) {
          self.theme = theme
          self.notificationsEnabled = notificationsEnabled
        }
      }
      """
    }

    assertMacro {
      """
      @MemberwiseInit
      struct ButtonStyle {
        @Init(default: Color.blue) let backgroundColor: Color
        @Init(default: Font.system(size: 16)) let font: Font
      }
      """
    } expansion: {
      """
      struct ButtonStyle {
        let backgroundColor: Color
        let font: Font

        internal init(
          backgroundColor: Color = Color.blue,
          font: Font = Font.system(size: 16)
        ) {
          self.backgroundColor = backgroundColor
          self.font = font
        }
      }
      """
    }
  }

  func testExplicitlyIgnoreProperties() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        @Init(.ignore) private var age: Int? = nil  // 👈 Ignored and given a default value
      }
      """
    } expansion: {
      """
      public struct Person {
        public let name: String
        private var age: Int? = nil  // 👈 Ignored and given a default value

        public init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  func testAttributedPropertiesAreIgnoredByDefault() {
    assertMacro {
      """
      import SwiftUI
      @MemberwiseInit(.internal)  // 👈
      struct MyView: View {
        @State var isOn: Bool

        var body: some View { EmptyView() }
      }
      """
    } expansion: {
      """
      import SwiftUI
      // 👈
      struct MyView: View {
        @State var isOn: Bool

        var body: some View { EmptyView() }

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      import SwiftUI
      @MemberwiseInit(.internal)  // 👈
      struct MyView: View {
        @State var isOn: Bool
        ┬────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@State' attribute
           ✏️ Add '@Init(.ignore)' and a default value
           ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)

        var body: some View { EmptyView() }
      }
      """
    } fixes: {
      """
      @State var isOn: Bool
      ┬────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@State' attribute

      ✏️ Add '@Init(.ignore)' and a default value
      import SwiftUI
      @MemberwiseInit(.internal)  // 👈
      struct MyView: View {
        @Init(.ignore)

        @State var isOn: Bool = <#value#>

        var body: some View { EmptyView() }
      }

      ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)
      import SwiftUI
      @MemberwiseInit(.internal)  // 👈
      struct MyView: View {
        @Init

        @State var isOn: Bool

        var body: some View { EmptyView() }
      }
      """
    }

    assertMacro {
      """
      import SwiftUI
      @MemberwiseInit(. internal)
      struct MyView: View {
        @State var isOn: Bool = false  // 👈 Default value provided

        var body: some View { EmptyView() }
      }
      """
    } expansion: {
      """
      import SwiftUI
      struct MyView: View {
        @State var isOn: Bool = false  // 👈 Default value provided

        var body: some View { EmptyView() }

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      import SwiftUI
      @MemberwiseInit(. internal)
      struct MyView: View {
        @State var isOn: Bool = false  // 👈 Default value provided
        ┬────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@State' attribute
           ✏️ Add '@Init(.ignore)'
           ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)

        var body: some View { EmptyView() }
      }
      """
    } fixes: {
      """
      @State var isOn: Bool = false  // 👈 Default value provided
      ┬────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@State' attribute

      ✏️ Add '@Init(.ignore)'
      import SwiftUI
      @MemberwiseInit(. internal)
      struct MyView: View {
        @Init(.ignore)

        @State var isOn: Bool = false  // 👈 Default value provided

        var body: some View { EmptyView() }
      }

      ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)
      import SwiftUI
      @MemberwiseInit(. internal)
      struct MyView: View {
        @Init

        @State var isOn: Bool = false  // 👈 Default value provided

        var body: some View { EmptyView() }
      }
      """
    }

    #if canImport(SwiftSyntax600)
      assertMacro {
        """
        import SwiftUI
        @MemberwiseInit(.internal)
        struct MyView: View {
          @Init @State var isOn: Bool  // 👈 `@Init`

          var body: some View { EmptyView() }
        }
        """
      } expansion: {
        """
        import SwiftUI
        struct MyView: View {
          @State var isOn: Bool  // 👈 `@Init`

          var body: some View { EmptyView() }

          internal init(
            isOn: Bool
          ) {
            self.isOn = isOn
          }
        }
        """
      }
    #else
      assertMacro {
        """
        import SwiftUI
        @MemberwiseInit(.internal)
        struct MyView: View {
          @Init @State var isOn: Bool  // 👈 `@Init`

          var body: some View { EmptyView() }
        }
        """
      } expansion: {
        """
        import SwiftUI
        struct MyView: View {@State 
          var isOn: Bool  // 👈 `@Init`

          var body: some View { EmptyView() }

          internal init(
            isOn: Bool
          ) {
            self.isOn = isOn
          }
        }
        """
      }
    #endif
  }

  func testSupportForPropertyWrappers() {
    #if canImport(SwiftSyntax600)
      assertMacro {
        """
        import SwiftUI

        @MemberwiseInit
        struct CounterView: View {
          @InitWrapper(type: Binding<Int>.self)
          @Binding var count: Int

          var body: some View { EmptyView() }
        }
        """
      } expansion: {
        """
        import SwiftUI
        struct CounterView: View {
          @Binding var count: Int

          var body: some View { EmptyView() }

          internal init(
            count: Binding<Int>
          ) {
            self._count = count
          }
        }
        """
      }
    #else
      assertMacro {
        """
        import SwiftUI

        @MemberwiseInit
        struct CounterView: View {
          @InitWrapper(type: Binding<Int>.self)
          @Binding var count: Int

          var body: some View { EmptyView() }
        }
        """
      } expansion: {
        """
        import SwiftUI
        struct CounterView: View {
          @Binding 
          var count: Int

          var body: some View { EmptyView() }

          internal init(
            count: Binding<Int>
          ) {
            self._count = count
          }
        }
        """
      }
    #endif
  }

  func testAutomaticEscapingForClosureTypes() {
    assertMacro {
      """
      @MemberwiseInit  // 👈
      public struct TaskRunner {
        public let onCompletion: () -> Void
      }
      """
    } expansion: {
      """
      // 👈
      public struct TaskRunner {
        public let onCompletion: () -> Void

        internal init(
          onCompletion: @escaping () -> Void
        ) {
          self.onCompletion = onCompletion
        }
      }
      """
    }

    assertMacro {
      """
      @MemberwiseInit(.public)  // 👈 `.public`
      public struct TaskRunner {
        public let onCompletion: () -> Void
      }
      """
    } expansion: {
      """
      // 👈 `.public`
      public struct TaskRunner {
        public let onCompletion: () -> Void

        public init(
          onCompletion: @escaping () -> Void
        ) {
          self.onCompletion = onCompletion
        }
      }
      """
    }

    assertMacro {
      """
      public typealias CompletionHandler = @Sendable () -> Void

      @MemberwiseInit(.public)
      public struct TaskRunner: Sendable {
        @Init(escaping: true) public let onCompletion: CompletionHandler  // 👈
      }
      """
    } expansion: {
      """
      public typealias CompletionHandler = @Sendable () -> Void
      public struct TaskRunner: Sendable {
        public let onCompletion: CompletionHandler  // 👈

        public init(
          onCompletion: @escaping CompletionHandler
        ) {
          self.onCompletion = onCompletion
        }
      }
      """
    }
  }

  func testUncheckedMemberwiseInit() {
    assertMacro {
      """
      @_UncheckedMemberwiseInit(.public)
      public struct APIResponse: Codable {
        public let id: String
        @Monitored internal var statusCode: Int
        private var rawResponse: Data

        // Computed properties and methods...
      }
      """
    } expansion: {
      """
      public struct APIResponse: Codable {
        public let id: String
        @Monitored internal var statusCode: Int
        private var rawResponse: Data

        public init(
          id: String,
          statusCode: Int,
          rawResponse: Data
        ) {
          self.id = id
          self.statusCode = statusCode
          self.rawResponse = rawResponse
        }

        // Computed properties and methods...
      }
      """
    }
  }

  func testOptionalsRequireExplicitArgument() {
    assertMacro {
      """
      @MemberwiseInit
      struct User {
        let id: Int
        let name: String?
      }
      """
    } expansion: {
      """
      struct User {
        let id: Int
        let name: String?

        internal init(
          id: Int,
          name: String?
        ) {
          self.id = id
          self.name = name
        }
      }
      """
    }
  }

  func testOptionalsDefaultToNil() {
    assertMacro {
      """
      @MemberwiseInit(.public, optionalsDefaultNil: true)
      public struct User: Codable {
        public let id: Int
        public let name: String?
        public let email: String?
        public let address: String?
      }
      """
    } expansion: {
      """
      public struct User: Codable {
        public let id: Int
        public let name: String?
        public let email: String?
        public let address: String?

        public init(
          id: Int,
          name: String? = nil,
          email: String? = nil,
          address: String? = nil
        ) {
          self.id = id
          self.name = name
          self.email = email
          self.address = address
        }
      }
      """
    }
  }

  func testExplicitNilOnVarProperty() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct User {
        public var name: String? = nil  // 👈 explicit initializer
      }
      """
    } expansion: {
      """
      public struct User {
        public var name: String? = nil  // 👈 explicit initializer

        public init(
          name: String? = nil
        ) {
          self.name = name
        }
      }
      """
    }
  }

  func testTupleDestructuring() {
    assertMacro {
      """
      @MemberwiseInit
      struct Point2D {
        let (x, y): (Int, Int)
      }
      """
    } expansion: {
      """
      struct Point2D {
        let (x, y): (Int, Int)

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
  }

  func testTupleDestructuringWithDefaults() {
    assertMacro {
      """
      @MemberwiseInit
      struct Point2D {
        var (x, y): (Int, Int) = (0, 0)
      }
      """
    } expansion: {
      """
      struct Point2D {
        var (x, y): (Int, Int) = (0, 0)

        internal init(
          x: Int = 0,
          y: Int = 0
        ) {
          self.x = x
          self.y = y
        }
      }
      """
    }
  }

  func testBackground() {
    assertMacro {
      """
      @MemberwiseInit  // 👈
      public struct Person {
        public let name: String
      }
      """
    } expansion: {
      """
      // 👈
      public struct Person {
        public let name: String

        internal init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    }

    assertMacro {
      """
      @MemberwiseInit(.public)  // 👈 `.public`
      public struct Person {
        public let name: String
      }
      """
    } expansion: {
      """
      // 👈 `.public`
      public struct Person {
        public let name: String

        public init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    }

    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        private var age: Int?  // 👈 `private`
      }
      """
    } expansion: {
      """
      public struct Person {
        public let name: String
        private var age: Int?  // 👈 `private`

        public init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        private var age: Int?  // 👈 `private`
        ┬──────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
           ✏️ Add '@Init(.public)'
           ✏️ Replace 'private' access with 'public'
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      private var age: Int?  // 👈 `private`
      ┬──────
      ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        @Init(.public) private var age: Int?  // 👈 `private`
      }

      ✏️ Replace 'private' access with 'public'
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        public var age: Int?  // 👈 `private`
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        @Init(.ignore) private var age: Int?  // 👈 `private` = <#value#>
      }
      """
    }

    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        @Init(.public) private var age: Int?  // 👈 `@Init(.public)`
      }
      """
    } expansion: {
      """
      public struct Person {
        public let name: String
        private var age: Int?  // 👈 `@Init(.public)`

        public init(
          name: String,
          age: Int?
        ) {
          self.name = name
          self.age = age
        }
      }
      """
    }

    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        @Init(.public) private var age: Int? = nil  // 👈 Default value
      }
      """
    } expansion: {
      """
      public struct Person {
        public let name: String
        private var age: Int? = nil  // 👈 Default value

        public init(
          name: String,
          age: Int? = nil
        ) {
          self.name = name
          self.age = age
        }
      }
      """
    }

    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let name: String
        @Init(.ignore) private var age: Int? = nil  // 👈 `.ignore`
      }
      """
    } expansion: {
      """
      public struct Person {
        public let name: String
        private var age: Int? = nil  // 👈 `.ignore`

        public init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }
}
