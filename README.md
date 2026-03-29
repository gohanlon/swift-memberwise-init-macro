<a href="https://gohanlon.com">
  <img src="https://gohanlon.github.io/gohanloncom-assets/images/g-logo.svg" width="50" alt="Galen O'Hanlon" style="margin-bottom: 20px;">
</a><br><br>

# @MemberwiseInit

![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/gohanlon/swift-memberwise-init-macro/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgohanlon%2Fswift-memberwise-init-macro%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/gohanlon/swift-memberwise-init-macro)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgohanlon%2Fswift-memberwise-init-macro%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/gohanlon/swift-memberwise-init-macro)

A Swift Macro for memberwise initializers at any access level, with default values and compile-time safety.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://gohanlon.github.io/gohanloncom-assets/images/swift-memberwise-init-hero-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="https://gohanlon.github.io/gohanloncom-assets/images/swift-memberwise-init-hero-light.png">
  <img alt="MemberwiseInit hero: @MemberwiseInit(.public) annotation on a struct, with the generated memberwise initializer shown below" src="https://gohanlon.github.io/gohanloncom-assets/images/swift-memberwise-init-hero-light.png" width="836">
</picture>

The init derives from your declarations. No boilerplate to maintain. Change a property, and it updates. Make a mistake, and the compiler tells you how to fix it.

