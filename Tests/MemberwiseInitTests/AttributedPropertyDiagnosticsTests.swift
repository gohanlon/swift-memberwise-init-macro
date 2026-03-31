import MacroTesting
import MemberwiseInitMacros
import SwiftSyntaxMacros
import XCTest

final class AttributedPropertyDiagnosticsTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      indentationWidth: .spaces(2),
      macros: [
        "MemberwiseInit": MemberwiseInitMacro.self,
        "Init": InitMacro.self,
        "InitWrapper": InitMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - wrapperInit

  func testBinding_WithTypeAnnotation() {
    assertMacro {
      """
      @MemberwiseInit
      struct CounterView {
        @Binding var count: Int
      }
      """
    } expansion: {
      """
      struct CounterView {
        @Binding var count: Int

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct CounterView {
        @Binding var count: Int
        ┬──────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Binding' attribute
           ✏️ Add '@InitWrapper(type: Binding<Int>.self)' (@SwiftUI.Binding)
           ✏️ Add '@Init' to include in the initializer
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @Binding var count: Int
      ┬──────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Binding' attribute

      ✏️ Add '@InitWrapper(type: Binding<Int>.self)' (@SwiftUI.Binding)
      @MemberwiseInit
      struct CounterView {
        @InitWrapper(type: Binding<Int>.self)

        @Binding var count: Int
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      struct CounterView {
        @Init

        @Binding var count: Int
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      struct CounterView {
        @Init(.ignore)

        @Binding var count: Int = <#value#>
      }
      """
    }
  }

  func testBinding_WithoutTypeAnnotation() {
    assertMacro {
      """
      @MemberwiseInit
      struct CounterView {
        @Binding var count = 0
      }
      """
    } expansion: {
      """
      struct CounterView {
        @Binding var count = 0

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct CounterView {
        @Binding var count = 0
        ┬─────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Binding' attribute
           ✏️ Add '@InitWrapper(type: Binding<<#Type#>>.self)' (@SwiftUI.Binding)
           ✏️ Add '@Init' to include in the initializer
           ✏️ Add '@Init(.ignore)'
      }
      """
    } fixes: {
      """
      @Binding var count = 0
      ┬─────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Binding' attribute

      ✏️ Add '@InitWrapper(type: Binding<<#Type#>>.self)' (@SwiftUI.Binding)
      @MemberwiseInit
      struct CounterView {
        @InitWrapper(type: Binding<<#Type#>>.self)

        @Binding var count = 0
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      struct CounterView {
        @Init

        @Binding var count = 0
      }

      ✏️ Add '@Init(.ignore)'
      @MemberwiseInit
      struct CounterView {
        @Init(.ignore)

        @Binding var count = 0
      }
      """
    }
  }

  func testBinding_ModuleQualified() {
    assertMacro {
      """
      @MemberwiseInit
      struct CounterView {
        @SwiftUI.Binding var count: Int
      }
      """
    } expansion: {
      """
      struct CounterView {
        @SwiftUI.Binding var count: Int

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct CounterView {
        @SwiftUI.Binding var count: Int
        ┬──────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@SwiftUI.Binding' attribute
           ✏️ Add '@InitWrapper(type: Binding<Int>.self)' (@SwiftUI.Binding)
           ✏️ Add '@Init' to include in the initializer
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @SwiftUI.Binding var count: Int
      ┬──────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@SwiftUI.Binding' attribute

      ✏️ Add '@InitWrapper(type: Binding<Int>.self)' (@SwiftUI.Binding)
      @MemberwiseInit
      struct CounterView {
        @InitWrapper(type: Binding<Int>.self)

        @SwiftUI.Binding var count: Int
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      struct CounterView {
        @Init

        @SwiftUI.Binding var count: Int
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      struct CounterView {
        @Init(.ignore)

        @SwiftUI.Binding var count: Int = <#value#>
      }
      """
    }
  }

  // MARK: - directInclude

  func testPublished() {
    assertMacro {
      """
      @MemberwiseInit
      class ViewModel {
        @Published var name: String
      }
      """
    } expansion: {
      """
      class ViewModel {
        @Published var name: String

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      class ViewModel {
        @Published var name: String
        ┬──────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Published' attribute
           ✏️ Add '@Init' to include in the initializer (@Combine.Published)
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @Published var name: String
      ┬──────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Published' attribute

      ✏️ Add '@Init' to include in the initializer (@Combine.Published)
      @MemberwiseInit
      class ViewModel {
        @Init

        @Published var name: String
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      class ViewModel {
        @Init(.ignore)

        @Published var name: String = <#value#>
      }
      """
    }
  }

  func testObservedObject() {
    assertMacro {
      """
      @MemberwiseInit
      struct DetailView {
        @ObservedObject var viewModel: MyViewModel
      }
      """
    } expansion: {
      """
      struct DetailView {
        @ObservedObject var viewModel: MyViewModel

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct DetailView {
        @ObservedObject var viewModel: MyViewModel
        ┬─────────────────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@ObservedObject' attribute
           ✏️ Add '@Init' to include in the initializer (@SwiftUI.ObservedObject)
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @ObservedObject var viewModel: MyViewModel
      ┬─────────────────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@ObservedObject' attribute

      ✏️ Add '@Init' to include in the initializer (@SwiftUI.ObservedObject)
      @MemberwiseInit
      struct DetailView {
        @Init

        @ObservedObject var viewModel: MyViewModel
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      struct DetailView {
        @Init(.ignore)

        @ObservedObject var viewModel: MyViewModel = <#value#>
      }
      """
    }
  }

  func testBindable() {
    assertMacro {
      """
      @MemberwiseInit
      struct DetailView {
        @Bindable var model: MyModel
      }
      """
    } expansion: {
      """
      struct DetailView {
        @Bindable var model: MyModel

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct DetailView {
        @Bindable var model: MyModel
        ┬───────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Bindable' attribute
           ✏️ Add '@Init' to include in the initializer (@SwiftUI.Bindable)
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @Bindable var model: MyModel
      ┬───────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Bindable' attribute

      ✏️ Add '@Init' to include in the initializer (@SwiftUI.Bindable)
      @MemberwiseInit
      struct DetailView {
        @Init

        @Bindable var model: MyModel
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      struct DetailView {
        @Init(.ignore)

        @Bindable var model: MyModel = <#value#>
      }
      """
    }
  }

  func testObservationIgnored() {
    assertMacro {
      """
      @MemberwiseInit
      class ViewModel {
        @ObservationIgnored var cache: [String: Data]
      }
      """
    } expansion: {
      """
      class ViewModel {
        @ObservationIgnored var cache: [String: Data]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      class ViewModel {
        @ObservationIgnored var cache: [String: Data]
        ┬────────────────────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@ObservationIgnored' attribute
           ✏️ Add '@Init' to include in the initializer (@Observation.ObservationIgnored)
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @ObservationIgnored var cache: [String: Data]
      ┬────────────────────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@ObservationIgnored' attribute

      ✏️ Add '@Init' to include in the initializer (@Observation.ObservationIgnored)
      @MemberwiseInit
      class ViewModel {
        @Init

        @ObservationIgnored var cache: [String: Data]
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      class ViewModel {
        @Init(.ignore)

        @ObservationIgnored var cache: [String: Data] = <#value#>
      }
      """
    }
  }

  func testAttribute_SwiftData() {
    assertMacro {
      """
      @MemberwiseInit
      class BirdSpecies {
        @Attribute(.unique) var id: String
      }
      """
    } expansion: {
      """
      class BirdSpecies {
        @Attribute(.unique) var id: String

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      class BirdSpecies {
        @Attribute(.unique) var id: String
        ┬─────────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Attribute' attribute
           ✏️ Add '@Init' to include in the initializer (@SwiftData.Attribute)
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @Attribute(.unique) var id: String
      ┬─────────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Attribute' attribute

      ✏️ Add '@Init' to include in the initializer (@SwiftData.Attribute)
      @MemberwiseInit
      class BirdSpecies {
        @Init

        @Attribute(.unique) var id: String
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      class BirdSpecies {
        @Init(.ignore)

        @Attribute(.unique) var id: String = <#value#>
      }
      """
    }
  }

  func testRelationship_SwiftData() {
    assertMacro {
      """
      @MemberwiseInit
      class BirdSpecies {
        @Relationship(deleteRule: .cascade) var birds: [Bird]
      }
      """
    } expansion: {
      """
      class BirdSpecies {
        @Relationship(deleteRule: .cascade) var birds: [Bird]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      class BirdSpecies {
        @Relationship(deleteRule: .cascade) var birds: [Bird]
        ┬────────────────────────────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Relationship' attribute
           ✏️ Add '@Init' to include in the initializer (@SwiftData.Relationship)
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @Relationship(deleteRule: .cascade) var birds: [Bird]
      ┬────────────────────────────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Relationship' attribute

      ✏️ Add '@Init' to include in the initializer (@SwiftData.Relationship)
      @MemberwiseInit
      class BirdSpecies {
        @Init

        @Relationship(deleteRule: .cascade) var birds: [Bird]
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      class BirdSpecies {
        @Init(.ignore)

        @Relationship(deleteRule: .cascade) var birds: [Bird] = <#value#>
      }
      """
    }
  }

  // MARK: - ignore: firstRender

  func testState() {
    assertMacro {
      """
      @MemberwiseInit
      struct DetailView {
        @State var isActive: Bool
      }
      """
    } expansion: {
      """
      struct DetailView {
        @State var isActive: Bool

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct DetailView {
        @State var isActive: Bool
        ┬────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@State' attribute
           ✏️ Add '@Init(.ignore)' and a default value
           ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)
      }
      """
    } fixes: {
      """
      @State var isActive: Bool
      ┬────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@State' attribute

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      struct DetailView {
        @Init(.ignore)

        @State var isActive: Bool = <#value#>
      }

      ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)
      @MemberwiseInit
      struct DetailView {
        @Init

        @State var isActive: Bool
      }
      """
    }
  }

  func testStateObject() {
    assertMacro {
      """
      @MemberwiseInit
      struct MyView {
        @StateObject var viewModel: MyViewModel
      }
      """
    } expansion: {
      """
      struct MyView {
        @StateObject var viewModel: MyViewModel

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct MyView {
        @StateObject var viewModel: MyViewModel
        ┬──────────────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@StateObject' attribute
           ✏️ Add '@Init(.ignore)' and a default value
           ✏️ Add '@Init' to include (@SwiftUI.StateObject — value is only used on first render)
      }
      """
    } fixes: {
      """
      @StateObject var viewModel: MyViewModel
      ┬──────────────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@StateObject' attribute

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      struct MyView {
        @Init(.ignore)

        @StateObject var viewModel: MyViewModel = <#value#>
      }

      ✏️ Add '@Init' to include (@SwiftUI.StateObject — value is only used on first render)
      @MemberwiseInit
      struct MyView {
        @Init

        @StateObject var viewModel: MyViewModel
      }
      """
    }
  }

  func testState_ModuleQualified() {
    assertMacro {
      """
      @MemberwiseInit
      struct MyView {
        @SwiftUI.State var isOn: Bool
      }
      """
    } expansion: {
      """
      struct MyView {
        @SwiftUI.State var isOn: Bool

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct MyView {
        @SwiftUI.State var isOn: Bool
        ┬────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@SwiftUI.State' attribute
           ✏️ Add '@Init(.ignore)' and a default value
           ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)
      }
      """
    } fixes: {
      """
      @SwiftUI.State var isOn: Bool
      ┬────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@SwiftUI.State' attribute

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      struct MyView {
        @Init(.ignore)

        @SwiftUI.State var isOn: Bool = <#value#>
      }

      ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)
      @MemberwiseInit
      struct MyView {
        @Init

        @SwiftUI.State var isOn: Bool
      }
      """
    }
  }

  // MARK: - ignore: injected

  func testEnvironment() {
    assertMacro {
      """
      @MemberwiseInit
      struct ContentView {
        @Environment(\\.colorScheme) var colorScheme
      }
      """
    } expansion: {
      """
      struct ContentView {
        @Environment(\\.colorScheme) var colorScheme

        internal init() {
        }
      }
      """
    } diagnostics: {
      #"""
      @MemberwiseInit
      struct ContentView {
        @Environment(\.colorScheme) var colorScheme
        ┬──────────────────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Environment' attribute
           ✏️ Add '@Init(.ignore)' (@SwiftUI.Environment — value is injected, not initialized) and a default value
           ✏️ Add '@Init' to include in the initializer
      }
      """#
    } fixes: {
      #"""
      @Environment(\.colorScheme) var colorScheme
      ┬──────────────────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Environment' attribute

      ✏️ Add '@Init(.ignore)' (@SwiftUI.Environment — value is injected, not initialized) and a default value
      @MemberwiseInit
      struct ContentView {
        @Init(.ignore)

        @Environment(\.colorScheme) var colorScheme = <#value#>
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      struct ContentView {
        @Init

        @Environment(\.colorScheme) var colorScheme
      }
      """#
    }
  }

  func testEnvironmentObject() {
    assertMacro {
      """
      @MemberwiseInit
      struct SettingsView {
        @EnvironmentObject var settings: UserSettings
      }
      """
    } expansion: {
      """
      struct SettingsView {
        @EnvironmentObject var settings: UserSettings

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct SettingsView {
        @EnvironmentObject var settings: UserSettings
        ┬────────────────────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@EnvironmentObject' attribute
           ✏️ Add '@Init(.ignore)' (@SwiftUI.EnvironmentObject — value is injected, not initialized) and a default value
           ✏️ Add '@Init' to include in the initializer
      }
      """
    } fixes: {
      """
      @EnvironmentObject var settings: UserSettings
      ┬────────────────────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@EnvironmentObject' attribute

      ✏️ Add '@Init(.ignore)' (@SwiftUI.EnvironmentObject — value is injected, not initialized) and a default value
      @MemberwiseInit
      struct SettingsView {
        @Init(.ignore)

        @EnvironmentObject var settings: UserSettings = <#value#>
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      struct SettingsView {
        @Init

        @EnvironmentObject var settings: UserSettings
      }
      """
    }
  }

  // MARK: - ignore: frameworkManaged

  func testFocusState() {
    assertMacro {
      """
      @MemberwiseInit
      struct MyView {
        @FocusState var isFocused: Bool
      }
      """
    } expansion: {
      """
      struct MyView {
        @FocusState var isFocused: Bool

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct MyView {
        @FocusState var isFocused: Bool
        ┬──────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@FocusState' attribute
           ✏️ Add '@Init(.ignore)' (@SwiftUI.FocusState — value is framework-managed) and a default value
           ✏️ Add '@Init' to include in the initializer
      }
      """
    } fixes: {
      """
      @FocusState var isFocused: Bool
      ┬──────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@FocusState' attribute

      ✏️ Add '@Init(.ignore)' (@SwiftUI.FocusState — value is framework-managed) and a default value
      @MemberwiseInit
      struct MyView {
        @Init(.ignore)

        @FocusState var isFocused: Bool = <#value#>
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      struct MyView {
        @Init

        @FocusState var isFocused: Bool
      }
      """
    }
  }

  func testAppStorage_AlreadyInitialized() {
    assertMacro {
      """
      @MemberwiseInit
      struct SettingsView {
        @AppStorage("fontSize") var fontSize = 14.0
      }
      """
    } expansion: {
      """
      struct SettingsView {
        @AppStorage("fontSize") var fontSize = 14.0

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct SettingsView {
        @AppStorage("fontSize") var fontSize = 14.0
        ┬──────────────────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@AppStorage' attribute
           ✏️ Add '@Init(.ignore)' (@SwiftUI.AppStorage — value is framework-managed)
           ✏️ Add '@Init' to include in the initializer
      }
      """
    } fixes: {
      """
      @AppStorage("fontSize") var fontSize = 14.0
      ┬──────────────────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@AppStorage' attribute

      ✏️ Add '@Init(.ignore)' (@SwiftUI.AppStorage — value is framework-managed)
      @MemberwiseInit
      struct SettingsView {
        @Init(.ignore)

        @AppStorage("fontSize") var fontSize = 14.0
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      struct SettingsView {
        @Init

        @AppStorage("fontSize") var fontSize = 14.0
      }
      """
    }
  }

  func testQuery_SwiftData() {
    assertMacro {
      """
      @MemberwiseInit
      struct PeopleView {
        @Query var people: [Person]
      }
      """
    } expansion: {
      """
      struct PeopleView {
        @Query var people: [Person]

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct PeopleView {
        @Query var people: [Person]
        ┬──────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Query' attribute
           ✏️ Add '@Init(.ignore)' (@SwiftData.Query — value is framework-managed) and a default value
           ✏️ Add '@Init' to include in the initializer
      }
      """
    } fixes: {
      """
      @Query var people: [Person]
      ┬──────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Query' attribute

      ✏️ Add '@Init(.ignore)' (@SwiftData.Query — value is framework-managed) and a default value
      @MemberwiseInit
      struct PeopleView {
        @Init(.ignore)

        @Query var people: [Person] = <#value#>
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      struct PeopleView {
        @Init

        @Query var people: [Person]
      }
      """
    }
  }

  // MARK: - ignore: runtimeManaged

  func testNSManaged() {
    assertMacro {
      """
      @MemberwiseInit
      class MainEntity {
        @NSManaged var name: String
      }
      """
    } expansion: {
      """
      class MainEntity {
        @NSManaged var name: String

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      class MainEntity {
        @NSManaged var name: String
        ┬──────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@NSManaged' attribute
           ✏️ Add '@Init(.ignore)' (@CoreData.NSManaged — properties are runtime-managed) and a default value
           ✏️ Add '@Init' to include in the initializer
      }
      """
    } fixes: {
      """
      @NSManaged var name: String
      ┬──────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@NSManaged' attribute

      ✏️ Add '@Init(.ignore)' (@CoreData.NSManaged — properties are runtime-managed) and a default value
      @MemberwiseInit
      class MainEntity {
        @Init(.ignore)

        @NSManaged var name: String = <#value#>
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      class MainEntity {
        @Init

        @NSManaged var name: String
      }
      """
    }
  }

  // MARK: - ignore: nonPersistent

  func testTransient_AlreadyInitialized() {
    assertMacro {
      """
      @MemberwiseInit
      class Player {
        @Transient var levelsPlayed = 0
      }
      """
    } expansion: {
      """
      class Player {
        @Transient var levelsPlayed = 0

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      class Player {
        @Transient var levelsPlayed = 0
        ┬──────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Transient' attribute
           ✏️ Add '@Init(.ignore)' (@SwiftData.Transient — non-persistent, must have a default)
           ✏️ Add '@Init' to include in the initializer
      }
      """
    } fixes: {
      """
      @Transient var levelsPlayed = 0
      ┬──────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Transient' attribute

      ✏️ Add '@Init(.ignore)' (@SwiftData.Transient — non-persistent, must have a default)
      @MemberwiseInit
      class Player {
        @Init(.ignore)

        @Transient var levelsPlayed = 0
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      class Player {
        @Init

        @Transient var levelsPlayed = 0
      }
      """
    }
  }

  // MARK: - safe (no diagnostic)

  func testObjc_NoDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @objc var name: String
      }
      """
    } expansion: {
      """
      struct S {
        @objc var name: String

        internal init(
          name: String
        ) {
          self.name = name
        }
      }
      """
    }
  }

  func testPreconcurrency_NoDiagnostic() {
    assertMacro {
      """
      @MemberwiseInit
      struct S {
        @preconcurrency var handler: @Sendable () -> Void
      }
      """
    } expansion: {
      """
      struct S {
        @preconcurrency var handler: @Sendable () -> Void

        internal init(
          handler: @escaping @Sendable () -> Void
        ) {
          self.handler = handler
        }
      }
      """
    }
  }

  // MARK: - unknown (baseline)

  func testUnknownAttribute() {
    assertMacro {
      """
      @MemberwiseInit
      struct Counter {
        @Logged var count: Int
      }
      """
    } expansion: {
      """
      struct Counter {
        @Logged var count: Int

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct Counter {
        @Logged var count: Int
        ┬─────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Logged' attribute
           ✏️ Add '@Init' to include in the initializer
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @Logged var count: Int
      ┬─────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Logged' attribute

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit
      struct Counter {
        @Init

        @Logged var count: Int
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      struct Counter {
        @Init(.ignore)

        @Logged var count: Int = <#value#>
      }
      """
    }
  }

  // MARK: - Multi-attribute precedence

  func testMultiAttribute_PublishedWithMainActor() {
    assertMacro {
      """
      @MemberwiseInit
      class ViewModel {
        @MainActor @Published var isLoading: Bool
      }
      """
    } expansion: {
      """
      class ViewModel {
        @MainActor @Published var isLoading: Bool

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      class ViewModel {
        @MainActor @Published var isLoading: Bool
        ┬────────────────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Published' attribute
           ✏️ Add '@Init' to include in the initializer (@Combine.Published)
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @MainActor @Published var isLoading: Bool
      ┬────────────────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Published' attribute

      ✏️ Add '@Init' to include in the initializer (@Combine.Published)
      @MemberwiseInit
      class ViewModel {
        @Init

        @MainActor @Published var isLoading: Bool
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit
      class ViewModel {
        @Init(.ignore)

        @MainActor @Published var isLoading: Bool = <#value#>
      }
      """
    }
  }

  // MARK: - Diagnostic precedence over access-level

  func testDiagnosticPrecedence_AttributedOverAccessLevel() {
    assertMacro {
      """
      @MemberwiseInit(.public)
      public struct CounterView {
        @Binding private var count: Int
      }
      """
    } expansion: {
      """
      public struct CounterView {
        @Binding private var count: Int

        public init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit(.public)
      public struct CounterView {
        @Binding private var count: Int
        ┬──────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Binding' attribute
           ✏️ Add '@InitWrapper(type: Binding<Int>.self)' (@SwiftUI.Binding)
           ✏️ Add '@Init' to include in the initializer
           ✏️ Add '@Init(.ignore)' and a default value
      }
      """
    } fixes: {
      """
      @Binding private var count: Int
      ┬──────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@Binding' attribute

      ✏️ Add '@InitWrapper(type: Binding<Int>.self)' (@SwiftUI.Binding)
      @MemberwiseInit(.public)
      public struct CounterView {
        @InitWrapper(type: Binding<Int>.self)

        @Binding private var count: Int
      }

      ✏️ Add '@Init' to include in the initializer
      @MemberwiseInit(.public)
      public struct CounterView {
        @Init

        @Binding private var count: Int
      }

      ✏️ Add '@Init(.ignore)' and a default value
      @MemberwiseInit(.public)
      public struct CounterView {
        @Init(.ignore)

        @Binding private var count: Int = <#value#>
      }
      """
    }
  }

  // MARK: - Already initialized (no "and a default value" suffix)

  func testState_AlreadyInitialized() {
    assertMacro {
      """
      @MemberwiseInit
      struct MyView {
        @State var isOn: Bool = false
      }
      """
    } expansion: {
      """
      struct MyView {
        @State var isOn: Bool = false

        internal init() {
        }
      }
      """
    } diagnostics: {
      """
      @MemberwiseInit
      struct MyView {
        @State var isOn: Bool = false
        ┬────────────────────────────
        ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@State' attribute
           ✏️ Add '@Init(.ignore)'
           ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)
      }
      """
    } fixes: {
      """
      @State var isOn: Bool = false
      ┬────────────────────────────
      ╰─ 🛑 @MemberwiseInit requires explicit @Init configuration for property with '@State' attribute

      ✏️ Add '@Init(.ignore)'
      @MemberwiseInit
      struct MyView {
        @Init(.ignore)

        @State var isOn: Bool = false
      }

      ✏️ Add '@Init' to include (@SwiftUI.State — value is only used on first render)
      @MemberwiseInit
      struct MyView {
        @Init

        @State var isOn: Bool = false
      }
      """
    }
  }
}
