import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MemberwiseInitPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    InitMacro.self,
    MemberwiseInitMacro.self,
  ]
}
