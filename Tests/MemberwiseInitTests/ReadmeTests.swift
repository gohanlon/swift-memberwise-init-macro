import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

final class ReadmeTests: XCTestCase {
  override func invokeTest() {
    // NB: Waiting for swift-macro-testing PR to support explicit indentationWidth: https://github.com/pointfreeco/swift-macro-testing/pull/8
    withMacroTesting(
      //indentationWidth: .spaces(2),
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "Init": InitMacro.self,
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
    assertMacro {
      """
      @MemberwiseInit
      struct CounterView: View {
        @InitWrapper(type: Binding<Bool>)
        @Binding var isOn: Bool

        var body: some View { EmptyView() }
      }
      """
    } expansion: {
      """
      struct CounterView: View {
        @InitWrapper(type: Binding<Bool>)
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
    assertMacro {
      """
      import SwiftUI

      @MemberwiseInit
      struct CounterView: View {
        @InitWrapper(type: Binding<Int>)
        @Binding var count: Int

        var body: some View { EmptyView() }
      }
      """
    } expansion: {
      """
      import SwiftUI
      struct CounterView: View {
        @InitWrapper(type: Binding<Int>)
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
      @_UncheckedMemberwiseInit(.internal)
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

        internal init(
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

  func testDeunderscoreParameterNames() {
    assertMacro {
      """
      @MemberwiseInit(.public, _deunderscoreParmeters: true)
      public struct Review {
        @Init(.public) private let _rating: Int

        public var rating: String {
          String(repeating: "⭐️", count: self._rating)
        }
      }
      """
    } expansion: {
      """
      public struct Review {
        private let _rating: Int

        public var rating: String {
          String(repeating: "⭐️", count: self._rating)
        }

        public init(
          _rating: Int
        ) {
          self._rating = _rating
        }
      }
      """
    }
  }

  func testOptionalsDefaultToNil() {
    assertMacro {
      """
      @MemberwiseInit(.public, _optionalsDefaultNil: true)
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

  func testTupleDestructuringNotSupported() {
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

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct Point2D {
        let (x, y): (Int, Int)
            ┬─────────────────
            ╰─ 🛑 @MemberwiseInit does not support tuple destructuring for property declarations. Use multiple declarations instead.
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
           ✏️ Add '@Init(.ignore)' and an initializer
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

      ✏️ Add '@Init(.ignore)' and an initializer
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
