module languages.dotnet.fsharp.tooling.builders;

/// F# Builders Package
/// 
/// Build strategy implementations for different F# output types:
/// - Library: DLL libraries
/// - Executable: Console/GUI applications
/// - Script: F# Interactive scripts
/// - Fable: JavaScript/TypeScript via Fable
/// - Native: Native AOT executables

public import languages.dotnet.fsharp.tooling.builders.base;
public import languages.dotnet.fsharp.tooling.builders.library;
public import languages.dotnet.fsharp.tooling.builders.executable;
public import languages.dotnet.fsharp.tooling.builders.script;
public import languages.dotnet.fsharp.tooling.builders.fable;
public import languages.dotnet.fsharp.tooling.builders.native;

