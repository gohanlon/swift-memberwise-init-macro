# @MemberwiseInit

![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/gohanlon/swift-memberwise-init-macro/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgohanlon%2Fswift-memberwise-init-macro%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/gohanlon/swift-memberwise-init-macro)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgohanlon%2Fswift-memberwise-init-macro%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/gohanlon/swift-memberwise-init-macro)

A Swift Macro for enhanced automatic memberwise initializers, greatly reducing manual boilerplate:

* **~1,100 deletions** to [Point-Free’s Website with MemberwiseInit][pointfreeco-website-memberwiseinit].
* **~1,300 deletions** to [Point-Free’s Isowords with MemberwiseInit][pointfreeco-isowords-memberwiseinit].

![swift-memberwise-init-hero04](https://github.com/gohanlon/swift-memberwise-init-macro/assets/3375/5aab978d-fe31-4d2a-968a-b540adbd1355)

Informed by explicit developer cues, MemberwiseInit can more often automatically provide your intended memberwise `init`, while maintaining a safe-by-default standard in line with [Swift’s memberwise initializers][swifts-memberwise-init].

> [!IMPORTANT]
> `@MemberwiseInit` is a Swift Macro requiring **swift-tools-version: 5.9** or later (**Xcode 15** onwards).

* [Quick start](#quick-start)
* [Quick reference](#quick-reference)
* [Features and limitations](#features-and-limitations)
  * [Custom `init` parameter labels](#custom-init-parameter-labels)
  * [Infer type from property initialization expressions](#infer-type-from-property-initialization-expressions)
  * [Default values, even for `let` properties](#default-values-even-for-let-properties)
  * [Explicitly ignore properties](#explicitly-ignore-properties)
  * [Attributed properties are ignored by default, but includable](#attributed-properties-are-ignored-by-default-but-includable)
  * [Support for property wrappers](#support-for-property-wrappers)
  * [Automatic `@escaping` for closure types (usually)](#automatic-escaping-for-closure-types-usually)
  * [Experimental: Unchecked memberwise initialization](#experimental-unchecked-memberwise-initialization)
  * [Deprecated: Deunderscore parameter names](#deprecated-deunderscore-parameter-names)
  * [Experimental: Defaulting optionals to nil](#experimental-defaulting-optionals-to-nil)
  * [Tuple destructuring in property declarations isn’t supported (yet)](#tuple-destructuring-in-property-declarations-isnt-supported-yet)
* [Background](#background)
* [License](#license)

## Quick start

To use MemberwiseInit:

1. **Installation**
   <br> In Xcode, add MemberwiseInit with: `File` → `Add Package Dependencies…` and input the package URL:

   > `https://github.com/gohanlon/swift-memberwise-init-macro`

   Or, for SPM-based projects, add it to your package dependencies:

   ```swift
   dependencies: [
     .package(url: "https://github.com/gohanlon/swift-memberwise-init-macro", from: "0.6.0")
   ]
   ```

   And then add the product to all targets that use MemberwiseInit:

   ```swift
   .product(name: "MemberwiseInit", package: "swift-memberwise-init-macro"),
   ```

2. **Import & basic usage**
   <br> After importing MemberwiseInit, add `@MemberwiseInit(.public)` before your struct definition. This provides an initializer with public access, or, if any properties are more restrictive, the macro will not compile and will emit an error diagnostic. Here, `age` being private makes the macro emit an error:

   ```swift
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

MemberwiseInit includes three macros:

### `@MemberwiseInit`

Attach to a struct to automatically provide it with a memberwise initializer.

* `@MemberwiseInit`
  <br> Provide an internal memberwise `init`.

* `@MemberwiseInit(.public)`
  <br> Provide a memberwise `init` at the provided access level. Valid access levels: `.private`, `.fileprivate`, `.internal`, `.package`, `.public`, `.open`.

### `@Init`

Attach to the property declarations of a struct that `@MemberwiseInit` is providing an `init` for.

* `@Init`
  <br> Include a property that would otherwise be ignored, e.g., attributed properties such as SwiftUI’s `@State` properties.

* `@Init(.ignore)`
  <br> Ignore that member property. The access level of an ignored property won’t cause the macro to fail, and the property won’t be included in the `init`. *Note: Ignored properties must be initialized elsewhere.*

* `@Init(.public)`
  <br> For the provided `init`, consider the property as having a different access level than its declared access level. Valid access levels: `.private`, `.fileprivate`, `.internal`, `.package`, `.public`, `.open`.

* `@Init(default: 42)`
  <br> Specifies a default parameter value for the property’s `init` argument, necessary for defaulting `let` properties.

* `@Init(escaping: true)`
  <br> To avoid compiler errors when a property’s `init` argument can’t automatically be `@escaped`, e.g. when a property’s type uses a typealias that represents a closure.

* `@Init(label: String)`
  <br> Assigns a custom parameter label in the provided `init`.
  * Use `@Init(label: "_")` to make the `init` parameter label-less.
  * Diagnostic errors arise from invalid labels, when misapplied to declarations having multiple bindings, or from naming conflicts among properties included in the `init`. (Ignored properties don’t cause conflicts.)

* `@Init(.public, default: { true }, escaping: true, label: "where")`
  <br> All arguments can be combined.

### `@InitWrapper(type:)`

* `@InitWrapper(type: Binding<String>.self)`
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

### Etcetera

* `@InitRaw`
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

* `@MemberwiseInit(_optionalsDefaultNil: true)` *(experimental)*
  <br> When set to `true`, give all optional properties a default `init` parameter value of `nil`. For non-public initializers, optional `var` properties default to `nil` unless this parameter is explicitly set to `false`.

* `@MemberwiseInit(_deunderscoreParameters: true)` *(deprecated, use `@Init(label:)` instead)*
  <br> Drop underscore prefix from generated `init` parameter names, unless doing so would result in a naming conflict. Ignored properties won't contribute to conflicts, and overridable using `@Init(label:)`.

* `@MemberwiseInit` on  `actor`, `class` *(experimental)*
  <br> Attachable to actor and class.

* `@_UncheckedMemberwiseInit` *(experimental)*
  <br> Generate a memberwise initializer for all properties, regardless of access level, with reduced compile-time safety checks (compared to `@MemberwiseInit`).

## Features and limitations

### Custom `init` parameter labels

To control the naming of parameters in the provided initializer, use `@Init(label: String)`. Tip: For a label-less/wildcard parameter, use `@Init(label: "_")`.

#### Explanation

Customize your initializer parameter labels with `@Init(label: String)`:

1. **Label-less/wildcard parameters**

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

2. **Custom parameter labels**

   ```swift
   @MemberwiseInit
   struct Receipt {
     @Init(label: "for") let item: String
   }
   ```

   Yields:

   ```swift
   init(
     for item: String  // 👈
   ) {
     self.item = item
   }
   ```

### Infer type from property initialization expressions

Explicit type annotations are not required when properties are initialized with an expression whose syntax implies type information, e.g., most Swift literals:

```swift
@MemberwiseInit
struct Example {
  var count = 0  // 👈 `Int` is inferred
}
```

#### Explanation

Explicit type specification can feel redundant. Helpfully, Swift’s memberwise initializer infers type from arbitrary expressions.

MemberwiseInit, as a Swift Macro, operates at the syntax level and doesn’t inherently understand type information. Still, many expressions which imply type from their syntax alone are supported, including all of the following:

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

### Default values, even for `let` properties

Use `@Init(default: Any)` to set default parameter values in the initializer. This is particularly useful for `let` properties, which otherwise cannot be defaulted after declaration. For `var` properties, consider using a declaration initializer (e.g., `var number = 0`) as a best practice.

#### Explanation

MemberwiseInit, like Swift, utilizes variable initializers to assign default values to `var` properties:

```swift
@MemberwiseInit
struct UserSettings {
  var theme = "Light"
  var notificationsEnabled = true
}
```

This yields:

```swift
internal init(
  theme: String = "Light",
  notificationsEnabled: Bool = true
) {
  self.theme = theme
  self.notificationsEnabled = notificationsEnabled
}
```

For `let` properties, `@Init(default:)` enables setting default values in the initializer:

```swift
@MemberwiseInit
struct ButtonStyle {
  @Init(default: Color.blue) let backgroundColor: Color
  @Init(default: Font.system(size: 16)) let font: Font
}
```

This yields:

```swift
internal init(
  backgroundColor: Color = Color.blue,
  font: Font = Font.system(size: 16)
) {
  self.backgroundColor = backgroundColor
  self.font = font
}
```

### Explicitly ignore properties

Use `@Init(.ignore)` to exclude a property from MemberwiseInit’s initializer; ensure ignored properties are otherwise initialized to avoid compiler errors.

#### Explanation

The `@Init(.ignore)` attribute excludes properties from the initializer, potentially allowing MemberwiseInit to produce a more accessible initializer for the remaining properties.

For example:

```swift
@MemberwiseInit(.public)
public struct Person {
  public let name: String
  @Init(.ignore) private var age: Int? = nil  // 👈 Ignored and given a default value
}
```

By marking `age` as ignored, MemberwiseInit creates a public initializer without the `age` parameter:

```swift
public init(
  name: String
) {
  self.name = name
}
```

If `age` weren't marked as ignored, MemberwiseInit would fail to compile and provide a diagnostic.

> **Note**
> In line with Swift’s memberwise initializer, MemberwiseInit automatically ignores `let` properties with assigned default values, as reassigning such properties within the initializer would be invalid.

### Attributed properties are ignored by default, but includable

If MemberwiseInit ignores an attributed property and causes a compiler error, you have two immediate remedies:

1. Assign a default value to the property.
2. Explicitly include the property in the initializer using the `@Init` annotation.

#### Explanation

Unlike the compiler’s default behavior, MemberwiseInit takes a more cautious approach when dealing with member properties that have attributes attached.

For a SwiftUI-based illustration, let’s look at a view without MemberwiseInit:

```swift
import SwiftUI
struct MyView: View {
  @State var isOn: Bool

  var body: some View { … }
}
```

Swift provides the following internal memberwise `init`:

```swift
internal init(
  isOn: Bool
) {
  self.isOn = isOn
}
```

However, initializing `@State` properties in this manner is a common pitfall in SwiftUI. The `isOn` state is only assigned upon the initial rendering of the view, and this assignment doesn’t occur on subsequent renders. To safeguard against this, MemberwiseInit defaults to ignoring attributed properties:

```swift
import SwiftUI
@MemberwiseInit(.internal)  // 👈
struct MyView: View {
  @State var isOn: Bool

  var body: some View { … }
}
```

This leads MemberwiseInit to provided the following initializer:

```swift
internal init() {
}  // 🛑 Compiler error:↵
// Return from initializer without initializing all stored properties
```

From here, you have two alternatives:

1. **Assign a default value**
   <br> Defaulting the property to a value makes the provided `init` valid, as the provided `init` no longer needs to initialize the property.

   ```swift
   import SwiftUI
   @MemberwiseInit(. internal)
   struct MyView: View {
     @State var isOn: Bool = false  // 👈 Default value provided

     var body: some View { … }
   }
   ```

   The resulting `init` is:

   ```swift
   internal init() {
   }  // 🎉 No error, all stored properties are initialized
   ```

2. **Use `@Init` annotation**
   <br> If you understand the behavior the attribute imparts, you can explicitly mark the property with `@Init` to include it in the initializer.

   ```swift
   import SwiftUI
   @MemberwiseInit(.internal)
   struct MyView: View {
     @Init @State var isOn: Bool  // 👈 `@Init`

     var body: some View { … }
   }
   ```

   This yields:

   ```swift
   internal init(
     isOn: Bool
   ) {
     self.isOn = isOn
   }
   ```

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

MemberwiseInit automatically marks closures in initializer parameters as `@escaping`. If using a typealias for a closure, explicitly annotate the property with `@Init(escaping: true)`.

#### Explanation

Swift Macros operate at the syntax level and don’t inherently understand type information. MemberwiseInit will add `@escaping` for closure types, provided that the closure type is directly declared as part of the property. Fortunately, this is the typical scenario.

In contrast, Swift’s memberwise initializer has the advantage of working with type information. This allows it to recognize and add `@escaping` even when the closure type is “obscured” within a typealias.

Consider the following struct:

```swift
public struct TaskRunner {
  public let onCompletion: () -> Void
}
```

Through observation (or by delving into the compiler’s source code), we can see that Swift automatically provides the following internal `init`:

```swift
internal init(
  onCompletion: @escaping () -> Void  // 🎉 `@escaping` automatically
) {
  self.onCompletion = onCompletion
}
```

Now, with MemberwiseInit:

```swift
@MemberwiseInit  // 👈
public struct TaskRunner {
  public let onCompletion: () -> Void
}
```

we get the same `init`, which we can inspect using Xcode’s “Expand Macro” command:

```swift
internal init(
  onCompletion: @escaping () -> Void  // 🎉 `@escaping` automatically
) {
  self.onCompletion = onCompletion
}
```

And we can have MemberwiseInit provide a public `init`:

```swift
@MemberwiseInit(.public)  // 👈 `.public`
public struct TaskRunner {
  public let onCompletion: () -> Void
}
```

This yields:

```swift
public init(  // 🎉 `public`
  onCompletion: @escaping () -> Void
) {
  self.onCompletion = onCompletion
}
```

Now, suppose the type of `onCompletion` got more complex and we decided to extract a typealias:

```swift
public typealias CompletionHandler = @Sendable () -> Void

@MemberwiseInit(.public)
public struct TaskRunner: Sendable {
  public let onCompletion: CompletionHandler
}
```

Because Swift Macros don’t inherently understand type information, MemberwiseInit cannot “see” that `CompletionHandler` represents a closure type that needs to be marked `@escaping`. This leads to a compiler error:

```swift
public init(
  onCompletion: CompletionHandler  // 👈 Missing `@escaping`!
) {
  self.onCompletion = onCompletion  // 🛑 Compiler error:↵
  // Assigning non-escaping parameter 'onCompletion' to an @escaping closure
}
```

To address this, when using a typealias for closures, you must explicitly mark the property with `@Init(escaping: true)`:

```swift
public typealias CompletionHandler = @Sendable () -> Void

@MemberwiseInit(.public)
public struct TaskRunner: Sendable {
  @Init(escaping: true) public let onCompletion: CompletionHandler  // 👈
}
```

which results in the following valid and inspectable public `init`:

```swift
public init(
  onCompletion: @escaping CompletionHandler  // 🎉 Correctly `@escaping`
) {
  self.onCompletion = onCompletion
}
```

### Experimental: Unchecked memberwise initialization

`@_UncheckedMemberwiseInit` is an experimental macro that bypasses compile-time safety checks and strict access control enforcement. It generates an initializer for all properties of a type, regardless of their declared access levels. Use it judiciously.

Key characteristics:

- Generates an initializer that includes all properties, regardless of their declared access levels
- Includes attributed properties by default (differs from `@MemberwiseInit`)
- Follows the same usage pattern as `@MemberwiseInit`

Example:

```swift
@_UncheckedMemberwiseInit(.public)
public struct APIResponse: Codable {
  public let id: String
  @Monitored internal var statusCode: Int
  private var rawResponse: Data

  // Computed properties and methods...
}
```

This yields a public initializer that includes all properties, regardless of their access level or attributes. Unlike `@MemberwiseInit`, this macro doesn't require `@Init` annotations or any other explicit opt-ins. The resulting initializer is:

```swift
public init(
  id: String,
  statusCode: Int,
  rawResponse: Data
) {
  self.id = id
  self.statusCode = statusCode
  self.rawResponse = rawResponse
}
```

### Deprecated: Deunderscore parameter names

> **Warning**
> `_deunderscoreParameters` is deprecated and will be removed in version 1.0. Use `@Init(label:)` on individual properties instead.

Set `@MemberwiseInit(_deunderscoreParameters: true)` to strip the underscore prefix from properties when generating initializer parameter names. If you wish to maintain the underscore or provide a custom label on a particular property, use `@Init(label: String)`.

If the removal of the underscore would lead to a naming conflict among the properties included in the initializer, MemberwiseInit will not strip the underscore. (Ignored properties won’t contribute to conflicts.)

#### Explanation

In Swift, properties prefixed with an underscore are conventionally used as internal storage or backing properties. Setting `_deunderscoreParameters: true` respects this convention, producing initializer parameter names that omit the underscore:

```swift
@MemberwiseInit(.public, _deunderscoreParmeters: true)
public struct Review {
  @Init(.public) private let _rating: Int

  public var rating: String {
    String(repeating: "⭐️", count: self._rating)
  }
}
```

This yields:

```swift
public init(
  rating: Int  // 👈 Non-underscored parameter
) {
  self._rating = rating
}
```

To override the deunderscore behavior at the property level, use `@Init(label: String)`:

```swift
@MemberwiseInit(.public, _deunderscoreParameters: true)
public struct Review {
  @Init(.public, label: "_rating") private let _rating: Int
}
```

This yields:

```swift
public init(
  _rating: Int  // 👈 Underscored parameter
) {
  self._rating = _rating
}
```

### Experimental: Defaulting optionals to nil

Use `@MemberwiseInit(_optionalsDefaultNil: Bool)` to explicitly control whether optional properties are defaulted to `nil` in the provided initializer:

* Set `_optionalsDefaultNil: true` to default all optional properties to `nil`, trading off compile-time guidance.
* Set `_optionalsDefaultNil: false` to ensure that MemberwiseInit never defaults optional properties to `nil`.

The default behavior of MemberwiseInit regarding optional properties aligns with Swift’s memberwise initializer:

* For non-public initializers, `var` optional properties automatically default to `nil`.
* For public initializers, MemberwiseInit follows Swift’s cautious approach to public APIs by requiring all parameters explicitly, including optionals, unless `_optionalsDefaultNil` is set to `true`.
* `let` optional properties are never automatically defaulted to `nil`. Setting `_optionalsDefaultNil` to `true` is the only way to cause them to default to `nil`.

> **Note**
> Use [`@Init(default:)`](#default-values-even-for-let-properties) to generally specify default values — it’s a safer, more explicit alternative to `_optionalsDefaultNil`.

#### Explanation

With `_optionalsDefaultNil`, you gain control over a default behavior of Swift’s memberwise init. And, it allows you to explicitly opt-in to your public initializer defaulting optional properties to `nil`.

Easing instantiation is the primary purpose of `_optionalsDefaultNil`, and is especially useful when your types mirror a loosely structured external dependency, e.g. `Codable` structs that mirror HTTP APIs. However, `_optionalsDefaultNil` has a drawback: when properties change, the compiler won’t flag outdated instantiations, risking unintended `nil` assignments and potential runtime errors.

In Swift:

* `var` property declarations that include an initial value naturally lead to default memberwise `init` parameter values in both Swift’s and MemberwiseInit’s initializers.
* `let` properties assigned a value at declaration become immutable, so they can’t be leveraged to specify default `init` parameter values.

For instance, `var` property declarations can be initialized to `nil`:

```swift
@MemberwiseInit(.public)
public struct User {
  public var name: String? = nil  // 👈
}
_ = User()  // 'name' defaults to 'nil'
```

Yields:

```swift
public init(
  name: String? = nil  // 👈
) {
  self.name = name
}
```

This isn’t feasible for `let` properties:

```swift
@MemberwiseInit(.public)
public struct User {
  public let name: String? = nil  // ✋ 'name' is 'nil' forever
}
```

Where appriopriate, `_optionalsDefaultNil` can be a convenient way to default optional properties to `nil` in the generated initializer:

```swift
@MemberwiseInit(.public, _optionalsDefaultNil: true)
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

### Tuple destructuring in property declarations isn’t supported (yet)

Using tuple syntax in property declarations isn’t supported:

```swift
@MemberwiseInit
struct Point2D {
  let (x, y): (Int, Int)
//┬─────────────────────
//╰─ 🛑 @MemberwiseInit does not support tuple destructuring for
//     property declarations. Use multiple declartions instead.
}
```

## Background

[Swift’s automatically provided memberwise initializers][swifts-memberwise-init] deftly cut down on boilerplate for structs. Yet, they must always error on the side of caution to ensure no presumptions are made about the developer’s intent. While this conservative approach is essential for avoiding unintended behaviors, it too often leads back to using boilerplate initializers.

Swift’s memberwise initializer can’t assume that a public type should be constructible from external modules, so it never provides an initializer having an access level greater than “internal.” To safely add a public initializer to a type requires an explicit developer intent. Traditionally, that means manually declaring an initializer, or using Xcode to generate a boilerplate initializer. Take this simple example:

```swift
public struct Person {
  public let name: String
}
```

Swift transparently adds the following, familiar `init`:

```swift
internal init(
  name: String
) {
  self.name = name
}
```

MemberwiseInit can provide the exact same `init`:

```swift
@MemberwiseInit  // 👈
public struct Person {
  public let name: String
}
```

Unlike Swift’s memberwise initializer, you can inspect MemberwiseInit’s initializer using Xcode by right clicking on `@MemberwiseInit` and the selecting “Expand Macro”.

> **Note**
> Introducing an explicit `init` suppresses the addition of Swift’s memberwise initializer. MemberwiseInit’s initializer is always added and can coexist with your other initializers, even for types directly conforming to `init`-specifying protocols like `Decodable` and `RawRepresentable`.[^1]

In contrast to Swift’s memberwise initializer, MemberwiseInit can provide an initializer at any access level, including public. You explicitly instruct MemberwiseInit to provide a public `init` by marking `Person` with `@MemberwiseInit(.public)`:

```swift
@MemberwiseInit(.public)  // 👈 `.public`
public struct Person {
  public let name: String
}
```

With this adjustment, expanding the macro yields:

```swift
public init(  // 🎉 `public`
  name: String
) {
  self.name = name
}
```

Suppose you then added a private member to `Person`:

```swift
@MemberwiseInit(.public)
public struct Person {
  public let name: String
  private var age: Int?  // 👈 `private`
}
```

Now, rather than degrading to providing a private `init` as Swift’s memberwise initializer must, MemberwiseInit instead fails with a diagnostic:

```swift
@MemberwiseInit(.public)
public struct Person {
  public let name: String
  private var age: Int?
//┬──────
//╰─ 🛑 @MemberwiseInit(.public) would leak access to 'private' property
//   ✏️ Add '@Init(.public)'
//   ✏️ Replace 'private' access with 'public'
//   ✏️ Add '@Init(.ignore)' and an initializer
}
```

> **Note**
> Both Swift’s and MemberwiseInit’s memberwise initializer are safe by default. Neither will provide an initializer that unintentionally leaks access to more restricted properties.

To publicly expose `age` via MemberwiseInit’s initializer, mark it with `@Init(.public)`:

```swift
@MemberwiseInit(.public)
public struct Person {
  public let name: String
  @Init(.public) private var age: Int?  // 👈 `@Init(.public)`
}
```

and now MemberwiseInit provides a public `init` that exposes the private `age` property:

```swift
public init(  // 👈 `public`
  name: String,
  age: Int?  // 👈 Exposed deliberately
) {
  self.name = name
  self.age = age
}
```

Compared to Swift’s memberwise initializer, MemberwiseInit’s approach has several advantages:

1. **Clear Intent**: `@MemberwiseInit(.public)` is a declaration of the developer’s explicit intention, thereby avoiding any ambiguity about the desired access level for the initializer.
2. **Safety**: By failing fast when expectations aren’t met, MemberwiseInit prevents unintended access level leaks that could compromise the encapsulation and safety of the code. That is, it is still safe by default.
3. **Simpler**: MemberwiseInit’s reduced complexity makes it easier to use, as its behavior is more direct and predictable.
4. **Learnable**: `@MemberwiseInit` can be applied naively, and most usage issues can be remedied in response to MemberwiseInit’s immediate feedback via diagnostic messages[^2].

Let’s give `age` a default value:

```swift
@MemberwiseInit(.public)
public struct Person {
  public let name: String
  @Init(.public) private var age: Int? = nil  // 👈 Default value
}
```

and now MemberwiseInit’s `init` parameter includes the default `age` value:

```swift
public init(
  name: String,
  age: Int? = nil  // 👈 Default value
) {
  self.name = name
  self.age = age
}
```

Suppose we don’t want to expose `age` publicly via the `init`. As long as `age` is initialized in another way (e.g. declared with a default value), we can explicitly tell MemberwiseInit to ignore it using `@Init(.ignore)`:

```swift
@MemberwiseInit(.public)
public struct Person {
  public let name: String
  @Init(.ignore) private var age: Int? = nil  // 👈 `.ignore`
}
```

Now MemberwiseInit ignores the private `age` property and provides a public `init`:

```swift
public init(  // 👈 `public`, ignoring `age` property
  name: String
) {
  self.name = name
}
```

## License

MemberwiseInit is available under the MIT license. See the [LICENSE][mit-license] file for more info.

[^1]: Swift omits its memberwise initializer when any explicit `init` is present. You can do an [“extension dance”][extension-dance] to retain Swift’s memberwise `init`, but with imposed tradeoffs.
[^2]: MemberwiseInit currently has some diagnostics accompanied by fix-its. However, it is actively working towards providing a more extensive and comprehensive set of fix-its. There are also usage errors presently left to the compiler checking the provided `init` that may be addressed directly in the future, e.g. rather than implicitly ignoring attributed properties marked with attributes like `@State`, MemberwiseInit may raise a diagnostic error and fix-its to add either `@Init`, `@Init(.ignore)`, or to assign a default value for the variable declaration.

[swifts-memberwise-init]: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Memberwise-Initializers-for-Structure-Types "Swift.org: Memberwise Initializers for Structure Types"
[pointfreeco-website-memberwiseinit]: https://github.com/gohanlon/pointfreeco/compare/main...memberwise-init-macro "Demo of Point-Free’s website using @MemberwiseInit"
[pointfreeco-isowords-memberwiseinit]: https://github.com/gohanlon/isowords/compare/main...memberwise-init-macro "Demo of Point-Free’s Isowords using @MemberwiseInit"
[mit-license]: https://github.com/gohanlon/swift-memberwise-init-macro/blob/main/LICENSE "MIT license"
[extension-dance]: https://gist.github.com/gohanlon/6aaeff970c955c9a39308c182c116f64
