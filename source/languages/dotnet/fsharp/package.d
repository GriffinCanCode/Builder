module languages.dotnet.fsharp;

/// F# Language Support
/// 
/// Comprehensive modular F# support with:
/// - Multiple build modes (Library, Executable, Script, Fable, Native)
/// - Build tool integration (dotnet, FAKE, direct fsc)
/// - Package managers (NuGet, Paket)
/// - Testing frameworks (Expecto, xUnit, NUnit, FsUnit, Unquote)
/// - Code formatting (Fantomas)
/// - Static analysis (FSharpLint, compiler warnings)
/// - F# Interactive (FSI) scripting
/// - Cross-platform (Fable for JS/TS, Native AOT, WASM)
/// 
/// Architecture:
///   core/          - Handler and configuration
///   managers/      - dotnet, FAKE, Paket, NuGet integration
///   tooling/       - Builders, formatters, analyzers, testers, detection
///   analysis/      - Static analysis integration
///   platforms/     - Cross-platform support (Fable, Native AOT)
///   interactive/   - F# Interactive support
/// 
/// Usage:
///   import languages.dotnet.fsharp;
///   
///   auto handler = new FSharpHandler();
///   auto config = parseFSharpConfig(target);
///   auto result = handler.build(target, workspaceConfig);

public import languages.dotnet.fsharp.core;
public import languages.dotnet.fsharp.managers;
public import languages.dotnet.fsharp.tooling;
public import languages.dotnet.fsharp.analysis;
public import languages.dotnet.fsharp.platforms;
public import languages.dotnet.fsharp.interactive;

