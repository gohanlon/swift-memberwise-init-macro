# @MemberwiseInit

A Swift Macro to generate seamless, safe, and explicit memberwise inits.

> :warning: :warning: :warning: **Pre-release**<br>
> I’m on the cusp of the official release and excited to share this with you! Dive in, experiment, and any feedback you provide will be greatly appreciated.

> :warning: **Important**<br>
> `@MemberwiseInit` is a Swift Macro requiring **swift-tools-version: 5.9** or later (**Xcode 15** onwards).

* [Introduction](#introduction)
* [Quick start](#quick-start)
* [Advanced usage and limitations](#advanced-usage-and-limitations)
  * [Underscore-prefixed properties](#underscore-prefixed-properties)
  * [Attributed properties are ignored by default, but includable](#attributed-properties-are-ignored-by-default-but-includable)
  * [Explicitly ignore properties](#explicitly-ignore-properties)
  * [Automatic `@escaping` for closure types (usually)](#automatic-escaping-for-closure-types-usually)
  * [Tuple destructuring in property declarations isn’t supported (yet)](#tuple-destructuring-in-property-declarations-isnt-supported-yet)
* [Motivation](#motivation)
* [Installation](#installation)
* [License](#license)

## Introduction

Swift provides memberwise initializers for structs, streamlining instantiation. However, this convenience doesn’t extend to classes or actors, and structs face constraints: limited init visibility, an inability to coexist with custom initializers, and lack of fine-grained control.

**MemberwiseInit** addresses these constraints:

- **Familiar**
  <br> MemberwiseInit mirrors Swift’s native memberwise initializer, promoting easy adoption.

- **Control**
  <br> Adjust your init using attributes.

- **Safety**
  <br> MemberwiseInit generates safe public initializers without exposing private properties by default. Override property visibility when necessary.

- **Enhanced utility**
  <br> Incorporate a generated memberwise init alongside custom ones or when manually conforming to protocols like `Decodable` and `RawRepresentable`.[^1]

- **Broadened scope**
  <br> While Swift rightly avoids auto-generating memberwise initializers for classes and actors due to inheritance and safety concerns, MemberwiseInit empowers you to create one when you assess it’s safe.

- **Reduced boilerplate**
  <br> Write and maintain fewer manual inits.

## Quick start

To use MemberwiseInit:

1. **Installation**
   <br> Add MemberwiseInit via Swift Package Manager by providing the package URL to your Xcode project: “https://github.com/gohanlon/swift-memberwise-init-macro”.

   Or, for SPM-based projects, add it to your package dependencies and target dependency:

   ```swift
   .package(url: "https://github.com/gohanlon/swift-memberwise-init-macro", from: "0.1.0"),
   ```

   ```swift
   dependencies: [
     .product(name: "MemberwiseInit", package: "swift-memberwise-init-macro"),
   ]
   ```

2. **Import & basic usage**
   <br> After importing MemberwiseInit, simply add `@MemberwiseInit` before your type definition. This will mirror Swift’s behavior: it generates an initializer with up to internal access, but scales down if any properties are more restrictive. Here, `isVerified` being private makes the initializer private too.

   ```swift
   import MemberwiseInit

   @MemberwiseInit
   struct User {
     let name: String
     private var isVerified: Bool = false
   }
   ```

3. **Customize visibility**
   <br> Make the struct public and use `@MemberwiseInit(.public)` to enable up to a public initializer. At this point, the init will still be private because `isVerified` is private.

   ```swift
   @MemberwiseInit(.public)
   public struct User {
     let name: String
     private var isVerified: Bool = false
   }
   ```

   Add `@Init(.public)` to `name` and `isVerified`. The initializer is now public.

   ```swift
   @MemberwiseInit(.public)
   public struct User {
     @Init(.public) let name: String
     @Init(.public) private var isVerified: Bool = false
   }
   ```

That’s it! Now access your new public memberwise initializer:

```swift
let user = User(name: "Blob")
```

## Advanced usage and limitations

### Underscore-prefixed properties
When using MemberwiseInit on underscore-prefixed properties, the initializer will present a non-prefixed version as the external parameter.

#### Explanation
In Swift, properties prefixed with an underscore are conventionally used as internal storage or backing properties. MemberwiseInit respects this convention, creating public-facing initializers without the underscore:

```swift
@MemberwiseInit(.public)
public struct Review {
  @Init(.public) private let _rating: Int

  var rating: String {
    return String(repeating: "⭐️", count: self._rating)
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

The compiler provides the following default memberwise initializer:

```swift
internal init(
  isOn: Bool
) {
  self.isOn = isOn
}
```

However, initializing `@State` properties in this manner is a common pitfall in SwiftUI. The `isOn` state is only assigned upon the initial rendering of the view, and this assignment doesn’t occur on subsequent renders. To safeguard against this, MemberwiseInit defaults to ignoring such attributed properties:

```swift
import SwiftUI
@MemberwiseInit  // 👈
struct MyView: View {
  @State var isOn: Bool

  var body: some View { … }
}
```

This leads MemberwiseInit to generate the following initializer:

```swift
internal init() {
}  // 🛑 Compiler error:↵
// Return from initializer without initializing all stored properties
```

From here, you have two alternatives:

1. **Assign a default value**
   <br> Defaulting the property to a value makes the generated MemberwiseInit valid, as the generated init no longer needs to initialize the property.

   ```swift
   import SwiftUI
   @MemberwiseInit
   struct MyView: View {
     @State var isOn: Bool = false  // 👈 Default value provided

     var body: some View { … }
   }
   ```

   The resulting initializer is:

   ```swift
   internal init() {
   }  // 🎉 No error, all stored properties are initialized
   ```

2. **Use `@Init` annotation**
   <br> If you understand the behavior the attribute imparts, you can explicitly mark the property with `@Init` to include it in the initializer.

   ```swift
   import SwiftUI
   @MemberwiseInit
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

### Explicitly ignore properties
To have MemberwiseInit both ignore and exclude specific properties from its generated initializer, mark them with `@Init(.ignore)`. Ensure these properties are otherwise initialized to avoid compiler errors.

### Explanation
The `@Init(.ignore)` attribute excludes properties from the initializer, potentially allowing MemberwiseInit to produce a more accessible initializer for the remaining properties.

For example:

```swift
@MemberwiseInit(.public)
public struct Person {
  @Init(.public) let name: String
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

If `age` weren't marked as ignored, the initializer would be private and would include the `age` property.

> **Note**
> In line with Swift’s built-in init, MemberwiseInit automatically ignores `let` properties with assigned default values, as reassigning such properties within the initializer would be invalid.

### Automatic `@escaping` for closure types (usually)
If you’re using MemberwiseInit with closure types, it’ll handle `@escaping` automatically for directly declared closures. However, if you use a typealias that represents a closure, ensure to explicitly mark the property with `@Init(.escaping)` to avoid compiler errors.

#### Explanation
Swift Macros operate at the syntax level and don’t inherently understand type information. MemberwiseInit will automatically attribute init parameters with `@escaping`, provided that the closure type is directly declared as part of the property. Fortunately, this is the typical scenario.

In contrast, the compiler’s built-in memberwise init has the advantage of working with type information. This allows it to recognize and add `@escaping` even when the closure type is “obscured” within a typealias.

Consider the following struct:

```swift
public struct TaskRunner {
  public let onCompletion: () -> Void
}
```

Through observation (or by delving into the compiler’s source code), we can see that the built-in memberwise init generates the following internal init:

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

we get the same init, which we can inspect using Xcode’s “Expand Macro” command:

```swift
internal init(
  onCompletion: @escaping () -> Void  // 🎉 `@escaping` automatically
) {
  self.onCompletion = onCompletion
}
```

And we can have MemberwiseInit generate a public init:

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

When using type aliases that represent closure types, there’s a caveat: Remember, Swift Macros operate at the syntax level and don’t inherently understand type information. MemberwiseInit cannot “see” that `CompletionHandler` represents a closure type that needs to be marked `@escaping`, leading to a compiler error:

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

which results in the following valid and inspectable public init:

```swift
public init(
  onCompletion: @escaping CompletionHandler  // 🎉 Correctly `@escaping`
) {
  self.onCompletion = onCompletion
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

## Motivation

The Swift compiler’s built-in memberwise init behavior is safe by design. It won’t assume that a public type should be constructible from external modules, so it never generates an init having an access level greater than “internal.”

To safely add a public init to a type requires an explicit developer intent. Traditionally, that means manually declaring an init, or using Xcode to generate a boilerplate init. Take this simple example:

```swift
public struct Person {
  let name: String
}
```

Swift transparently adds the following, familiar init:

```swift
internal init(
  name: String
) {
  self.name = name
}
```

MemberwiseInit can generate the exact same init:

```swift
@MemberwiseInit
public struct Person {
  let name: String
}
```

Unlike Swift’s built-in init, you can inspect MemberwiseInit’s generated init using Xcode by right clicking on `@MemberwiseInit` and the selecting “Expand Macro”.

> **Note**
> Introducing an explicit init suppresses the addition of Swift’s built-in memberwise initializer. MemberwiseInit’s initializer is always added and can coexist with your other inits.

In contrast to Swift’s native memberwise initializer, MemberwiseInit can generate initializers at any access level, including public, when you explicitly indicate that intent.

If you want MemberwiseInit to generate a public init for `Person`, you need do two things. First, you need to explicitly allow MemberwiseInit to generate a public init:

```swift
@MemberwiseInit(.public)
public struct Person {
  let name: String
}
```

At this point, if you expanded the macro, you’ll see that the init is still internal because `name` is internal:

```swift
internal init(  // 👈 Still internal
  name: String
) {
  self.name = name
}
```

The reason the init is still internal is foundational to understanding both MemberwiseInit and the compiler’s built-in memberwise init. By default, they both generate an init that acts as a safeguard, ensuring there’s no unintentional leaked access to more restricted properties.

This brings us to the second thing: tell MemberwiseInit that it’s okay to expose `name` publicly via the init. This is achieved by marking `name` with `@Init(.public)`:

```swift
@MemberwiseInit(.public)
public struct Person {
  @Init(.public) let name: String  // 👈
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

Alternatively, you could choose to make `name` public:

```swift
@MemberwiseInit(.public)
public struct Person {
  public let name: String
}
```

Suppose you then added a private member to `Person`:

```swift
@MemberwiseInit(.public)
public struct Person {
  @Init(.public) let name: String
  private let age: Int?  // 👈 `private`
}
```

Now MemberwiseInit, as the compiler’s built-in init would, generates a private init:

```swift
private init(  // 👈 `private`
  name: String,
  age: Int?
) {
  self.name = name
  self.age = age
}
```

To publicly expose `age` via MemberwiseInit’s generated init, mark it with `@Init(.public)`:

```swift
@MemberwiseInit(.public)
public struct Person {
  @Init(.public) let name: String
  @Init(.public) private let age: Int?  // 👈
}
```

and now MemberwiseInit generates a public init that includes the private `age` property:

```swift
public init(  // 👈 `public`
  name: String,
  age: Int?  // 👈 Developer intent
) {
  self.name = name
  self.age = age
}
```

Let’s change `age` to be a `var` property with a default value:

```swift
@MemberwiseInit(.public)
public struct Person {
  @Init(.public) let name: String
  @Init(.public) private var age: Int? = nil  // 👈 `var` with default value
}
```

and now MemberwiseInit’s init parameter includes the default `age` value:

```swift
public init(
  name: String,
  age: Int? = nil  // 👈 Default value
) {
  self.name = name
  self.age = age
}
```

Suppose we don’t want to expose `age` publicly via the init. As long as `age` is initialized in another way (e.g. declared with a default value), we can explicitly tell MemberwiseInit to ignore it using `@Init(.ignore)`:

```swift
@MemberwiseInit(.public)
public struct Person {
  @Init(.public) let name: String
  @Init(.ignore) private var age: Int? = nil  // 👈
}
```

Now MemberwiseInit generates a public init, ignoring `age`:

```swift
public init(  // 👈 `public`, ignoring `age` property
  name: String
) {
  self.name = name
}
```

## Installation

To integrate MemberwiseInit into your Xcode project:

1. Open your project in Xcode.
2. Navigate to the menu `File > Add Package Dependencies…`.
3. Enter the package repository URL in the “Search or Enter Package URL” field: “https://github.com/gohanlon/swift-memberwise-init-macro”.
4. Select the latest version or specify a version range.
5. Click ‘Next’ and then ‘Finish’ to complete the integration.

After integrating, import the macro using `import MemberwiseInit` in your Swift files.

## License

MemberwiseInit is available under the MIT license. See the [LICENSE](https://github.com/gohanlon/swift-memberwise-init-macro/blob/main/LICENSE) file for more info.

[^1]: Swift omits its built-in memberwise init when any explicit init is present. You can do an [“extension dance”](https://gist.github.com/gohanlon/6aaeff970c955c9a39308c182c116f64) to retain Swift’s built-in memberwise init, but with imposed tradeoffs.
