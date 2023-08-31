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
  @Init(.escaping) public let onCompletion: CompletionHandler
}

@MemberwiseInit(.public)
public struct Job {
  @Init(.public, .escaping, label: "for")
  let callback: CompletionHandler
}
_ = Job(for: { print("Done!") })

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

// Swift's built-in memberwise init:
struct Person11 {
  let _name: String
}
_ = Person11.init(_name: "Blob")

@MemberwiseInit
struct Person20 {
  @Init(.internal) private let age: Int
}
_ = Person20.init(age: 42)

// Swift's built-in memberwise init:
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

// Swift's built-in memberwise init:
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

// Note: Swift's built-in memberwise init supports tuple destructuring for property declarations:
struct Point {
  let (defaultX, defaultY): (Int, Int)
}
_ = Point.init(defaultX: 0, defaultY: 0)
