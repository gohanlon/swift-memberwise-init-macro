import MemberwiseInit

@MemberwiseInit(.public)
public struct Person1 {
  public let name: String
  @Init(.public) private var age: Int? = nil
}
_ = Person1(name: "Blob")
_ = Person1(name: "Blob", age: 42)

@MemberwiseInit(.public)
public struct Person2 {
  public let name: String
  @Init(.ignore) private var age: Int? = nil
}
_ = Person2(name: "Blob")
//_ = Person2(name: "Blob", age: 42) // 🛑 Incorrect argument label in call

@MemberwiseInit(.public)
public struct Dependency: Sendable {
  public let get: @Sendable (_ key: String, _ type: Any.Type) -> (any Sendable)?
  public let set: @Sendable (_ value: (any Sendable)?, _ key: String) -> Void
  public let values: @Sendable (_ key: String, _ value: Any.Type) -> AsyncStream<(any Sendable)?>
}
_ = Dependency(
  get: { key, type in },
  set: { value, key in },
  values: { key, value in
    return .init { continuation in
      // …
    }
  }
)

@MemberwiseInit(.public)
public struct User1 {
  public let id: Int
  public var name: String? = nil
}
_ = User1.init(id: 42)
_ = User1.init(id: 42, name: "Blob")

@MemberwiseInit(.public, _optionalsDefaultNil: true)
public struct User2 {
  public let id: Int
  public let name: String?
  public let email: String?
  public let address: String?
}
_ = User2.init(id: 42)
_ = User2.init(id: 42, name: "Blob", email: "blob@example.com")

public typealias CompletionHandler = @Sendable () -> Void

@MemberwiseInit(.public)
public struct TaskRunner: Sendable {
  @Init(escaping: true) public let onCompletion: CompletionHandler
}

@MemberwiseInit(.public)
public struct Job {
  @Init(.public, escaping: true, label: "for")
  let callback: CompletionHandler
}
_ = Job(for: { print("Done!") })

//@MemberwiseInit(.public)
//public struct TaskRunner: Sendable {
//  @Init(.escaping) public let onCompletion: CompletionHandler
//  ┬─────────────────────────────
//  ╰─ ⚠️ @Init(.escaping) is deprecated
//     ✏️ Replace '@Init(.escaping)' with '@Init(escaping: true)'
//}

@MemberwiseInit
struct Point2D {
  @Init(label: "_") let x: Int
  @Init(label: "_") let y: Int
}
_ = Point2D(1, 2)

//@MemberwiseInit
//struct S {
//  @Init(label: "b") let a: String //  🛑 Label 'b' conflicts with a property name
//  let b: String
//}

@MemberwiseInit
public struct InferType<T: CaseIterable> {
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

@MemberwiseInit
struct S1 {
  @Init(label: "b") let _a: String
}
_ = S1.init(b: "Blob")

@MemberwiseInit(_deunderscoreParameters: true)
struct S2 {
  let _a: String
  @Init(.ignore) var a: String? = nil
}
_ = S2.init(a: "Blob")

@MemberwiseInit
struct S3 {
  let _a: String
  var a: String? = nil
}
_ = S3.init(_a: "Blob")

//import SwiftUI
//@MemberwiseInit(.public)
//struct MyView: View {
//  @State var isOn: Bool = false  // 👈 initializer clause
//
//  var body: some View { EmptyView() }
//}
//_ = MyView.init()
//
//@MemberwiseInit
//struct MyView2: View {
//  @Init @State var isOn: Bool  // 👈 @Init
//
//  var body: some View { EmptyView() }
//}
//_ = MyView2.init(isOn: true)

@MemberwiseInit(_deunderscoreParameters: true)
struct Person10 {
  let _name: String
}
_ = Person10.init(name: "Blob")
//_ = Person10.init(_name: "Blob") // 🛑 No exact matches in call to initializer

// Swift's memberwise init:
struct Person11 {
  let _name: String
}
_ = Person11.init(_name: "Blob")

@MemberwiseInit
struct Person20 {
  @Init(.internal) private let age: Int
}
_ = Person20.init(age: 42)

// Swift's memberwise init:
//struct Person21 {
//  private let age: Int
//}
//_ = Person21.init(age: 42) // 🛑 'Person21' initializer is inaccessible due to 'private' protection level

//@MemberwiseInit
//struct Person22 {
//  private let age: Int
//}
//_ = Person22.init(age: 42) // 🛑 'Person22' initializer is inaccessible due to 'private' protection level

@MemberwiseInit
struct Person30: Decodable {
  let name: String

  enum CodingKeys: CodingKey {
    case name
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = try container.decode(String.self, forKey: .name)
  }
}
_ = Person30.init(name: "Blob")

// Bare:
//struct Person31: Decodable {
//  let name: String
//
//  enum CodingKeys: CodingKey {
//    case name
//  }
//
//  init(from decoder: Decoder) throws {
//    let container = try decoder.container(keyedBy: CodingKeys.self)
//    self.name = try container.decode(String.self, forKey: .name)
//  }
//}
//_ = Person31.init(name: "Blob") // 🛑 Incorrect argument label in call (have 'name:', expected 'from:')

@MemberwiseInit
struct Person40: RawRepresentable {
  let name: String

  var rawValue: String {
    self.name
  }

  init?(rawValue: String) {
    self.name = rawValue
  }
}
_ = Person40.init(name: "Blob")

// Swift's memberwise init is omitted:
//struct Person41: RawRepresentable {
//  let name: String
//
//  var rawValue: String {
//    self.name
//  }
//
//  init?(rawValue: String) {
//    self.name = rawValue
//  }
//}
//_ = Person41.init(name: "Blob") // 🛑 Incorrect argument label in call (have 'name:', expected 'rawValue:')

// Bare:
//class Calculator {
//  lazy var lastResult: Double // 🛑 `Error: Lazy properties must have an initializer`
//}

// Tuple destructuring for property declarations fails with diagnostic, but support can be added:
//@MemberwiseInit
//struct Point2D {
//  let (defaultX, defaultY): (Int, Int) // 🛑 @MemberwiseInit does not support tuple destructuring for property declarations. Use multiple declarations instead.
//}

// Note: Swift's memberwise init supports tuple destructuring for property declarations:
struct Point {
  let (defaultX, defaultY): (Int, Int)
}
_ = Point.init(defaultX: 0, defaultY: 0)

// MARK: - Swift compiler "tests"

// SwiftSyntax 509.0.2 represents `1 + 2 + 3` as a tree of InfixOperatorExprSyntax values,
// but Swift 5.9.0 represents it as SequenceExprSyntax.
@MemberwiseInit
public struct TestManualExpressionFolding {
  var number = 1 + 2 + 3
}
_ = TestManualExpressionFolding(number: 2)

// Swift compiler bug prevents extending inner types (in the same file) when the outer type
// has macros: https://github.com/apple/swift/issues/66450
//@MemberwiseInit(.public)  // 🛑 Circular reference resolving attached macro 'MemberwiseInit'
//public struct BottomMenuState {  // 🛑 Circular reference
//  public struct Button {}
//}
//extension BottomMenuState.Button: Equatable {}
