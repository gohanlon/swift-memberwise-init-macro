import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

// TODO: Cover valid `open` usages (on class and member decl).
// TODO: Warn when `@Init(.private) is applied to reduce access, e.g. `public let v: T`?

final class MemberwiseInitTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      indentationWidth: .spaces(2),
      record: .missing,
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "Init": InitMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - Test simple usage

  // NB: Redundant to AccessLevelTests but handy to have here, too.
  func testEmptyStruct() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
      }
      """
    } expansion: {
      """
      struct Person {

          internal init() {
          }
      }
      """
    }
  }

  // NB: Redundant to AccessLevelTests but handy to have here, too.
  func testEmptyPublicStruct() {
    assertMacro {
      """
      @MemberwiseInit
      public struct Person {
      }
      """
    } expansion: {
      """
      public struct Person {

          internal init() {
          }
      }
      """
    }
  }

  // NB: Redundant to AccessLevelTests but handy to have here, too.
  func testLetProperty() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let name: String
      }
      """
    } expansion: {
      """
      struct Person {
        let name: String

        internal init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  // MARK: - Test assignment variations

  func testVarProperty() {
    assertMacro {
      """
      @MemberwiseInit
      struct Pedometer {
        var stepsToday: Int
      }
      """
    } expansion: {
      """
      struct Pedometer {
        var stepsToday: Int

        internal init(
          stepsToday: Int
        ) {
          self.stepsToday = stepsToday
        }
      }
      """
    }
  }

  func testLetWithInitializer_IsIgnored() {
    assertMacro {
      """
      @MemberwiseInit
      public struct Earth {
        private let radiusInMiles: Float = 3958.8
      }
      """
    } expansion: {
      """
      public struct Earth {
        private let radiusInMiles: Float = 3958.8

        internal init() {
        }
      }
      """
    }
  }

  func testInitOnLetWithInitializer_WarnsAndIgnored() {
    assertMacro {
      """
      @MemberwiseInit
      struct Earth {
        @Init let name = "Earth"
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct Earth {
        @Init let name = "Earth"
        ┬────
        ╰─ ⚠️ @Init can't be applied to already initialized constant
           ✏️ Remove '@Init'
           ✏️ Remove '= "Earth"'
      }
      """
    } fixes: {
      """
      @Init let name = "Earth"
      ┬────
      ╰─ ⚠️ @Init can't be applied to already initialized constant

      ✏️ Remove '@Init'
      @MemberwiseInit
      struct Earth {
        let name = "Earth"
      }

      ✏️ Remove '= "Earth"'
      @MemberwiseInit
      struct Earth {
        @Init let name: String
      }
      """
    } expansion: {
      """
      struct Earth {
        let name = "Earth"
      
        internal init() {
        }
      }
      """
    }
  }

  func testVarWithInitializer_IsIncludedWithDefaultValue() {
    assertMacro {
      """
      @MemberwiseInit
      struct Pedometer {
        var stepsToday: Int = 0
      }
      """
    } expansion: {
      """
      struct Pedometer {
        var stepsToday: Int = 0

        internal init(
          stepsToday: Int = 0
        ) {
          self.stepsToday = stepsToday
        }
      }
      """
    }
  }

  func testInlineCommentOnProperty() {
    assertMacro {
      """
      @MemberwiseInit
      struct Pedometer {
        let stepsToday: Int // number of steps taken today
      }
      """
    } expansion: {
      """
      struct Pedometer {
        let stepsToday: Int // number of steps taken today

        internal init(
          stepsToday: Int
        ) {
          self.stepsToday = stepsToday
        }
      }
      """
    }
  }

  // MARK: - Test automatic @escaping

  func testAutomaticEscaping() {
    assertMacro {
      """
      @MemberwiseInit
      struct APIRequest: Sendable {
        let onSuccess: (Data) -> Void
        let onFailure: @MainActor @Sendable (Error) -> Void
      }
      """
    } expansion: {
      """
      struct APIRequest: Sendable {
        let onSuccess: (Data) -> Void
        let onFailure: @MainActor @Sendable (Error) -> Void

        internal init(
          onSuccess: @escaping (Data) -> Void,
          onFailure: @escaping @MainActor @Sendable (Error) -> Void
        ) {
          self.onSuccess = onSuccess
          self.onFailure = onFailure
        }
      }
      """
    }
  }

  // MARK: - Test binding variations

  func testLetHavingTwoBindings() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let firstName: String, lastName: String
      }
      """
    } expansion: {
      """
      struct Person {
        let firstName: String, lastName: String

        internal init(
          firstName: String,
          lastName: String
        ) {
          self.firstName = firstName
          self.lastName = lastName
        }
      }
      """
    }
  }

  func testLetHavingTwoBindingsWhereFirstInitialized() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let firstName: String = "", lastName: String
      }
      """
    } expansion: {
      """
      struct Person {
        let firstName: String = "", lastName: String

        internal init(
          lastName: String
        ) {
          self.lastName = lastName
        }
      }
      """
    }
  }

  func testLetHavingTwoBindingsWhereFirstInitializedWithoutExplicitType() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let firstName = "", lastName: String
      }
      """
    } expansion: {
      """
      struct Person {
        let firstName = "", lastName: String

        internal init(
          lastName: String
        ) {
          self.lastName = lastName
        }
      }
      """
    }
  }

  func testLetHavingTwoBindingsWhereFirstLacksExplicitType() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let firstName, lastName: String
      }
      """
    } expansion: {
      """
      struct Person {
        let firstName, lastName: String

        internal init(
          firstName: String,
          lastName: String
        ) {
          self.firstName = firstName
          self.lastName = lastName
        }
      }
      """
    }
  }

  func testLetHavingTwoBindingsWhereLastInitialized() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let firstName: String, lastName: String = ""
      }
      """
    } expansion: {
      """
      struct Person {
        let firstName: String, lastName: String = ""

        internal init(
          firstName: String
        ) {
          self.firstName = firstName
        }
      }
      """
    }
  }

  func testLetHavingThreeBindingsWhereMiddleLacksExplicitType() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let name: String, age, favoriteNumber: Int
      }
      """
    } expansion: {
      """
      struct Person {
        let name: String, age, favoriteNumber: Int

        internal init(
          name: String,
          age: Int,
          favoriteNumber: Int
        ) {
          self.name = name
          self.age = age
          self.favoriteNumber = favoriteNumber
        }
      }
      """
    }
  }

  func testLetHavingThreeBindingsWhereOnlyLastHasFunctionTypeAnnotation_AllEscaping() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let say, whisper, yell: () -> Void
      }
      """
    } expansion: {
      """
      struct Person {
        let say, whisper, yell: () -> Void

        internal init(
          say: @escaping () -> Void,
          whisper: @escaping () -> Void,
          yell: @escaping () -> Void
        ) {
          self.say = say
          self.whisper = whisper
          self.yell = yell
        }
      }
      """
    }
  }

  // MARK: - Test destructured tuples

  // TODO: @MemberwiseInit should support tuple destructuring for property declarations
  //  func testLetDestructuredTupleWithoutInitializer() {
  //    assertMacro {
  //      """
  //      @MemberwiseInit
  //      struct Point2D {
  //        let (x, y): (Int, Int)
  //      }
  //      """
  //    } expansion: {
  //      """
  //      struct Point2D {
  //        let (x, y): (Int, Int)
  //
  //        internal init(
  //          x: Int,
  //          y: Int
  //        ) {
  //          self.x = x
  //          self.y = y
  //        }
  //      }
  //      """
  //    }
  //  }

  // NB: @MemberwiseInit does not support tuple destructuring for property declarations, but
  // already initialized `let` properties are ignored, so the tuple can be ignored.
  func testLetDestructuredTupleWithInitializer() {
    assertMacro {
      """
      @MemberwiseInit
      struct Point2D {
        let (defaultX, defaultY): (Int, Int) = (0, 0)
      }
      """
    } expansion: {
      """
      struct Point2D {
        let (defaultX, defaultY): (Int, Int) = (0, 0)

        internal init() {
        }
      }
      """
    }
  }

  func testLetDestructuredTupleWithoutInitializer_FailsNotSupported() {
    assertMacro {
      """
      @MemberwiseInit
      struct Point2D {
        let (x, y): (Int, Int)
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
    } expansion: {
      """
      struct Point2D {
        let (x, y): (Int, Int)
      
        internal init() {
        }
      }
      """
    }
  }

  func testVarDestructuredTupleWithInitializer_FailsNotSupported() {
    assertMacro {
      """
      @MemberwiseInit
      struct Point2D {
        var (x, y): (Int, Int) = (0, 0)
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct Point2D {
        var (x, y): (Int, Int) = (0, 0)
            ┬──────────────────────────
            ╰─ 🛑 @MemberwiseInit does not support tuple destructuring for property declarations. Use multiple declarations instead.
      }
      """
    } expansion: {
      """
      struct Point2D {
        var (x, y): (Int, Int) = (0, 0)
      
        internal init() {
        }
      }
      """
    }
  }

  // MARK: - Test enum and extension

  func testAppliedToEnum_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      enum Action {
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      ┬──────────────
      ╰─ 🛑 @MemberwiseInit can only be attached to a struct, class, or actor; not to an enum.
      enum Action {
      }
      """
    }
  }

  func testAppliedToExtension_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      extension Int {
        var isGoodNumber: Bool {
          true
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      ┬──────────────
      ╰─ 🛑 @MemberwiseInit can only be attached to a struct, class, or actor; not to an extension.
      extension Int {
        var isGoodNumber: Bool {
          true
        }
      }
      """
    }
  }

  // MARK: - Test computed properties

  func testComputedProperty_IsIgnored() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        private var hasGoodFavoriteNumber: Bool {
          true
        }
      }
      """
    } expansion: {
      """
      struct Person {
        private var hasGoodFavoriteNumber: Bool {
          true
        }

        internal init() {
        }
      }
      """
    }
  }

  func testGetterOnlyComputedProperty_IsIgnored() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        var name: String {
          get {
            return "John Doe"
          }
        }
      }
      """
    } expansion: {
      """
      struct Person {
        var name: String {
          get {
            return "John Doe"
          }
        }

        internal init() {
        }
      }
      """
    }
  }

  func testGetterSetterComputedProperty_IsIgnored() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        var firstName: String
        var lastName: String
        var fullName: String {
          get {
            return "\\(firstName) \\(lastName)"
          }
          set {
            let nameParts = newValue.split(separator: " ")
            firstName = String(nameParts[0])
            lastName = String(nameParts[1])
          }
        }
      }
      """
    } expansion: {
      #"""
      struct Person {
        var firstName: String
        var lastName: String
        var fullName: String {
          get {
            return "\(firstName) \(lastName)"
          }
          set {
            let nameParts = newValue.split(separator: " ")
            firstName = String(nameParts[0])
            lastName = String(nameParts[1])
          }
        }

        internal init(
          firstName: String,
          lastName: String
        ) {
          self.firstName = firstName
          self.lastName = lastName
        }
      }
      """#
    }
  }

  // MARK: - Test annotations and attributes

  func testMacroAdjacentAttribute() {
    assertMacro {
      """
      @MemberwiseInit @available(iOS 15, *)
      struct Person {
        let name: String
      }
      """
    } expansion: {
      """
      @available(iOS 15, *)
      struct Person {
        let name: String

        internal init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  func testPropertyWithAttribute_IsIgnored() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct MyView {
        @State private var isOn: Bool
      }
      """
    } expansion: {
      """
      public struct MyView {
        @State private var isOn: Bool

        public init() {
        }
      }
      """
    }
  }

  // NB: Separating attributes on multiple lines to work around peculiar SwiftSyntaxMacroExpansion
  // trivia handling.
  // Waiting for: https://github.com/apple/swift-syntax/pull/2215
  func testPropertyWithInitAndAttribute_IsIncluded() {
    assertMacro {
      """
      @MemberwiseInit
      struct MyView {
        @Init
        @State
        var isOn: Bool
      }
      """
    } expansion: {
      """
      struct MyView {
        @State
        var isOn: Bool

        internal init(
          isOn: Bool
        ) {
          self.isOn = isOn
        }
      }
      """
    }
  }

  // NB: Separating attributes on multiple lines to work around peculiar SwiftSyntaxMacroExpansion
  // trivia handling.
  // Waiting for: https://github.com/apple/swift-syntax/pull/2215
  func testPropertyWithAttributeAndInit_IsIncluded() {
    assertMacro {
      """
      @MemberwiseInit
      struct MyView {
        @State
        @Init
        var isOn: Bool
      }
      """
    } expansion: {
      """
      struct MyView {
        @State
        var isOn: Bool

        internal init(
          isOn: Bool
        ) {
          self.isOn = isOn
        }
      }
      """
    }
  }

  // NB: Separating attributes on multiple lines to work around peculiar SwiftSyntaxMacroExpansion
  // trivia handling.
  // Waiting for: https://github.com/apple/swift-syntax/pull/2215
  func testPropertyWithAttributeAndInitArgs_IsIncludedArgsApplied() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      struct MyView {
        @State
        @Init(.public)
        var isOn: Bool
      }
      """
    } expansion: {
      """
      struct MyView {
        @State
        var isOn: Bool

        public init(
          isOn: Bool
        ) {
          self.isOn = isOn
        }
      }
      """
    }
  }

  // NB: Separating attributes on multiple lines to work around peculiar SwiftSyntaxMacroExpansion
  // trivia handling.
  // Waiting for: https://github.com/apple/swift-syntax/pull/2215
  func testPropertyWithInitEmptyParensAndAttribute_IsIncluded() {
    assertMacro {
      """
      @MemberwiseInit
      struct MyView {
        @Init()
        @State
        var isOn: Bool
      }
      """
    } expansion: {
      """
      struct MyView {
        @State
        var isOn: Bool

        internal init(
          isOn: Bool
        ) {
          self.isOn = isOn
        }
      }
      """
    }
  }

  func
    testMemberwiseInitInternalOnPublicStruct_InitPublicEscapingOnPrivateProperty_InternalInitEscaping()
  {
    assertMacro {
      """
      @MemberwiseInit(.internal)
      public struct Person {
        @Init(.public, escaping: true) private let name: String
      }
      """
    } expansion: {
      """
      public struct Person {
        private let name: String

        internal init(
          name: @escaping String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  func testInitAndInit_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init @Init
        let value: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init @Init
              ┬────
              ╰─ 🛑 Multiple @Init configurations are not supported by @MemberwiseInit
        let value: T
      }
      """
    } expansion: {
      """
      struct S {
      
        let value: T
      
        internal init() {
        }
      }
      """
    }
  }

  func testInitInitWrapperInitRaw_FailsWithDiagnostics() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init @InitWrapper @InitRaw
        let value: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init @InitWrapper @InitRaw
                           ┬───────
              │            ╰─ 🛑 Multiple @Init configurations are not supported by @MemberwiseInit
              ┬───────────
              ╰─ 🛑 Multiple @Init configurations are not supported by @MemberwiseInit
        let value: T
      }
      """
    } expansion: {
      """
      struct S {
        @InitWrapper @InitRaw
        let value: T
      
        internal init() {
        }
      }
      """
    }
  }

  // MARK: - Test invalid syntax

  func testInvalidLetProperty_NoExcessiveDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let name
      }
      """
    } expansion: {
      """
      struct Person {
        let name

        internal init() {
        }
      }
      """
    }
  }

  func testInvalidVarProperty_NoExcessiveDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        var name
      }
      """
    } expansion: {
      """
      struct Person {
        var name

        internal init() {
        }
      }
      """
    }
  }

  // MARK: - Test init access level

  func testInitAccessLevelBaseline_MatchesAnnotationTarget() {
    assertMacro {
      """
      @MemberwiseInit
      private struct Person {
      }

      @MemberwiseInit
      fileprivate struct Person {
      }

      @MemberwiseInit
      struct Person {
      }

      @MemberwiseInit
      internal struct Person {
      }

      @MemberwiseInit
      package struct Person {
      }

      @MemberwiseInit
      public struct Person {
      }

      @MemberwiseInit
      open class Person {
      }
      """
    } expansion: {
      """
      private struct Person {

          internal init() {
          }
      }
      fileprivate struct Person {

          internal init() {
          }
      }
      struct Person {

          internal init() {
          }
      }
      internal struct Person {

          internal init() {
          }
      }
      package struct Person {

          internal init() {
          }
      }
      public struct Person {

          internal init() {
          }
      }
      open class Person {

          internal init() {
          }
      }
      """
    }
  }

  // NB: This is almost covered by the exhaustive AccessLevelTests. This test touches on all the
  // access levels (instead of a meaningful few).
  func testDefaultInitAccessLevels_FailsWithDiagnotics() {
    assertMacro {
      """
      @MemberwiseInit
      private struct Person {
        private let name: String
      }

      @MemberwiseInit
      fileprivate struct Person {
        private let name: String
      }

      @MemberwiseInit
      struct Person {
        fileprivate let name: String
      }

      @MemberwiseInit
      internal struct Person {
        fileprivate let name: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      private struct Person {
        private let name: String
        ┬──────
        ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property
           ✏️ Add '@Init(.internal)'
           ✏️ Replace 'private' access with 'internal'
           ✏️ Add '@Init(.ignore)' and an initializer
      }

      @MemberwiseInit
      fileprivate struct Person {
        private let name: String
        ┬──────
        ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property
           ✏️ Add '@Init(.internal)'
           ✏️ Replace 'private' access with 'internal'
           ✏️ Add '@Init(.ignore)' and an initializer
      }

      @MemberwiseInit
      struct Person {
        fileprivate let name: String
        ┬──────────
        ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'fileprivate' property
           ✏️ Add '@Init(.internal)'
           ✏️ Replace 'fileprivate' access with 'internal'
           ✏️ Add '@Init(.ignore)' and an initializer
      }

      @MemberwiseInit
      internal struct Person {
        fileprivate let name: String
        ┬──────────
        ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'fileprivate' property
           ✏️ Add '@Init(.internal)'
           ✏️ Replace 'fileprivate' access with 'internal'
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } expansion: {
      """
      private struct Person {
        private let name: String
      
        internal init() {
        }
      }
      fileprivate struct Person {
        private let name: String
      
        internal init() {
        }
      }
      struct Person {
        fileprivate let name: String
      
        internal init() {
        }
      }
      internal struct Person {
        fileprivate let name: String
      
        internal init() {
        }
      }
      """
    }
  }

  func testDefaultInitAccessLevels() {
    assertMacro {
      """
      @MemberwiseInit
      package struct Person {
        let name: String
      }

      @MemberwiseInit
      public struct Person {
        let name: String
      }

      @MemberwiseInit
      open class Person {
        public var name: String
      }
      """
    } expansion: {
      """
      package struct Person {
        let name: String

        internal init(
          name: String
        ) {
          self.name = name
        }
      }
      public struct Person {
        let name: String

        internal init(
          name: String
        ) {
          self.name = name
        }
      }
      open class Person {
        public var name: String

        internal init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  func
    testMemberwiseInitPublic_PublicStruct_PublicAndImplicitlyInternalProperties_FailsWithDiagnostic()
  {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public var firstName = "Foo"
        var lastName: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public var firstName = "Foo"
        var lastName: String
        ┬───────────────────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      var lastName: String
      ┬───────────────────
      ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      public struct Person {
        public var firstName = "Foo"
        @Init(.public) var lastName: String
      }

      ✏️ Add 'public' access level
      @MemberwiseInit(.public)
      public struct Person {
        public var firstName = "Foo"
        public var lastName: String
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit(.public)
      public struct Person {
        public var firstName = "Foo"
        @Init(.ignore) var lastName: String = <#value#>
      }
      """
    } expansion: {
      """
      public struct Person {
        public var firstName = "Foo"
        var lastName: String
      
        public init(
          firstName: String = "Foo"
        ) {
          self.firstName = firstName
        }
      }
      """
    }
  }

  func testMemberwiseInitPackage_PublicStruct_PublicProperty_PackageInit() {
    assertMacro {
      """
      @MemberwiseInit(.package)
      public struct Person {
        public let firstName: String
      }
      """
    } expansion: {
      """
      public struct Person {
        public let firstName: String

        package init(
          firstName: String
        ) {
          self.firstName = firstName
        }
      }
      """
    }
  }

  func testPublicStruct_PublicAndFileprivateProperty_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        fileprivate let lastName: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        fileprivate let lastName: String
        ┬──────────
        ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'fileprivate' property
           ✏️ Add '@Init(.internal)'
           ✏️ Replace 'fileprivate' access with 'internal'
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      fileprivate let lastName: String
      ┬──────────
      ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'fileprivate' property

      ✏️ Add '@Init(.internal)'
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        @Init(.internal) fileprivate let lastName: String
      }

      ✏️ Replace 'fileprivate' access with 'internal'
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        internal let lastName: String
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        @Init(.ignore) fileprivate let lastName: String = <#value#>
      }
      """
    } expansion: {
      """
      public struct Person {
        public let firstName: String
        fileprivate let lastName: String
      
        internal init(
          firstName: String
        ) {
          self.firstName = firstName
        }
      }
      """
    }
  }

  // TODO: rename to _FailsWithDiagnostic
  func testPublicStruct_PublicAndPrivateProperty_PrivateInit() {
    assertMacro {
      """
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        private let lastName: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        private let lastName: String
        ┬──────
        ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property
           ✏️ Add '@Init(.internal)'
           ✏️ Replace 'private' access with 'internal'
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      private let lastName: String
      ┬──────
      ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property

      ✏️ Add '@Init(.internal)'
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        @Init(.internal) private let lastName: String
      }

      ✏️ Replace 'private' access with 'internal'
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        internal let lastName: String
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        @Init(.ignore) private let lastName: String = <#value#>
      }
      """
    } expansion: {
      """
      public struct Person {
        public let firstName: String
        private let lastName: String
      
        internal init(
          firstName: String
        ) {
          self.firstName = firstName
        }
      }
      """
    }
  }

  func testImplicitlyInternalStructWithPublicAndPrivateProperty_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        public let firstName: String
        private let lastName: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct Person {
        public let firstName: String
        private let lastName: String
        ┬──────
        ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property
           ✏️ Add '@Init(.internal)'
           ✏️ Replace 'private' access with 'internal'
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      private let lastName: String
      ┬──────
      ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property

      ✏️ Add '@Init(.internal)'
      @MemberwiseInit
      struct Person {
        public let firstName: String
        @Init(.internal) private let lastName: String
      }

      ✏️ Replace 'private' access with 'internal'
      @MemberwiseInit
      struct Person {
        public let firstName: String
        internal let lastName: String
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit
      struct Person {
        public let firstName: String
        @Init(.ignore) private let lastName: String = <#value#>
      }
      """
    } expansion: {
      """
      struct Person {
        public let firstName: String
        private let lastName: String
      
        internal init(
          firstName: String
        ) {
          self.firstName = firstName
        }
      }
      """
    }
  }

  func testEmptyCustomInitOnImplicitlyInternalProperty_FailsWithDiagnosticOnVariable() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct S {
        @Init let v: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct S {
        @Init let v: T
        ┬─────────────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property
           ✏️ Add '@Init(.public)'
           ✏️ Add 'public' access level
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      @Init let v: T
      ┬─────────────
      ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'internal' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      public struct S {
        @Init(.public) let v: T
      }

      ✏️ Add 'public' access level
      @MemberwiseInit(.public)
      public struct S {
        @Init public let v: T
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit(.public)
      public struct S {
        @Init(.ignore) let v: T = <#value#>
      }
      """
    } expansion: {
      """
      public struct S {
        let v: T
      
        public init() {
        }
      }
      """
    }
  }

  func testEmptyCustomInitOnPrivateProperty_FailsWithDiagnosticOnPrivateModifier() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct S {
        @Init private let v: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct S {
        @Init private let v: T
              ┬──────
              ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
                 ✏️ Add '@Init(.public)'
                 ✏️ Replace 'private' access with 'public'
                 ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      @Init private let v: T
            ┬──────
            ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      public struct S {
        @Init(.public) private let v: T
      }

      ✏️ Replace 'private' access with 'public'
      @MemberwiseInit(.public)
      public struct S {
        @Init public let v: T
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit(.public)
      public struct S {
        @Init(.ignore) private let v: T = <#value#>
      }
      """
    } expansion: {
      """
      public struct S {
        private let v: T
      
        public init() {
        }
      }
      """
    }
  }

  func testCustomInitPrivate_FailsWithDiagnosticOnCustomInitPrivate() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct S {
        @Init(.private, label: "_") let v: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct S {
        @Init(.private, label: "_") let v: T
              ┬───────
              ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
                 ✏️ Add '@Init(.public)'
                 ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      @Init(.private, label: "_") let v: T
            ┬───────
            ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      public struct S {
        @Init(.public, label: "_") let v: T
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit(.public)
      public struct S {
        @Init(.ignore) let v: T = <#value#>
      }
      """
    } expansion: {
      """
      public struct S {
        let v: T
      
        public init() {
        }
      }
      """
    }
  }

  func testCustomInitLabel_FailsWithDiagnosticOnPrivateModifier() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct S {
        @Init(label: "_") private let v: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct S {
        @Init(label: "_") private let v: T
                          ┬──────
                          ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
                             ✏️ Add '@Init(.public)'
                             ✏️ Replace 'private' access with 'public'
                             ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      @Init(label: "_") private let v: T
                        ┬──────
                        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      public struct S {
        @Init(.public, label: "_") private let v: T
      }

      ✏️ Replace 'private' access with 'public'
      @MemberwiseInit(.public)
      public struct S {
        @Init(label: "_") public let v: T
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit(.public)
      public struct S {
        @Init(.ignore) private let v: T = <#value#>
      }
      """
    } expansion: {
      """
      public struct S {
        private let v: T
      
        public init() {
        }
      }
      """
    }
  }

  // NB: Swift's memberwise init has the same behavior.
  func testPublicStructWithPreinitializedPrivateLet_PublicInit() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        private let lastName: String = ""
      }
      """
    } expansion: {
      """
      public struct Person {
        private let lastName: String = ""

        public init() {
        }
      }
      """
    }
  }

  func testMemberwiseInitPubic_PublicStructWithPreinitializedPrivateLet_PublicInit() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        private let lastName: String = ""
      }
      """
    } expansion: {
      """
      public struct Person {
        private let lastName: String = ""

        public init() {
        }
      }
      """
    }
  }

  func testPublicFinalClass_InternalInit() {
    assertMacro {
      """
      @MemberwiseInit
      public final class Person {
      }
      """
    } expansion: {
      """
      public final class Person {

          internal init() {
          }
      }
      """
    }
  }

  func testMemberwiseInitPrivate_PrivateSetProperty_IsIncludedPrivateInit() {
    assertMacro {
      """
      @MemberwiseInit(.private)
      struct Pedometer {
        private(set) var stepsToday: Int
      }
      """
    } expansion: {
      """
      struct Pedometer {
        private(set) var stepsToday: Int

        private init(
          stepsToday: Int
        ) {
          self.stepsToday = stepsToday
        }
      }
      """
    }
  }

  func testPublicGetPrivateSetProperty_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct Pedometer {
        public private(set) var stepsToday: Int
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct Pedometer {
        public private(set) var stepsToday: Int
        ┬──────────────────
        ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property
           ✏️ Add '@Init(.internal)'
           ✏️ Replace 'public private(set)' access with 'internal'
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      public private(set) var stepsToday: Int
      ┬──────────────────
      ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property

      ✏️ Add '@Init(.internal)'
      @MemberwiseInit
      struct Pedometer {
        @Init(.internal) public private(set) var stepsToday: Int
      }

      ✏️ Replace 'public private(set)' access with 'internal'
      @MemberwiseInit
      struct Pedometer {
        public internal(set) var stepsToday: Int
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit
      struct Pedometer {
        @Init(.ignore) public private(set) var stepsToday: Int = <#value#>
      }
      """
    } expansion: {
      """
      struct Pedometer {
        public private(set) var stepsToday: Int
      
        internal init() {
        }
      }
      """
    }
  }

  func testMemberwiseInitPublic_PrivateVarWithInitializer_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      struct Pedometer {
        private var stepsToday: Int = 0
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      struct Pedometer {
        private var stepsToday: Int = 0
        ┬──────
        ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
           ✏️ Add '@Init(.public)'
           ✏️ Replace 'private' access with 'public'
           ✏️ Add '@Init(.ignore)'
      }
      """
    } fixes: {
      """
      private var stepsToday: Int = 0
      ┬──────
      ╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property

      ✏️ Add '@Init(.public)'
      @MemberwiseInit(.public)
      struct Pedometer {
        @Init(.public) private var stepsToday: Int = 0
      }

      ✏️ Replace 'private' access with 'public'
      @MemberwiseInit(.public)
      struct Pedometer {
        public var stepsToday: Int = 0
      }

      ✏️ Add '@Init(.ignore)'
      @MemberwiseInit(.public)
      struct Pedometer {
        @Init(.ignore) private var stepsToday: Int = 0
      }
      """
    } expansion: {
      """
      struct Pedometer {
        private var stepsToday: Int = 0
      
        public init() {
        }
      }
      """
    }
  }

  func testNonInternalDefaultAccess_FailsWithDiagnostic() {
    assertMacro {
      """
      struct S {
        @MemberwiseInit(.internal)
        private struct T {
          let v: Int
        }
      }
      """
    } diagnostics: {
      """
      struct S {
        @MemberwiseInit(.internal)
        private struct T {
          let v: Int
          ┬─────────
          ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property
             ✏️ Add '@Init(.internal)'
             ✏️ Add 'internal' access level
             ✏️ Add '@Init(.ignore)' and an initializer
        }
      }
      """
    } fixes: {
      """
      let v: Int
      ┬─────────
      ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property

      ✏️ Add '@Init(.internal)'
      struct S {
        @MemberwiseInit(.internal)
        private struct T {
          @Init(.internal) let v: Int
        }
      }

      ✏️ Add 'internal' access level
      struct S {
        @MemberwiseInit(.internal)
        private struct T {
          internal let v: Int
        }
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      struct S {
        @MemberwiseInit(.internal)
        private struct T {
          @Init(.ignore) let v: Int = <#value#>
        }
      }
      """
    } expansion: {
      """
      struct S {
        private struct T {
          let v: Int
      
          internal init() {
          }
        }
      }
      """
    }
  }

  func testAccessLeakOnMultipleBindings_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      public struct S {
        private var x, y: Int
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      public struct S {
        private var x, y: Int
        ┬──────
        ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property
           ✏️ Add '@Init(.internal)'
           ✏️ Replace 'private' access with 'internal'
           ✏️ Add '@Init(.ignore)' and an initializer
      }
      """
    } fixes: {
      """
      private var x, y: Int
      ┬──────
      ╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property

      ✏️ Add '@Init(.internal)'
      @MemberwiseInit
      public struct S {
        @Init(.internal) private var x, y: Int
      }

      ✏️ Replace 'private' access with 'internal'
      @MemberwiseInit
      public struct S {
        internal var x, y: Int
      }

      ✏️ Add '@Init(.ignore)' and an initializer
      @MemberwiseInit
      public struct S {
        @Init(.ignore) private var x = <#value#>, y: Int = <#value#>
      }
      """
    } expansion: {
      """
      public struct S {
        private var x, y: Int
      
        internal init() {
        }
      }
      """
    }
  }

  // MARK: - Test macro parameters

  func testCustomInitPublicEscapingLabel() {
    assertMacro {
      """
      public typealias CompletionHandler = () -> Void

      @MemberwiseInit(.public)
      public struct Job {
        @Init(.public, escaping: true, label: "for")
        let callback: CompletionHandler
      }
      """
    } expansion: {
      """
      public typealias CompletionHandler = () -> Void
      public struct Job {
        let callback: CompletionHandler

        public init(
          for callback: @escaping CompletionHandler
        ) {
          self.callback = callback
        }
      }
      """
    }
  }

  // TODO: regress MemberwiseInit to match swift-syntax 5.10 limitation
  func testCustomInitEscapingWithMultipleBindings() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(escaping: true)
        let v, r: T
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(escaping: true)
        ┬────────────────────
        ╰─ 🛑 peer macro can only be applied to a single variable
        let v, r: T
      }
      """
    } expansion: {
      """
      struct S {
        let v, r: T
      
        internal init(
          v: @escaping T,
          r: @escaping T
        ) {
          self.v = v
          self.r = r
        }
      }
      """
    }
  }

  // TODO: Consider regressing MemberwiseInit to match swift-syntax 5.10 limitation (or leave redundant error, but that has a fix-it)
  func testCustomLabelWithMultipleBindings_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        @Init(label: "with") public let firstName, lastName: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct Person {
        @Init(label: "with") public let firstName, lastName: String
              ┬────────────
        │     ╰─ 🛑 Custom 'label' can't be applied to multiple bindings
        ┬───────────────────
        ╰─ 🛑 peer macro can only be applied to a single variable
      }
      """
    } expansion: {
      """
      public struct Person {
        public let firstName, lastName: String
      
        public init() {
        }
      }
      """
    }
  }

  // TODO: Consider regressing MemberwiseInit to match swift-syntax 5.10 limitation (or leave redundant error, but that has a fix-it)
  func testLabellessCustomInitForMultipleBindings() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        @Init(label: "_") public let firstName, lastName: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct Person {
        @Init(label: "_") public let firstName, lastName: String
        ┬────────────────
        ╰─ 🛑 peer macro can only be applied to a single variable
      }
      """
    } expansion: {
      """
      public struct Person {
        public let firstName, lastName: String
      
        public init(
          _ firstName: String,
          _ lastName: String
        ) {
          self.firstName = firstName
          self.lastName = lastName
        }
      }
      """
    }
  }

  func testCustomInitIgnore() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        @Init(.public) let name: String
        @Init(.ignore) private var age: Int? = nil
      }
      """
    } expansion: {
      """
      public struct Person {
        let name: String
        private var age: Int? = nil

        public init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  // NB: @MemberwiseInit cannot "see" that the typealias is a closure type that needs '@escaping'.
  func testCustomInitEscaping() {
    assertMacro {
      """
      typealias LoggingMechanism = @Sendable (String) -> Void

      @MemberwiseInit
      struct TaskRunner: Sendable {
        @Init(escaping: true) let log: LoggingMechanism
      }
      """
    } expansion: {
      """
      typealias LoggingMechanism = @Sendable (String) -> Void
      struct TaskRunner: Sendable {
        let log: LoggingMechanism

        internal init(
          log: @escaping LoggingMechanism
        ) {
          self.log = log
        }
      }
      """
    }
  }

  // NB: @MemberwiseInit can't validate type semantics. The '@escaping' misuse here will trigger
  // a compiler diagnostic.
  func testIncorrectUseOfCustomInitEscaping_SucceedsWithInvalidCode() {
    assertMacro {
      """
      @MemberwiseInit
      struct Config: Sendable {
        @Init(escaping: true) let version: Int
      }
      """
    } expansion: {
      """
      struct Config: Sendable {
        let version: Int

        internal init(
          version: @escaping Int
        ) {
          self.version = version
        }
      }
      """
    }
  }

  // MARK: - Test init parameter names and labels

  func testUnderscoredParameter() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let _name: String
      }
      """
    } expansion: {
      """
      struct Person {
        let _name: String

        internal init(
          _name: String
        ) {
          self._name = _name
        }
      }
      """
    }
  }

  func testCustomInitUnderscoredParameter() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        @Init(.public) let _name: String
      }
      """
    } expansion: {
      """
      struct Person {
        let _name: String

        internal init(
          _name: String
        ) {
          self._name = _name
        }
      }
      """
    }
  }

  func testDeunderscoreParameters() {
    assertMacro {
      """
      @MemberwiseInit(_deunderscoreParameters: true)
      struct Person {
        let _name: String
      }
      """
    } expansion: {
      """
      struct Person {
        let _name: String

        internal init(
          name: String
        ) {
          self._name = name
        }
      }
      """
    }
  }

  func testDeunderscoreParametersFalse() {
    assertMacro {
      """
      @MemberwiseInit(_deunderscoreParameters: false)
      struct Person {
        let _name: String
      }
      """
    } expansion: {
      """
      struct Person {
        let _name: String

        internal init(
          _name: String
        ) {
          self._name = _name
        }
      }
      """
    }
  }

  func testDeunderscoredParametersWouldConflict_DeunderscoreSkipped() {
    assertMacro {
      """
      @MemberwiseInit(_deunderscoreParameters: true)
      struct S {
        let a: String
        let _a: String
      }
      """
    } expansion: {
      """
      struct S {
        let a: String
        let _a: String

        internal init(
          a: String,
          _a: String
        ) {
          self.a = a
          self._a = _a
        }
      }
      """
    }
  }

  func testDeunderscoredParameters_WhenConflictingPropertyIsIgnored() {
    assertMacro {
      """
      @MemberwiseInit(_deunderscoreParameters: true)
      struct S {
        let _a: String
        @Init(.ignore) let a: String
      }
      """
    } expansion: {
      """
      struct S {
        let _a: String
        let a: String

        internal init(
          a: String
        ) {
          self._a = a
        }
      }
      """
    }
  }

  func testCustomInitLabelOverridesDeunderscoring() {
    assertMacro {
      """
      @MemberwiseInit(_deunderscoreParameters: true)
      struct S {
        @Init(label: "_a") let _a: String
      }
      """
    } expansion: {
      """
      struct S {
        let _a: String

        internal init(
          _a: String
        ) {
          self._a = _a
        }
      }
      """
    }
  }

  func testCustomInitLabelOnUnderscoredProperty_DeunderscoreSkipped() {
    assertMacro {
      """
      @MemberwiseInit(_deunderscoreParameters: true)
      struct S {
        @Init(label: "b") let _a: String
      }
      """
    } expansion: {
      """
      struct S {
        let _a: String

        internal init(
          b _a: String
        ) {
          self._a = _a
        }
      }
      """
    }
  }

  func testCustomInitLabel_Labeless() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        @Init(label: "_") let name: String
      }
      """
    } expansion: {
      """
      struct Person {
        let name: String

        internal init(
          _ name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  func testCustomInitLabel_MultipleLabellessParameters() {
    assertMacro {
      """
      @MemberwiseInit
      struct Pair<T> {
        @Init(label: "_") let first: T
        @Init(label: "_") let second: T
      }
      """
    } expansion: {
      """
      struct Pair<T> {
        let first: T
        let second: T

        internal init(
          _ first: T,
          _ second: T
        ) {
          self.first = first
          self.second = second
        }
      }
      """
    }
  }

  func testInvalidCustomInitLabel_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        @Init(label: "1foo") let name: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct Person {
        @Init(label: "1foo") let name: String
                     ┬─────
                     ╰─ 🛑 Invalid label value
      }
      """
    } expansion: {
      """
      struct Person {
        let name: String
      
        internal init() {
        }
      }
      """
    }
  }

  func testCustomInitLabelHavingMultipleLines_FailsWithDiagnostic() {
    assertMacro {
      #"""
      @MemberwiseInit
      struct Person {
        @Init(label: """
          too
          long
        """) let name: String
      }
      """#
    } diagnostics: {
      #"""
      @MemberwiseInit
      struct Person {
        @Init(label: """
                     ╰─ 🛑 Invalid label value
          too
          long
        """) let name: String
      }
      """#
    } expansion: {
      """
      struct Person {
        let name: String
      
        internal init() {
        }
      }
      """
    }
  }

  func testCustomInitLabelHavingSingleLineUsingMultilineSyntax() {
    assertMacro {
      #"""
      @MemberwiseInit
      struct Person {
        @Init(label: """
          foo
        """) let name: String
      }
      """#
    } expansion: {
      """
      struct Person {
        let name: String

        internal init(
          foo name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  func testCustomInitLabelConflictsWithPropertyName_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "b") let a: String
        let b: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "b") let a: String
                     ┬──
                     ╰─ 🛑 Label 'b' conflicts with a property name
        let b: String
      }
      """
    } expansion: {
      """
      struct S {
        let a: String
        let b: String
      
        internal init(
          b a: String,
          b: String
        ) {
          self.a = a
          self.b = b
        }
      }
      """
    }
  }

  func testCustomInitLabel_WhenConflictingPropertyIsIgnored() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "b") let a: String
        @Init(.ignore) let b: String
      }
      """
    } expansion: {
      """
      struct S {
        let a: String
        let b: String

        internal init(
          b a: String
        ) {
          self.a = a
        }
      }
      """
    }
  }

  func testCustomInitLabelConflictsWithAnotherLabel_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "z") let a: String
        @Init(label: "z") let b: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "z") let a: String
        @Init(label: "z") let b: String
                     ┬──
                     ╰─ 🛑 Label 'z' conflicts with another label
      }
      """
    } expansion: {
      """
      struct S {
        let a: String
        let b: String
      
        internal init(
          z a: String,
          z b: String
        ) {
          self.a = a
          self.b = b
        }
      }
      """
    }
  }

  func testCustomInitLabelConflictsWithMultipleOtherLabels_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "z") let a: String
        @Init(label: "z") let b: String
        @Init(label: "z") let c: String
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct S {
        @Init(label: "z") let a: String
        @Init(label: "z") let b: String
                     ┬──
                     ╰─ 🛑 Label 'z' conflicts with another label
        @Init(label: "z") let c: String
                     ┬──
                     ╰─ 🛑 Label 'z' conflicts with another label
      }
      """
    } expansion: {
      """
      struct S {
        let a: String
        let b: String
        let c: String
      
        internal init(
          z a: String,
          z b: String,
          z c: String
        ) {
          self.a = a
          self.b = b
          self.c = c
        }
      }
      """
    }
  }

  // MARK: - Test _optionalsDefaultNil (experimental)

  func testOptionalLetProperty_InternalInitNoDefault() {
    assertMacro {
      """
      @MemberwiseInit(.internal)
      public struct Person {
        let nickname: String?
      }
      """
    } expansion: {
      """
      public struct Person {
        let nickname: String?

        internal init(
          nickname: String?
        ) {
          self.nickname = nickname
        }
      }
      """
    }
  }

  func testOptionalLetProperty_PublicInitNoDefault() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let nickname: String?
      }
      """
    } expansion: {
      """
      public struct Person {
        public let nickname: String?

        public init(
          nickname: String?
        ) {
          self.nickname = nickname
        }
      }
      """
    }
  }

  // NB: Swift's memberwise init defaults optional vars to nil, which seems reasonable considering
  // it only provides non-public initializers. Swift will never default lets to nil, however.
  // I assume that automatically assigning lets precludes uncommon init flows where you'd want to
  // assign the constant some other way.
  func testOptionalVarProperty_InternalInitWithDefault() {
    assertMacro {
      """
      @MemberwiseInit(.internal)
      struct Person {
        var nickname: String?
      }
      """
    } expansion: {
      """
      struct Person {
        var nickname: String?

        internal init(
          nickname: String? = nil
        ) {
          self.nickname = nickname
        }
      }
      """
    }
  }

  func testOptionalVarProperty_PackageInitNoDefault() {
    assertMacro {
      """
      @MemberwiseInit(.package)
      public struct Person {
        package var nickname: String?
      }
      """
    } expansion: {
      """
      public struct Person {
        package var nickname: String?

        package init(
          nickname: String?
        ) {
          self.nickname = nickname
        }
      }
      """
    }
  }

  func testOptionalVarProperty_PublicInitNoDefault() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public var nickname: String?
      }
      """
    } expansion: {
      """
      public struct Person {
        public var nickname: String?

        public init(
          nickname: String?
        ) {
          self.nickname = nickname
        }
      }
      """
    }
  }

  // NB: With MemberwiseInit, Swift's default behavior can be disabled.
  func testOptionalVar_OptionalsDefaultNilFalse_InternalInitNoDefault() {
    assertMacro {
      """
      @MemberwiseInit(_optionalsDefaultNil: false)
      struct Product {
        var discountCode: String?
      }
      """
    } expansion: {
      """
      struct Product {
        var discountCode: String?

        internal init(
          discountCode: String?
        ) {
          self.discountCode = discountCode
        }
      }
      """
    }
  }

  // NB: Confirms that `_optionalsDefaultNil: false` for optional let has no effect.
  func testOptionalLet_OptionalsDefaultNilFalse_InternalInitNoDefault() {
    assertMacro {
      """
      @MemberwiseInit(_optionalsDefaultNil: false)
      struct Product {
        let discountCode: String?
      }
      """
    } expansion: {
      """
      struct Product {
        let discountCode: String?

        internal init(
          discountCode: String?
        ) {
          self.discountCode = discountCode
        }
      }
      """
    }
  }

  func testOptionalLet_OptionalsDefaultNilTrue_InternalInitWithDefault() {
    assertMacro {
      """
      @MemberwiseInit(_optionalsDefaultNil: true)
      struct Person {
        let nickname: String?
      }
      """
    } expansion: {
      """
      struct Person {
        let nickname: String?

        internal init(
          nickname: String? = nil
        ) {
          self.nickname = nickname
        }
      }
      """
    }
  }

  func testOptionalVar_OptionalsDefaultNilTrue_PublicInitWithDefault() {
    assertMacro {
      """
      @MemberwiseInit(.public, _optionalsDefaultNil: true)
      public struct Person {
        public var nickname: String?
      }
      """
    } expansion: {
      """
      public struct Person {
        public var nickname: String?

        public init(
          nickname: String? = nil
        ) {
          self.nickname = nickname
        }
      }
      """
    }
  }

  // MARK: - Test complex usage

  func testNestedStructs() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let name: String
        let address: Address

        @MemberwiseInit
        struct Address {
          let city: String
          let state: String
        }
      }
      """
    } expansion: {
      """
      struct Person {
        let name: String
        let address: Address
        struct Address {
          let city: String
          let state: String

          internal init(
            city: String,
            state: String
          ) {
            self.city = city
            self.state = state
          }
        }

        internal init(
          name: String,
          address: Address
        ) {
          self.name = name
          self.address = address
        }
      }
      """
    }
  }

  // NB: Most cases of multiple attachement are invalid or nonsensical.
  // TODO: Generate a helpful diagnostic error message when multiple attachment is nonsensical.
  func testAttachedMultipleTimes() {
    assertMacro {
      """
      @MemberwiseInit(.public, _deunderscoreParameters: true)
      @MemberwiseInit(.internal, _optionalsDefaultNil: false)
      @MemberwiseInit(.private)
      public struct Person {
        @Init(.public) var _name: String?
      }
      """
    } expansion: {
      """
      public struct Person {
        var _name: String?

        public init(
          name: String?
        ) {
          self._name = name
        }

        internal init(
          _name: String?
        ) {
          self._name = _name
        }

        private init(
          _name: String? = nil
        ) {
          self._name = _name
        }
      }
      """
    }
  }

  // https://github.com/tgrapperon/swift-dependencies-additions/blob/main/Sources/UserDefaultsDependency/UserDefaultsDependency.swift
  func testComplexProtocolWitnessDependency() {
    assertMacro {
      """
      @MemberwiseInit(.public, _deunderscoreParameters: true)
      public struct Dependency: Sendable {
        public let _get: @Sendable (_ key: String, _ type: Any.Type) -> (any Sendable)?
        public let _set: @Sendable (_ value: (any Sendable)?, _ key: String) -> Void
        public let _values: @Sendable (_ key: String, _ value: Any.Type) -> AsyncStream<(any Sendable)?>
      }
      """
    } expansion: {
      """
      public struct Dependency: Sendable {
        public let _get: @Sendable (_ key: String, _ type: Any.Type) -> (any Sendable)?
        public let _set: @Sendable (_ value: (any Sendable)?, _ key: String) -> Void
        public let _values: @Sendable (_ key: String, _ value: Any.Type) -> AsyncStream<(any Sendable)?>

        public init(
          get: @escaping @Sendable (_ key: String, _ type: Any.Type) -> (any Sendable)?,
          set: @escaping @Sendable (_ value: (any Sendable)?, _ key: String) -> Void,
          values: @escaping @Sendable (_ key: String, _ value: Any.Type) -> AsyncStream<(any Sendable)?>
        ) {
          self._get = get
          self._set = set
          self._values = values
        }
      }
      """
    }
  }

  // TODO: Consider SE-0400: Init Accessors:
  // https://github.com/apple/swift-evolution/blob/main/proposals/0400-init-accessors.md#init-accessors
  //
  // - May need something like `@MemberwiseInit(properties: ["title", "text"])` to generate
  //  `init(title: String, text: String)`.
  func testInitAccessor() {
    assertMacro {
      """
      @MemberwiseInit
      struct Angle {
        var degrees: Double
        var radians: Double {
          @storageRestrictions(initializes: degrees)
          init(initialValue)  {
            degrees = initialValue * 180 / .pi
          }

          get { degrees * .pi / 180 }
          set { degrees = newValue * 180 / .pi }
        }

        init(radiansParam: Double) {
          self.radians = radiansParam
        }
      }
      """
    } expansion: {
      """
      struct Angle {
        var degrees: Double
        var radians: Double {
          @storageRestrictions(initializes: degrees)
          init(initialValue)  {
            degrees = initialValue * 180 / .pi
          }

          get { degrees * .pi / 180 }
          set { degrees = newValue * 180 / .pi }
        }

        init(radiansParam: Double) {
          self.radians = radiansParam
        }

        internal init(
          degrees: Double
        ) {
          self.degrees = degrees
        }
      }
      """
    }
  }

  // MARK: - Test class property variations

  // Lazy properties must be declared with an initializer.
  //
  // A `lazy var` property shouldn't be initialized in an `init` method, as the purpose of
  // `lazy var` is to defer initialization until some time after the instance itself is initialized.
  // Immediately initializing the property defeats this purpose.
  func testLazyVarInClass_IsIgnored() {
    assertMacro {
      """
      @MemberwiseInit
      class Calculator {
        lazy var lastResult: Double = 0.0
      }
      """
    } expansion: {
      """
      class Calculator {
        lazy var lastResult: Double = 0.0

        internal init() {
        }
      }
      """
    }
  }

  func testStaticProperties_AreIgnored() {
    assertMacro {
      """
      @MemberwiseInit
      struct Coordinate {
        static let originX: Int = 0
        static var displayGrid: Bool = true
      }
      """
    } expansion: {
      """
      struct Coordinate {
        static let originX: Int = 0
        static var displayGrid: Bool = true

        internal init() {
        }
      }
      """
    }
  }

  func testStoredPropertyWithObservers_IsIncluded() {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        var age: Int {
          willSet { print("Will set to \\(newValue).") }
          didSet { ageLabel.text = "Age: \\(age)" }
        }
      }
      """
    } expansion: {
      #"""
      struct Person {
        var age: Int {
          willSet { print("Will set to \(newValue).") }
          didSet { ageLabel.text = "Age: \(age)" }
        }

        internal init(
          age: Int
        ) {
          self.age = age
        }
      }
      """#
    }
  }
}
