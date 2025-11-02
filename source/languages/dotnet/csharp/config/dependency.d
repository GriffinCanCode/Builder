module languages.dotnet.csharp.config.dependency;

import std.json;

/// NuGet package reference
struct NuGetPackage
{
    string id;
    string version_;
    bool includeAssets = true;
    bool privateAssets = false;
    string[] excludeAssets;
}

/// NuGet configuration
struct NuGetConfig
{
    bool restore = true;
    bool autoInstall = true;
    NuGetPackage[] packages;
    string[] sources;
    string configFile;
    bool noCache = false;
    bool forceEvaluate = false;
    bool lockFile = false;
    string lockedMode;
}

/// C# dependency configuration
struct CSharpDependencyConfig
{
    NuGetConfig nuget;
    string[] packageReferences;
    string[] projectReferences;
    bool autoRestore = true;
}

