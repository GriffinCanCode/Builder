module languages.dotnet.csharp;

/// C# Language Support
/// 
/// Comprehensive modular C# support with:
/// - Multiple build modes (Standard, Single-File, Native AOT, R2R, Trimmed)
/// - Build tool integration (dotnet CLI, MSBuild, csc)
/// - Framework targets (.NET 6/7/8/9, .NET Framework, .NET Standard)
/// - Runtime publishing (Self-contained, portable, cross-platform)
/// - Project types (Console, Library, Web API, Blazor, MAUI, etc.)
/// - Code formatting (dotnet-format, CSharpier)
/// - Static analysis (Roslyn analyzers, StyleCop, etc.)
/// - NuGet package management
/// - Testing frameworks (xUnit, NUnit, MSTest)
/// - Native AOT compilation
/// - Modern C# features (C# 8-12+)
/// 
/// Architecture:
///   core/          - Handler and configuration
///   managers/      - dotnet CLI, MSBuild, and NuGet integration
///   tooling/       - Builders, formatters, analyzers, detection
///   analysis/      - .csproj and .sln parsing
/// 
/// Usage:
///   import languages.dotnet.csharp;
///   
///   auto handler = new CSharpHandler();
///   auto config = parseCSharpConfig(target);
///   auto result = handler.build(target, workspaceConfig);

public import languages.dotnet.csharp.core;
public import languages.dotnet.csharp.managers;
public import languages.dotnet.csharp.tooling;
public import languages.dotnet.csharp.analysis;

