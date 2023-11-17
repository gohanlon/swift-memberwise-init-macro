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
  _ accessLevel: AccessLevelConfig? = nil,
  _deunderscoreParameters: Bool? = nil,
  _optionalsDefaultNil: Bool? = nil
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "MemberwiseInitMacro"
  )

// MARK: @Init macro

public enum EscapingConfig {
  case escaping
}

public enum IgnoreConfig {
  case ignore
}

@attached(peer)
public macro Init(
  _ accessLevel: AccessLevelConfig? = nil,
  assignee: String? = nil,
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
