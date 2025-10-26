module languages.dotnet.fsharp.interactive;

/// F# Interactive Package
/// 
/// F# Interactive (FSI) support:
/// - Script execution via F# Interactive
/// - REPL capabilities
/// - Interactive development support
///
/// Note: FSI support is primarily implemented through:
/// - Script builder in tooling/builders/script.d
/// - FSI configuration in core/config.d
///
/// This package serves as a documentation and organization point.

// FSI is implemented in the script builder
public import languages.dotnet.fsharp.tooling.builders.script;

