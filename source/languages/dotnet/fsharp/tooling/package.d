module languages.dotnet.fsharp.tooling;

/// F# Tooling Package
/// 
/// Development tools and utilities for F# builds:
/// - Builders: Build strategy implementations
/// - Formatters: Code formatting (Fantomas)
/// - Analyzers: Static analysis (FSharpLint, compiler)
/// - Testers: Test frameworks (Expecto, xUnit, NUnit)
/// - Packagers: Package creation (NuGet)
/// - Detection: Tool detection and version management

public import languages.dotnet.fsharp.tooling.builders;
public import languages.dotnet.fsharp.tooling.formatters;
public import languages.dotnet.fsharp.tooling.analyzers;
public import languages.dotnet.fsharp.tooling.testers;
public import languages.dotnet.fsharp.tooling.packagers;
public import languages.dotnet.fsharp.tooling.detection;

