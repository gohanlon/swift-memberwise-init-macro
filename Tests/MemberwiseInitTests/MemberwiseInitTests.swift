import SwiftSyntaxMacros
import MacroTesting
import MemberwiseInitMacros
import XCTest

// TODO: cover valid `open` usages (on class and member decl)
// TODO: Consider exhaustive coverage for multiple-properties on a struct.
// TODO: warn when `@Init(.private) is applied to reduce access, e.g. `public let v: T`?

final class MemberwiseInitTests: XCTestCase {
  override func invokeTest() {
    // TODO: PR swift-macro-testing to support explicit indentationWidth Trivia in assertMacro/withMacroTesting
    // Waiting for: https://github.com/pointfreeco/swift-macro-testing/pull/8
    withMacroTesting(
      indentationWidth: .spaces(2),
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "Init": InitMacro.self
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - Test simple usage

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


  func testLetProperty() throws {
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

  func testOptionlProperty() throws {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        let nickname: String?
      }
      """
    } expansion: {
      """
      struct Person {
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

  func testUnderscorePrefixConvention() {
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
          name: String
        ) {
          self._name = name
        }
      }
      """
    }
  }

  // MARK: - Test assignment variations

  func testVarProperty() throws {
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

  func testLetMarkedInitWithInitializer_IsIgnored() throws {
    assertMacro {
      """
      @MemberwiseInit
      struct Earth {
        @Init let name = "Earth"
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

  func testVarWithInitializer_IsIncludedWithDefaultValue() throws {
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

  func testVarPropertyWithInitializerWithoutExplicitType_FailsWithDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      public struct Pedometer {
        var stepsToday = 0
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      public struct Pedometer {
        var stepsToday = 0
            ┬─────────────
            ╰─ 🛑 @MemberwiseInit requires explicit type declarations for `var` stored properties.
      }
      """
    }
  }

  func testInlineCommentOnPropertyHasNoEffect() throws {
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

  func testAutomaticEscaping() throws {
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

  func testLetHavingTwoBindings() throws {
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

  func testLetHavingTwoBindingsWhereFirstInitialized() throws {
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

  func testLetHavingTwoBindingsWhereFirstInitializedWithoutExplicitType() throws {
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

  func testLetHavingTwoBindingsWhereFirstLacksExplicitType() throws {
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

  func testLetHavingTwoBindingsWhereLastInitialized() throws {
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

  func testLetStatementHavingThreeBindingsWhereMiddleLacksExplicitType() throws {
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

  func testLetStatementHavingThreeBindingsWhereOnlyLastHasExplicitFunctionType_AllEscaping() throws {
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
//  func testLetDestructuredTupleWithoutInitializer() throws {
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
  func testLetDestructuredTupleWithInitializer() throws {
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

  func testLetDestructuredTupleWithoutInitializer_FailsNotSupported() throws {
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
    }
  }

  func testVarDestructuredTupleWithInitializer_FailsNotSupported() throws {
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
    }
  }

  // MARK: - Test enum and extension

  func testAppliedToEnum_FailsWithDiagnostic() throws {
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

  func testAppliedToExtension_FailsWithDiagnostic() throws {
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
        var hasGoodFavoriteNumber: Bool {
          true
        }
      }
      """
    } expansion: {
      """
      struct Person {
        var hasGoodFavoriteNumber: Bool {
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

  func testMacroAdjacentAttribute() throws {
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

  func testMemberwiseInitInternalOnPublicStruct_InitPublicEscapingOnPrivateProperty_InternalInitEscaping() {
    assertMacro {
      """
      @MemberwiseInit(.internal)
      public struct Person {
        @Init(.public, .escaping) private let _name: String
      }
      """
    } expansion: {
      """
      public struct Person {
        private let _name: String

        internal init(
          name: @escaping String
        ) {
          self._name = name
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

  // NB: This is almost covered by the exhaustive AccessLevelTests, but `open class Person`
  // is missing. This test touches on all the access levels (instead of a meaningful few).
  func testDefaultInitAccessLeves() {
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
      private struct Person {
        private let name: String

        private init(
          name: String
        ) {
          self.name = name
        }
      }
      fileprivate struct Person {
        private let name: String

        private init(
          name: String
        ) {
          self.name = name
        }
      }
      struct Person {
        fileprivate let name: String

        fileprivate init(
          name: String
        ) {
          self.name = name
        }
      }
      internal struct Person {
        fileprivate let name: String

        fileprivate init(
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

  func testMemberwiseInitPublic_PublicStruct_PublicAndImplicitlyInternalProperties_InternalInit() throws {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct Person {
        public let firstName: String
        let lastName: String
      }
      """
    } expansion: {
      """
      public struct Person {
        public let firstName: String
        let lastName: String

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

  func testPublicStruct_PublicAndFileprivateProperty_FileprivateInit() throws {
    assertMacro {
      """
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        fileprivate let lastName: String
      }
      """
    } expansion: {
      """
      public struct Person {
        public let firstName: String
        fileprivate let lastName: String

        fileprivate init(
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

  func testPublicStruct_PublicAndPrivateProperty_PrivateInit() throws {
    assertMacro {
      """
      @MemberwiseInit
      public struct Person {
        public let firstName: String
        private let lastName: String
      }
      """
    } expansion: {
      """
      public struct Person {
        public let firstName: String
        private let lastName: String

        private init(
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

  func testImplicitlyInternalStructWithPublicAndPrivateProperty_PrivateInit() throws {
    assertMacro {
      """
      @MemberwiseInit
      struct Person {
        public let firstName: String
        private let lastName: String
      }
      """
    } expansion: {
      """
      struct Person {
        public let firstName: String
        private let lastName: String

        private init(
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

  // NB: The compiler's member-wise init has the same behavior.
  func testPublicStructWithPreinitializedPrivateLet_InternalInit() throws {
    assertMacro {
      """
      @MemberwiseInit
      public struct Person {
        private let lastName: String = ""
      }
      """
    } expansion: {
      """
      public struct Person {
        private let lastName: String = ""

        internal init() {
        }
      }
      """
    }
  }

  func testMemberwiseInitPubic_PublicStructWithPreinitializedPrivateLet_PublicInit() throws {
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

  func testPrivateSetProperty_IsIncludedPrivateInit() throws {
    assertMacro {
      """
      @MemberwiseInit
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

  func testNonInternalDefaultAccess() throws {
    assertMacro {
      """
      struct S {
        @MemberwiseInit
        private struct T {
          let v: Int
        }
      }
      """
    } expansion: {
      """
      struct S {
        private struct T {
          let v: Int

          private init(
            v: Int
          ) {
            self.v = v
          }
        }
      }
      """
    }
  }


  // MARK: - Test macro parameters

  func testInitParameterIgnore() throws {
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

  // TODO: This test is extremely similar to `testLetWithInitializer_IsIgnored`, just with @Init. Bring them together?
  // TODO: emit diagnostic on "@Init" when applied nonsensically
  func testInitOnLetWithInitializer_IsIgnored() throws {
    assertMacro {
      """
      @MemberwiseInit
      public struct Earth {
        @Init private let radiusInMiles: Float = 3958.8
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

  // NB: @MemberwiseInit cannot that see the typealias's underlying type is a closure type that
  // needs to be escaped.
  func testExplicitInitParameterEscaping() throws {
    assertMacro {
      """
      typealias LoggingMechanism = @Sendable (String) -> Void

      @MemberwiseInit
      struct TaskRunner: Sendable {
        @Init(.escaping) let log: LoggingMechanism
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

  func testExplicitInitParameterEscapingForMultiple() throws {
    assertMacro {
      """
      typealias LoggingMechanism = @Sendable (String) -> Void
      typealias CompletionHandler = @Sendable () -> Void

      @MemberwiseInit
      struct TaskRunner: Sendable {
        @Init(.escaping) let log: LoggingMechanism
        @Init(.escaping) let onCompletion: CompletionHandler
      }
      """
    } expansion: {
      """
      typealias LoggingMechanism = @Sendable (String) -> Void
      typealias CompletionHandler = @Sendable () -> Void
      struct TaskRunner: Sendable {
        let log: LoggingMechanism
        let onCompletion: CompletionHandler

        internal init(
          log: @escaping LoggingMechanism,
          onCompletion: @escaping CompletionHandler
        ) {
          self.log = log
          self.onCompletion = onCompletion
        }
      }
      """
    }
  }

  // NB: @MemberwiseInit can't validate Swift syntax. Here, '@escaping' is misapplied, and the
  // compiler will generate a helpful diagnostic error message.
  func testIncorrectUseOfExplicitEscaping_SucceedsWithInvalidCode() throws {
    assertMacro {
      """
      @MemberwiseInit
      struct Config: Sendable {
        @Init(.escaping) let version: Int
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

  func testOptionalsDefaultNilFalse_AssignsNoDefaultToOptional() throws {
    assertMacro {
      """
      @MemberwiseInit(optionalsDefaultNil: false)
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

  func testOptionalsDefaultNilTrueWithExplicitEscaping() throws {
    assertMacro {
      """
      typealias TaskCallback = (String) -> Void

      @MemberwiseInit(optionalsDefaultNil: true)
      struct TaskRunner {
        @Init(.escaping) let completionHandler: TaskCallback
        let retryCount: Int?
      }
      """
    } expansion: {
      """
      typealias TaskCallback = (String) -> Void
      struct TaskRunner {
        let completionHandler: TaskCallback
        let retryCount: Int?

        internal init(
          completionHandler: @escaping TaskCallback,
          retryCount: Int? = nil
        ) {
          self.completionHandler = completionHandler
          self.retryCount = retryCount
        }
      }
      """
    }
  }

  func testOptionalsDefaultNilTrue_ParameterValueDefaultsNil() throws {
    assertMacro {
      """
      @MemberwiseInit(optionalsDefaultNil: true)
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

  // MARK: - Test complex usage

  func testNestedStructs() throws {
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

  // NB: This is the only case where attaching @MemberwiseInit multiple times is useful, and
  // most cases of multiple attachement are invalid or nonsensical.
  // TODO: Generate a helpful diagnostic error message when multiple attachment is nonsensical.
  func testAttachedMultipleTimes() throws {
    assertMacro {
      """
      @MemberwiseInit(.public)
      @MemberwiseInit(.internal, optionalsDefaultNil: true)
      public struct Person {
        @Init(.public) let name: String?
      }
      """
    } expansion: {
      """
      public struct Person {
        let name: String?

        public init(
          name: String?
        ) {
          self.name = name
        }

        internal init(
          name: String? = nil
        ) {
          self.name = name
        }
      }
      """
    }
  }

  // https://github.com/tgrapperon/swift-dependencies-additions/blob/main/Sources/UserDefaultsDependency/UserDefaultsDependency.swift
  func testComplexProtocolWitnessDependency() {
    assertMacro {
      """
      @MemberwiseInit(.public)
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
  // - May need something like `@MemberwiseInit(properties: ["title", "text"])` to cause the to
  // generate `init(title: String, text: String)`.
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

  func testStaticProperties_AreIgnored() throws {
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
