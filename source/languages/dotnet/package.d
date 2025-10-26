module languages.dotnet;

/// .NET Languages Package
/// 
/// Support for .NET ecosystem languages:
/// - C# (csharp.d)
/// - F# (fsharp/) - Comprehensive modular support
///
/// F# includes:
/// - Multiple build modes (Library, Executable, Script, Fable, Native AOT)
/// - Build tools (dotnet CLI, FAKE, direct fsc)
/// - Package managers (NuGet, Paket)
/// - Testing frameworks (Expecto, xUnit, NUnit)
/// - Code formatting (Fantomas)
/// - Static analysis (FSharpLint)
/// - F# Interactive scripting
/// - Cross-platform (Fable for JS/TS, Native AOT, WASM)

public import languages.dotnet.csharp;
public import languages.dotnet.fsharp;

