# @MemberwiseInit

![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/gohanlon/swift-memberwise-init-macro/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgohanlon%2Fswift-memberwise-init-macro%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/gohanlon/swift-memberwise-init-macro)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgohanlon%2Fswift-memberwise-init-macro%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/gohanlon/swift-memberwise-init-macro)

A Swift Macro for enhanced automatic memberwise initializers, greatly reducing manual boilerplate:

* **~1,000 deletions** to [Point-Free’s Website with MemberwiseInit][pointfreeco-website-memberwiseinit].
* **~1,200 deletions** to [Point-Free’s Isowords with MemberwiseInit][pointfreeco-isowords-memberwiseinit].

![swift-memberwise-init-hero04](https://github.com/gohanlon/swift-memberwise-init-macro/assets/3375/5aab978d-fe31-4d2a-968a-b540adbd1355)

Informed by explicit developer cues, MemberwiseInit can more often automatically provide your intended memberwise `init`, while maintaining a safe-by-default standard in line with [Swift’s memberwise initializers][swifts-memberwise-init].

> [!IMPORTANT]
> `@MemberwiseInit` is a Swift Macro requiring **swift-tools-version: 5.9** or later (**Xcode 15** onwards).

* [Quick start](#quick-start)
* [Quick reference](#quick-reference)
* [Features and limitations](#features-and-limitations)
  * [Custom `init` parameter labels](#custom-init-parameter-labels)
  * [Infer type from property initialization expressions](#infer-type-from-property-initialization-expressions)
  * [Explicitly ignore properties](#explicitly-ignore-properties)
  * [Attributed properties are ignored by default, but includable](#attributed-properties-are-ignored-by-default-but-includable)
  * [Support for property wrappers](#support-for-property-wrappers)
  * [Automatic `@escaping` for closure types (usually)](#automatic-escaping-for-closure-types-usually)
  * [Experimental: Deunderscore parameter names](#experimental-deunderscore-parameter-names)
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
     .package(url: "https://github.com/gohanlon/swift-memberwise-init-macro", from: "0.2.0")
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
   //╰─ 🛑 @MemberwiseInit(.internal) would leak access to 'private' property
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

MemberwiseInit includes two macros:

### `@MemberwiseInit`

Attach to struct, actor *(experimental)*, or class *(experimental)*.

* `@MemberwiseInit`
  <br> Provide an internal memberwise `init`.

* `@MemberwiseInit(.public)`
  <br> Provide a memberwise `init` at the provided access level. Valid access levels: `.private`, `.fileprivate`, `.internal`, `.package`, `.public`, `.open`.

* `@MemberwiseInit(_deunderscoreParameters: true)` *(experimental)*
  <br> Drop underscore prefix from generated `init` parameter names, unless doing so would result in a naming conflict. (Ignored properties won’t contribute to conflicts.)

* `@MemberwiseInit(_optionalsDefaultNil: true)` *(experimental)*
  <br> When set to `true`, give all optional properties a default `init` parameter value of `nil`. For non-public initializers, optional `var` properties default to `nil` unless this parameter is explicitly set to `false`.

### `@Init`

Attach to member property declarations of a struct, actor, or class that `@MemberwiseInit` is providing an `init` for.

* `@Init`
  <br> Include a property that would otherwise be ignored, e.g., attributed properties such as SwiftUI’s `@State` properties.

* `@Init(.ignore)`
  <br> Ignore that member property. The access level of an ignored property won’t cause the macro to fail, and the property won’t be included in the `init`. *Note: Ignored properties must be initialized elsewhere.*

* `@Init(.public)`
  <br> For the provided `init`, consider the property as having a different access level than its declared access level. Valid access levels: `.private`, `.fileprivate`, `.internal`, `.package`, `.public`, `.open`.

* `@Init(.escaping`)
  <br> To avoid compiler errors when a property’s `init` argument can’t automatically be `@escaped`, e.g. when a property’s type uses a typealias that represents a closure.

* `@Init(.public, .escaping)`
  <br> Access level and escaping behaviors can be used together.

* `@Init(label: String)`
  <br> Assigns a custom parameter label in the provided `init`.
  * Use `@Init(label: "_")` to make the `init` parameter label-less.
  * Diagnostic errors arise from invalid labels, or conflicts among properties included in the `init`. (Ignored properties don’t cause conflicts.)
  * Overrides MemberwiseInit’s experimental `_deunderscoreParameters` behavior.

* `@Init(.public, label: String)`
  <br> Custom labels can be combined with all other behaviors.

* `@Init(assignee: String)`
  <br> Override the target property to which the initializer argument should be assigned. By default, a property named “property” has the assignee `self.property`, as demonstrated in `self.property = property`.

* `@Init(type: Any.Type)`
  <br> Override the type of the argument in the initializer.

* `@Init(assignee: String, type: Any.Type)`
  <br> Combine `assignee` and `type` to support usage with property wrappers:

  ```swift
  @Init(assignee: "self._isOn", type: Binding<Bool>)
  @Binding var isOn = true
  ```

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

Combine `@Init(assignee:)` and `@Init(type)` to support property wrappers. For example, here’s a simple usage with SwiftUI’s `@Binding`:

```swift
import SwiftUI

@MemberwiseInit
struct CounterView: View {
  @Init(assignee: "self._count", type: Binding<Int>)
  @Binding var count = 0

  var body: some View { … }
}
```

### Automatic `@escaping` for closure types (usually)

MemberwiseInit automatically marks closures in initializer parameters as `@escaping`. If using a typealias for a closure, explicitly annotate the property with `@Init(.escaping)`.

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

To address this, when using a typealias for closures, you must explicitly mark the property with `@Init(.escaping)`:

```swift
public typealias CompletionHandler = @Sendable () -> Void

@MemberwiseInit(.public)
public struct TaskRunner: Sendable {
  @Init(.escaping) public let onCompletion: CompletionHandler  // 👈
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

### Experimental: Deunderscore parameter names

> **Note**
> Prefer using `@Init(label:)` at the property level to explicitly specify non-underscored names—`@MemberwiseInit(_deunderscoreParmeters:)` may be deprecated soon.

Set `@MemberwiseInit(_deunderscoreParmeters: true)` to strip the underscore prefix from properties when generating initializer parameter names. If you wish to maintain the underscore or provide a custom label on a particular property, use `@Init(label: String)`.

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
> `@Init(default:)` is a planned future enhancement to generally specify default values, and will be a safer, more explicit alternative to `_optionalsDefaultNil`.

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

While MemberwiseInit doesn’t (yet) solve for default values of `let` properties, `_optionalsDefaultNil` serves the specific case of defaulting optional properties to `nil`:

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
//╰─ 🛑 @MemberwiseInit(. public) would leak access to 'private' property
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

1. **Clear Intent**: `@MemberwiseInit` is a declaration of the developer’s explicit intention, thereby avoiding any ambiguity about the desired access level for the initializer.
2. **Safety**: By failing fast when expectations aren’t met, MemberwiseInit prevents unintended access level leaks that could compromise the encapsulation and safety of the code. That is, it is still safe by default.
3. **Simpler**: MemberwiseInit’s reduced complexity makes it easier to use, as its behavior is more direct and predictable.
4. **Learnable**:  `@MemberwiseInit` can be applied naively, and most usage issues can be remedied in response to MemberwiseInit’s immediate feedback via diagnostic messages[^2].

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
[^2]: Presently, MemberwiseInit’s diagnostics are limited to simple diagnostic errors—it doesn’t yet offer “fix-it” diagnostics. And, there are usage errors presently left to the compiler checking the provided `init` that may be addressed directly in the future, e.g. rather than implicitly ignoring attributed properties marked with attributes like `@State`, MemberwiseInit may raise a diagnostic error and “fix-its” to add either `@Init`, `@Init(.ignore)`, or to assign a default value for the variable declaration.

[swifts-memberwise-init]: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Memberwise-Initializers-for-Structure-Types "Swift.org: Memberwise Initializers for Structure Types"
[pointfreeco-website-memberwiseinit]: https://github.com/gohanlon/pointfreeco/compare/main..memberwise-init-macro "Demo of Point-Free’s website using @MemberwiseInit"
[pointfreeco-isowords-memberwiseinit]: https://github.com/gohanlon/isowords/compare/main...memberwise-init-macro "Demo of Point-Free’s Isowords using @MemberwiseInit"
[mit-license]: https://github.com/gohanlon/swift-memberwise-init-macro/blob/main/LICENSE "MIT license"
[extension-dance]: https://gist.github.com/gohanlon/6aaeff970c955c9a39308c182c116f64
