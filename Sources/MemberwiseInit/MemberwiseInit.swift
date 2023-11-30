public enum AccessLevelConfig {
  case `private`
  case `fileprivate`
  case `internal`
  case `package`
  case `public`
  case `open`
}

// MARK: @MemberwiseInit macro

@attached(member, names: named(init))
public macro MemberwiseInit(
  _ accessLevel: AccessLevelConfig,
  _deunderscoreParameters: Bool? = nil,
  _optionalsDefaultNil: Bool? = nil
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "MemberwiseInitMacro"
  )

@attached(member, names: named(init))
public macro MemberwiseInit(
  _deunderscoreParameters: Bool? = nil,
  _optionalsDefaultNil: Bool? = nil
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "MemberwiseInitMacro"
  )

// MARK: @Init macro

public enum IgnoreConfig {
  case ignore
}

// NB: The behavior of `@Init(default: nil)` can be surprising upon close examination:
// * `@Init()`: No argument is given, so `default` semantically defaults to nil, which means "no default value".
// * `@Init(default: nil)`: However, when nil is explicitly provided, it means "set the default value to nil".

@attached(peer)
public macro Init(
  _ accessLevel: AccessLevelConfig? = nil,
  default: Any? = nil,
  escaping: Bool? = nil,
  label: String? = nil
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "InitMacro"
  )

@attached(peer)
public macro InitWrapper(
  _ accessLevel: AccessLevelConfig? = nil,
  default: Any? = nil,
  escaping: Bool? = nil,
  label: String? = nil,
  type: Any.Type
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "InitMacro"
  )

@attached(peer)
public macro InitRaw(
  _ accessLevel: AccessLevelConfig? = nil,
  assignee: String? = nil,
  default: Any? = nil,
  escaping: Bool? = nil,
  label: String? = nil,
  type: Any.Type? = nil
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "InitMacro"
  )

@attached(peer)
public macro Init(
  _ ignore: IgnoreConfig
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "InitMacro"
  )

// MARK: - Deprecated

// Deprecated; remove in 1.0
public enum EscapingConfig { case escaping }

@attached(peer)
public macro Init(
  _ accessLevel: AccessLevelConfig,
  _ escaping: EscapingConfig,
  label: String? = nil
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "InitMacro"
  )

// Deprecated; remove in 1.0
@attached(peer)
public macro Init(
  _ escaping: EscapingConfig,
  label: String? = nil
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "InitMacro"
  )
