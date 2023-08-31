import MemberwiseInit

@MemberwiseInit(.public)
public struct Person1 {
  @Init(.public) let name: String
  @Init(.public) private var age: Int? = nil
}
_ = Person1(name: "Blob")
_ = Person1(name: "Blob", age: 42)


@MemberwiseInit(.public)
public struct Person2 {
  @Init(.public) let name: String
  @Init(.ignore) private var age: Int? = nil
}
_ = Person2(name: "Blob")
//_ = Person2(name: "Blob", age: 42) // 🛑 Incorrect argument label in call


@MemberwiseInit(.public)
public struct Dependency: Sendable {
  @Init(.public) let _get: @Sendable (_ key: String, _ type: Any.Type) -> (any Sendable)?
  @Init(.public) let _set: @Sendable (_ value: (any Sendable)?, _ key: String) -> Void
  @Init(.public) let _values: @Sendable (_ key: String, _ value: Any.Type) -> AsyncStream<(any Sendable)?>
}
_ = Dependency(
  get: { key, type in },
  set: { value, key in},
  values: { key, value in
    return .init { continuation in
      // …
    }
  }
)


public typealias CompletionHandler = @Sendable () -> Void

@MemberwiseInit(.public)
public struct TaskRunner: Sendable {
  @Init(.escaping) public let onCompletion: CompletionHandler
}


import SwiftUI
@MemberwiseInit(.public)
struct MyView: View {
  @State var isOn: Bool = false  // 👈 initializer clause

  var body: some View { EmptyView() }
}
_ = MyView.init()

@MemberwiseInit
struct MyView2: View {
  @Init @State var isOn: Bool  // 👈 @Init

  var body: some View { EmptyView() }
}
_ = MyView2.init(isOn: true)


//@MemberwiseInit
//struct Point2D {
//  let (x, y): (Int, Int)  // 🛑 @MemberwiseInit does not support tuple destructuring for property declarations. Use multiple declarations instead.
//}


@MemberwiseInit
struct Person10 {
  let _name: String
}
_ = Person10(name: "Foo")
//_ = Person10(_name: "Foo") // 🛑 No exact matches in call to initializer

// Bare:
struct Person11 {
  let _name: String
}
_ = Person11.init(_name: "Foo")


@MemberwiseInit
struct Person20 {
  @Init(.internal) private let age: Int
}
_ = Person20(age: 42)

// Bare:
//struct Person21 {
//  private let age: Int
//}
//_ = Person21(age: 42) // Error: 'Person21' initializer is inaccessible due to 'private' protection level

//@MemberwiseInit
//struct Person22 {
//  private let age: Int
//}
//_ = Person22(age: 42) // Error: 'Person22' initializer is inaccessible due to 'private' protection level


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
_ = Person30.init(name: "Foo")

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
//_ = Person31.init(name: "Foo") // 🛑 Incorrect argument label in call (have 'name:', expected 'from:')

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
_ = Person40.init(name: "Foo")

// Bare:
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
//_ = Person41.init(name: "Foo") // 🛑 Incorrect argument label in call (have 'name:', expected 'rawValue:')


// Bare:
//class Calculator {
//  lazy var lastResult: Double // 🛑 `Error: Lazy properties must have an initializer`
//}


// MemberwiseInit does not supports tuple destructuring for property declarations (yet):
//@MemberwiseInit
//struct Point2D {
//  let (defaultX, defaultY): (Int, Int) // 🛑 @MemberwiseInit does not support tuple destructuring for property declarations. Use multiple declarations instead.
//}

// Swift does support tuple destructuring for property declarations:
// Bare:
struct Point {
  let (defaultX, defaultY): (Int, Int)
}
_ = Point.init(defaultX: 0, defaultY: 0)
