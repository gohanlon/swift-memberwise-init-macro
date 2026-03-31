enum IgnoreReason {
  case firstRender
  case injected
  case frameworkManaged
  case runtimeManaged
  case nonPersistent

  var note: String {
    switch self {
    case .firstRender: "value is only used on first render"
    case .injected: "value is injected, not initialized"
    case .frameworkManaged: "value is framework-managed"
    case .runtimeManaged: "properties are runtime-managed"
    case .nonPersistent: "non-persistent, must have a default"
    }
  }

  /// When true, the parenthetical note appears on the `@Init` fix-it (as a warning
  /// about choosing it) rather than on the `@Init(.ignore)` fix-it.
  var noteOnInitFixIt: Bool {
    switch self {
    case .firstRender: true
    case .injected, .frameworkManaged, .runtimeManaged, .nonPersistent: false
    }
  }
}

enum KnownAttributeKind {
  /// Metadata-only attribute — skip diagnostic entirely
  case safe
  /// Property needs wrapper-type initialization (e.g. @Binding → @InitWrapper)
  case wrapperInit(qualifiedName: String)
  /// Property should be included directly (e.g. @Published → @Init)
  case directInclude(qualifiedName: String)
  /// Property should be ignored (e.g. @State → @Init(.ignore))
  case ignore(qualifiedName: String, reason: IgnoreReason)
}

/// Both unqualified and module-qualified forms are matched via comma-separated
/// switch patterns — no string parsing, no dictionary.
func knownAttribute(_ name: String) -> KnownAttributeKind? {
  switch name {
  // safe
  case "objc", "nonobjc", "usableFromInline", "_spi", "preconcurrency":
    return .safe

  // wrapperInit
  case "Binding", "SwiftUI.Binding":
    return .wrapperInit(qualifiedName: "SwiftUI.Binding")

  // directInclude
  case "ObservedObject", "SwiftUI.ObservedObject":
    return .directInclude(qualifiedName: "SwiftUI.ObservedObject")
  case "Published", "Combine.Published":
    return .directInclude(qualifiedName: "Combine.Published")
  case "Bindable", "SwiftUI.Bindable":
    return .directInclude(qualifiedName: "SwiftUI.Bindable")
  case "ObservationIgnored", "Observation.ObservationIgnored":
    return .directInclude(qualifiedName: "Observation.ObservationIgnored")
  case "Attribute", "SwiftData.Attribute":
    return .directInclude(qualifiedName: "SwiftData.Attribute")
  case "Relationship", "SwiftData.Relationship":
    return .directInclude(qualifiedName: "SwiftData.Relationship")

  // ignore — first-render
  case "State", "SwiftUI.State":
    return .ignore(qualifiedName: "SwiftUI.State", reason: .firstRender)
  case "StateObject", "SwiftUI.StateObject":
    return .ignore(qualifiedName: "SwiftUI.StateObject", reason: .firstRender)

  // ignore — injected
  case "Environment", "SwiftUI.Environment":
    return .ignore(qualifiedName: "SwiftUI.Environment", reason: .injected)
  case "EnvironmentObject", "SwiftUI.EnvironmentObject":
    return .ignore(qualifiedName: "SwiftUI.EnvironmentObject", reason: .injected)

  // ignore — framework-managed
  case "FocusState", "SwiftUI.FocusState":
    return .ignore(qualifiedName: "SwiftUI.FocusState", reason: .frameworkManaged)
  case "AccessibilityFocusState", "SwiftUI.AccessibilityFocusState":
    return .ignore(qualifiedName: "SwiftUI.AccessibilityFocusState", reason: .frameworkManaged)
  case "GestureState", "SwiftUI.GestureState":
    return .ignore(qualifiedName: "SwiftUI.GestureState", reason: .frameworkManaged)
  case "ScaledMetric", "SwiftUI.ScaledMetric":
    return .ignore(qualifiedName: "SwiftUI.ScaledMetric", reason: .frameworkManaged)
  case "Namespace", "SwiftUI.Namespace":
    return .ignore(qualifiedName: "SwiftUI.Namespace", reason: .frameworkManaged)
  case "AppStorage", "SwiftUI.AppStorage":
    return .ignore(qualifiedName: "SwiftUI.AppStorage", reason: .frameworkManaged)
  case "SceneStorage", "SwiftUI.SceneStorage":
    return .ignore(qualifiedName: "SwiftUI.SceneStorage", reason: .frameworkManaged)
  case "FetchRequest", "SwiftUI.FetchRequest":
    return .ignore(qualifiedName: "SwiftUI.FetchRequest", reason: .frameworkManaged)
  case "SectionedFetchRequest", "SwiftUI.SectionedFetchRequest":
    return .ignore(qualifiedName: "SwiftUI.SectionedFetchRequest", reason: .frameworkManaged)
  case "Query", "SwiftData.Query":
    return .ignore(qualifiedName: "SwiftData.Query", reason: .frameworkManaged)
  case "FocusedObject", "SwiftUI.FocusedObject":
    return .ignore(qualifiedName: "SwiftUI.FocusedObject", reason: .frameworkManaged)
  case "FocusedValue", "SwiftUI.FocusedValue":
    return .ignore(qualifiedName: "SwiftUI.FocusedValue", reason: .frameworkManaged)
  case "FocusedBinding", "SwiftUI.FocusedBinding":
    return .ignore(qualifiedName: "SwiftUI.FocusedBinding", reason: .frameworkManaged)
  case "PhysicalMetric", "SwiftUI.PhysicalMetric":
    return .ignore(qualifiedName: "SwiftUI.PhysicalMetric", reason: .frameworkManaged)
  case "UIApplicationDelegateAdaptor", "SwiftUI.UIApplicationDelegateAdaptor":
    return .ignore(qualifiedName: "SwiftUI.UIApplicationDelegateAdaptor", reason: .frameworkManaged)
  case "NSApplicationDelegateAdaptor", "SwiftUI.NSApplicationDelegateAdaptor":
    return .ignore(qualifiedName: "SwiftUI.NSApplicationDelegateAdaptor", reason: .frameworkManaged)
  case "WKApplicationDelegateAdaptor", "SwiftUI.WKApplicationDelegateAdaptor":
    return .ignore(qualifiedName: "SwiftUI.WKApplicationDelegateAdaptor", reason: .frameworkManaged)
  case "WKExtensionDelegateAdaptor", "SwiftUI.WKExtensionDelegateAdaptor":
    return .ignore(qualifiedName: "SwiftUI.WKExtensionDelegateAdaptor", reason: .frameworkManaged)

  // ignore — runtime-managed
  case "NSManaged", "CoreData.NSManaged":
    return .ignore(qualifiedName: "CoreData.NSManaged", reason: .runtimeManaged)

  // ignore — non-persistent
  case "Transient", "SwiftData.Transient":
    return .ignore(qualifiedName: "SwiftData.Transient", reason: .nonPersistent)

  default: return nil
  }
}
