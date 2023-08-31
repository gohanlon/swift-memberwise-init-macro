public enum AccessLevelConfig {
  case `private`
  case `fileprivate`
  case `internal`
  case `public`
  case `open`
}

// MARK: @MemberwiseInit macro

@attached(member, names: named(init))
public macro MemberwiseInit(
  _ accessLevel: AccessLevelConfig = .internal,
  _deunderscoreParameters: Bool = false,
  _optionalsDefaultNil: Bool = false
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
public macro Init() =
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

@attached(peer)
public macro Init(
  label: String
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "InitMacro"
  )

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

@attached(peer)
public macro Init(
  _ accessLevel: AccessLevelConfig,
  label: String? = nil
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "InitMacro"
  )

@attached(peer)
public macro Init(
  _ escaping: EscapingConfig,
  label: String? = nil
) =
  #externalMacro(
    module: "MemberwiseInitMacros",
    type: "InitMacro"
  )