- [Quick start](#quick-start)
- [Quick reference](#quick-reference)
- [Features and limitations](#features-and-limitations)
  - [Custom `init` parameter labels](#custom-init-parameter-labels)
  - [Infer type from property initialization expressions](#infer-type-from-property-initialization-expressions)
  - [Default values, even for `let` properties](#default-values-even-for-let-properties)
  - [Explicitly ignore properties](#explicitly-ignore-properties)
  - [Attributed properties require explicit configuration](#attributed-properties-require-explicit-configuration)
  - [Support for property wrappers](#support-for-property-wrappers)
  - [Automatic `@escaping` for closure types (usually)](#automatic-escaping-for-closure-types-usually)
  - [Experimental: Unchecked memberwise initialization](#experimental-unchecked-memberwise-initialization)
  - [Defaulting optionals to nil](#defaulting-optionals-to-nil)
  - [Tuple destructuring](#tuple-destructuring)
  - [Coexists with other initializers](#coexists-with-other-initializers)
- [License](#license)

## Quick start

To use MemberwiseInit:

1. **Installation**
   <br> In Xcode, add MemberwiseInit with: `File` → `Add Package Dependencies…` and enter the package URL:

   > `https://github.com/gohanlon/swift-memberwise-init-macro`

   Or, for SPM-based projects, add it to your package dependencies:

   ```swift
   dependencies: [
     .package(url: "https://github.com/gohanlon/swift-memberwise-init-macro", from: "1.0.0")
   ]
   ```

   And then add the product to all targets that use MemberwiseInit:

   ```swift
   .product(name: "MemberwiseInit", package: "swift-memberwise-init-macro"),
   ```

2. **Import & basic usage**
   <br> After importing MemberwiseInit, add `@MemberwiseInit(.public)` before your struct definition. This provides an initializer with public access, or, if any properties are more restrictive, the macro reports an error. Here, `age` being private:

   ```swift
   import MemberwiseInit

   @MemberwiseInit(.public)
   public struct Person {
     public let name: String
     private var age: Int? = nil
   //┬──────
   //╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
   //   ✏️ Add '@Init(.public)'
   //   ✏️ Replace 'private' access with 'public'
   //   ✏️ Add '@Init(.ignore)'
   }
   ```

   Tell MemberwiseInit to ignore `age` with `@Init(.ignore)`:

   ```swift
   @MemberwiseInit(.public)
   public struct Person {
     public let name: String
     @Init(.ignore) private var age: Int? = nil
   }
   ```

   Alternatively, you can use `@Init(.public)` to include and expose `age` publicly in the `init`:

   ```swift
   @MemberwiseInit(.public)
   public struct Person {
     public let name: String
     @Init(.public) private var age: Int? = nil
   }
   ```

## Quick reference

The two primary macros are `@MemberwiseInit` (attached to the type) and `@Init` (attached to properties).

### `@MemberwiseInit`

Attach to a struct to automatically provide it with a memberwise initializer.

- `@MemberwiseInit`
  <br> Provide an internal memberwise `init`.

- `@MemberwiseInit(.public)`
  <br> Provide a memberwise `init` at the specified access level. Valid access levels: `.private`, `.fileprivate`, `.internal`, `.package`, `.public`, `.open`.

- `@MemberwiseInit(optionalsDefaultNil: true)`
  <br> When set to `true`, give all optional properties a default `init` parameter value of `nil`. Defaults to `false`.

### `@Init`

Attach to the property declarations of a struct that `@MemberwiseInit` is providing an `init` for.

- `@Init`
  <br> Required on properties with custom attributes (e.g. `@State`) to explicitly include them in the initializer.

- `@Init(.ignore)`
  <br> Exclude the property from the initializer. The access level of an ignored property won’t cause the macro to report an error, and the property won’t be included in the `init`. *Note: Ignored properties must be initialized elsewhere.*

- `@Init(.public)`
  <br> Include the property in the `init` at the given access level, regardless of its declared access level. Valid access levels: `.private`, `.fileprivate`, `.internal`, `.package`, `.public`, `.open`.

- `@Init(default: 42)`
  <br> Specifies a default parameter value for the property’s `init` argument, necessary for defaulting `let` properties.

- `@Init(escaping: true)`
  <br> To avoid compiler errors when MemberwiseInit can’t detect that a closure property needs `@escaping`, e.g. when the type is a typealias.

- `@Init(label: String)`
  <br> Assigns a custom parameter label in the provided `init`.
  - Use `@Init(label: "_")` to make the `init` parameter label-less.
  - Diagnostics are emitted for invalid labels, multiple-binding declarations, or naming conflicts among included properties. (Ignored properties don’t cause conflicts.)

- `@Init(.public, default: { true }, escaping: true, label: "where")`
  <br> All arguments can be combined.

- `@InitRaw`
  <br> Attach to property declarations to directly configure MemberwiseInit.

  ```swift
  public macro InitRaw(
    _ accessLevel: AccessLevelConfig? = nil,
    assignee: String? = nil,
    default: Any? = nil,
    escaping: Bool? = nil,
    label: String? = nil,
    type: Any.Type? = nil
  )
  ```

### `@InitWrapper(type:)`

- `@InitWrapper(type: Binding<String>.self)`
  <br> Apply this attribute to properties that are wrapped by a property wrapper and require direct initialization using the property wrapper’s type.

  ```swift
  @MemberwiseInit
  struct CounterView: View {
    @InitWrapper(type: Binding<Bool>.self)
    @Binding var isOn: Bool

    var body: some View { … }
  }
  ```

  > **Note**
  > The above `@InitWrapper` is functionally equivalent to the following `@InitRaw` configuration:<br>
  > `@InitRaw(assignee: "self._isOn", type: Binding<Bool>.self)`.

### Experimental

- `@MemberwiseInit` on `actor`, `class`

- `@_UncheckedMemberwiseInit`
  <br> Generate a memberwise initializer for all properties, regardless of access level, with reduced compile-time safety checks (compared to `@MemberwiseInit`).

## Features and limitations

### Custom `init` parameter labels

Use `@Init(label:)` to customize parameter labels. Use `@Init(label: "_")` for a label-less/wildcard parameter.

```swift
@MemberwiseInit
struct Receipt {
  @Init(label: "for") let item: String
}

_ = Receipt(for: "Coffee")
```

<details>
<summary>More examples</summary>

**Label-less/wildcard parameters**

```swift
@MemberwiseInit
struct Point2D {
  @Init(label: "_") let x: Int
  @Init(label: "_") let y: Int
}
```

Yields:

```swift
init(
  _ x: Int,
  _ y: Int
) {
  self.x = x
  self.y = y
}
```


</details>

### Infer type from property initialization expressions

Explicit type annotations are not required when properties are initialized with an expression whose syntax implies type information — most Swift literals and common expressions:

```swift
@MemberwiseInit
struct Example {
  var count = 0              // Int
  var name = ""              // String
  var flag = true            // Bool
  var items = [1, 2, 3]      // [Int]
  var lookup = ["key": 1]    // [String: Int]
  var point = (1.0, 2.0)     // (Double, Double)
  var empty = [Int]()        // [Int]
  var cast = 1 as Double     // Double
}
```

Because MemberwiseInit operates at the syntax level — not the type level — it can’t infer types from arbitrary expressions the way Swift’s memberwise initializer can. When the type isn’t syntactically evident, add an explicit type annotation.

<details>
<summary>Full list of supported expressions</summary>

```swift
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
```

</details>

### Default values, even for `let` properties

Use `@Init(default:)` to set default `init` parameter values. This is particularly useful for `let` properties, since `let x = 5` fixes the value rather than making it an overridable default. For `var` properties, prefer assigning a value directly (e.g., `var number = 0`) — it naturally becomes the `init` parameter's default.

```swift
@MemberwiseInit
struct ButtonStyle {
  @Init(default: true) let isEnabled: Bool
  @Init(default: Color.blue) let backgroundColor: Color
  @Init(default: Font.system(size: 16)) let font: Font
}

_ = ButtonStyle()                                     // uses defaults
_ = ButtonStyle(backgroundColor: .red, font: .body)   // override some
```

### Explicitly ignore properties

Use `@Init(.ignore)` to exclude a property from the initializer. Ignored properties must have a default value. Without `@Init(.ignore)`, a restrictive property like `private var age` would cause MemberwiseInit to report an error. In line with Swift’s memberwise initializer, `let` properties with assigned default values are automatically ignored.

```swift
@MemberwiseInit(.public)
public struct Person {
  public let name: String
  @Init(.ignore) private var age: Int? = nil  // 👈 Ignored and given a default value
}
```

<details>
<summary>Expanded init</summary>

By marking `age` as ignored, MemberwiseInit creates a public initializer without the `age` parameter:

```swift
public init(
  name: String
) {
  self.name = name
}
```

</details>

### Attributed properties require explicit configuration

Properties with custom attributes (e.g. `@State`, `@Published`) are not automatically included in the initializer. MemberwiseInit requires you to explicitly configure them with `@Init` or `@Init(.ignore)`:

```swift
import SwiftUI
@MemberwiseInit(.internal)
struct MyView: View {
  @State var isOn: Bool
//┬────────────────────
//╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with ‘@State’ attribute
//   ✏️ Add ‘@Init’
//   ✏️ Add ‘@Init(.ignore)’ and a default value

  var body: some View { … }
}
```

<details>
<summary>Why, and how to fix</summary>

Attributed properties often have initialization semantics that differ from plain stored properties. For example, initializing `@State` properties in a memberwise `init` is a common pitfall in SwiftUI — the state is only assigned upon the initial rendering of the view. Rather than silently including or excluding these properties, MemberwiseInit asks you to be explicit.

1. **Add `@Init` to include the property**

   ```swift
   @MemberwiseInit(.internal)
   struct MyView: View {
     @Init @State var isOn: Bool  // 👈 Explicitly included

     var body: some View { … }
   }
   ```

2. **Add `@Init(.ignore)` and a default value**

   ```swift
   @MemberwiseInit(.internal)
   struct MyView: View {
     @Init(.ignore) @State var isOn: Bool = false  // 👈 Explicitly excluded

     var body: some View { … }
   }
   ```

</details>

### Support for property wrappers

Apply `@InitWrapper` to properties that are wrapped by a property wrapper and require direct initialization using the property wrapper’s type. For example, here’s a simple usage with SwiftUI’s `@Binding`:

```swift
import SwiftUI

@MemberwiseInit
struct CounterView: View {
  @InitWrapper(type: Binding<Int>.self)
  @Binding var count: Int

  var body: some View { … }
}
```

This yields:

```swift
internal init(
  count: Binding<Int>
) {
  self._count = count
}
```

### Automatic `@escaping` for closure types (usually)

MemberwiseInit automatically marks closure parameters as `@escaping` when the closure type appears directly in the property’s type annotation:

```swift
@MemberwiseInit(.public)
public struct TaskRunner {
  public let onCompletion: () -> Void
}
// ➜ public init(onCompletion: @escaping () -> Void)
```

<details>
<summary>When it doesn’t work: typealiased closures</summary>

Because Swift Macros operate at the syntax level, MemberwiseInit can’t see through a typealias to detect that `@escaping` is needed. This leads to a compiler error:

```
🛑 Assigning non-escaping parameter ‘onCompletion’ to an @escaping closure
```

Use `@Init(escaping: true)` to fix this:

```swift
public typealias CompletionHandler = @Sendable () -> Void

@MemberwiseInit(.public)
public struct TaskRunner: Sendable {
  @Init(escaping: true) public let onCompletion: CompletionHandler  // 👈
}
// ➜ public init(onCompletion: @escaping CompletionHandler)
```

</details>

### Experimental: Unchecked memberwise initialization

`@_UncheckedMemberwiseInit` is an experimental macro that generates an initializer for all properties of a type, regardless of their declared access levels. It bypasses access control enforcement and includes attributed properties without requiring `@Init`.

```swift
@_UncheckedMemberwiseInit(.public)
public struct APIResponse: Codable {
  public let id: String
  @Monitored internal var statusCode: Int   // ⚠️ exposed publicly, unchecked
  private var rawResponse: Data             // ⚠️ exposed publicly, unchecked
}
```

<details>
<summary>Expanded init</summary>

This yields a public initializer that includes all properties, regardless of their access level or attributes. Unlike `@MemberwiseInit`, no `@Init` annotations are needed:

```swift
public init(
  id: String,
  statusCode: Int,      // ⚠️ internal → public
  rawResponse: Data     // ⚠️ private → public
) {
  self.id = id
  self.statusCode = statusCode
  self.rawResponse = rawResponse
}
```

</details>

### Defaulting optionals to nil

Swift’s memberwise initializer defaults optional properties to `nil` — callers can omit them. `@MemberwiseInit` intentionally does not:

```swift
@MemberwiseInit
struct User {
  let id: Int
  let name: String?
}
```

Generates `init(id: Int, name: String?)` — not `init(id: Int, name: String? = nil)`. You must pass `name` explicitly.

This is deliberate. Swift’s implicit nil-defaulting means the compiler won’t flag call sites when an optional property is added or removed. By requiring explicit arguments, `@MemberwiseInit` lets the compiler catch these changes for you.

#### Opting in

When explicit `nil` at every call site is more noise than signal — e.g. `Codable` structs modeling HTTP APIs — use `optionalsDefaultNil: true`:

```swift
@MemberwiseInit(.public, optionalsDefaultNil: true)
public struct User: Codable {
  public let id: Int
  public let name: String?
  public let email: String?
  public let address: String?
}
```

Yields:

```swift
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
```

> **Note**
> [`@Init(default:)`](#default-values-even-for-let-properties) is a more targeted alternative for defaulting individual properties. For `var` properties, assigning `nil` directly (`var name: String? = nil`) also works — the default flows through to the init parameter naturally.

### Tuple destructuring

Tuple property declarations are supported — each element becomes a separate `init` parameter, with per-element defaults extracted from `var` tuple literals.

```swift
@MemberwiseInit
struct Point2D {
  var (x, y): (Int, Int) = (0, 0)
}
// ➜ init(x: Int = 0, y: Int = 0)
```

### Coexists with other initializers

Unlike [Swift's memberwise initializer][swifts-memberwise-init] — which is suppressed when any explicit `init` is present — MemberwiseInit's generated initializer always coexists with your other initializers, even for types conforming to protocols like `Decodable` and `RawRepresentable`.

> **Note**
> Swift omits its memberwise initializer when any explicit `init` is present. You can do an ["extension dance"][extension-dance] to retain Swift's memberwise `init`, but with tradeoffs.

## License

MemberwiseInit is available under the MIT license. See the [LICENSE][mit-license] file for more info.

[swifts-memberwise-init]: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Memberwise-Initializers-for-Structure-Types "Swift.org: Memberwise Initializers for Structure Types"
[mit-license]: https://github.com/gohanlon/swift-memberwise-init-macro/blob/main/LICENSE "MIT license"
[extension-dance]: https://gist.github.com/gohanlon/6aaeff970c955c9a39308c182c116f64
