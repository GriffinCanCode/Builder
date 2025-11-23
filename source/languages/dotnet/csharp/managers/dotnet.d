module languages.dotnet.csharp.managers.dotnet;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.dotnet.csharp.core.config;
import infrastructure.utils.logging.logger;
import infrastructure.utils.security.validation;

/// dotnet CLI operations
struct DotNetOps
{
    /// Build project with dotnet CLI
    static bool build(string projectRoot, in CSharpConfig config)
    {
        Logger.info("Building with dotnet CLI");
        
        string[] cmd = ["dotnet", "build"];
        
        // Configuration
        cmd ~= ["--configuration", config.configuration];
        
        // Output directory
        if (!config.outputPath.empty)
            cmd ~= ["--output", config.outputPath];
        
        // Framework
        auto framework = getFrameworkMoniker(config);
        if (!framework.empty)
            cmd ~= ["--framework", framework];
        
        // Runtime
        auto runtime = getRuntimeId(config);
        if (!runtime.empty && config.publish.selfContained)
            cmd ~= ["--runtime", runtime];
        
        // Verbosity
        if (!config.msbuild.verbosity.empty)
            cmd ~= ["--verbosity", config.msbuild.verbosity];
        
        // No restore
        if (!config.nuget.autoRestore)
            cmd ~= ["--no-restore"];
        
        // Additional MSBuild properties
        foreach (key, value; config.msbuild.properties)
        {
            cmd ~= ["-p:" ~ key ~ "=" ~ value];
        }
        
        // Language version
        if (config.languageVersion.major > 0)
        {
            cmd ~= ["-p:LangVersion=" ~ config.languageVersion.toString()];
        }
        
        // Nullable
        if (config.analysis.nullable)
        {
            cmd ~= ["-p:Nullable=enable"];
        }
        
        // Treat warnings as errors
        if (config.analysis.treatWarningsAsErrors)
        {
            cmd ~= ["-p:TreatWarningsAsErrors=true"];
        }
        
        // Execute build - use safe array form
        auto result = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.error("dotnet build failed");
            Logger.error("  Output: " ~ result.output);
            return false;
        }
        
        Logger.info("dotnet build succeeded");
        return true;
    }
    
    /// Publish project with dotnet CLI
    static bool publish(string projectRoot, in CSharpConfig config)
    {
        Logger.info("Publishing with dotnet CLI");
        
        string[] cmd = ["dotnet", "publish"];
        
        // Configuration
        cmd ~= ["--configuration", config.configuration];
        
        // Output directory
        if (!config.outputPath.empty)
            cmd ~= ["--output", config.outputPath];
        
        // Framework
        auto framework = getFrameworkMoniker(config);
        if (!framework.empty)
            cmd ~= ["--framework", framework];
        
        // Runtime
        auto runtime = getRuntimeId(config);
        if (!runtime.empty)
            cmd ~= ["--runtime", runtime];
        
        // Self-contained
        if (config.publish.selfContained)
        {
            cmd ~= ["--self-contained", "true"];
        }
        else
        {
            cmd ~= ["--self-contained", "false"];
        }
        
        // Single file
        if (config.publish.singleFile || config.mode == CSharpBuildMode.SingleFile)
        {
            cmd ~= ["-p:PublishSingleFile=true"];
        }
        
        // Ready to run
        if (config.publish.readyToRun || config.mode == CSharpBuildMode.ReadyToRun)
        {
            cmd ~= ["-p:PublishReadyToRun=true"];
        }
        
        // Native AOT
        if (config.publish.nativeAot || config.aot.enabled || config.mode == CSharpBuildMode.NativeAOT)
        {
            cmd ~= ["-p:PublishAot=true"];
            
            if (config.aot.optimizeForSize)
                cmd ~= ["-p:OptimizationPreference=Size"];
            
            if (config.aot.invariantGlobalization)
                cmd ~= ["-p:InvariantGlobalization=true"];
            
            if (!config.aot.stackTraceSupport)
                cmd ~= ["-p:StackTraceSupport=false"];
        }
        
        // Trimming
        if (config.publish.trimmed || config.mode == CSharpBuildMode.Trimmed)
        {
            cmd ~= ["-p:PublishTrimmed=true"];
            
            if (!config.publish.trimMode.empty)
                cmd ~= ["-p:TrimMode=" ~ config.publish.trimMode];
        }
        
        // Verbosity
        if (!config.msbuild.verbosity.empty)
            cmd ~= ["--verbosity", config.msbuild.verbosity];
        
        // Additional MSBuild properties
        foreach (key, value; config.msbuild.properties)
        {
            cmd ~= ["-p:" ~ key ~ "=" ~ value];
        }
        
        // Execute publish - use safe array form
        auto result = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.error("dotnet publish failed");
            Logger.error("  Output: " ~ result.output);
            return false;
        }
        
        Logger.info("dotnet publish succeeded");
        return true;
    }
    
    /// Run tests with dotnet CLI
    static bool test(string projectRoot, TestConfig config)
    {
        Logger.info("Running tests with dotnet CLI");
        
        string[] cmd = ["dotnet", "test"];
        
        // Filter
        if (!config.filter.empty)
            cmd ~= ["--filter", config.filter];
        
        // Logger
        if (!config.logger.empty)
            cmd ~= ["--logger", config.logger];
        
        // Results directory
        if (!config.resultsDirectory.empty)
            cmd ~= ["--results-directory", config.resultsDirectory];
        
        // No build (assume already built)
        cmd ~= ["--no-build"];
        
        // Verbosity
        if (config.verbose)
            cmd ~= ["--verbosity", "detailed"];
        else
            cmd ~= ["--verbosity", "normal"];
        
        // Blame mode
        if (config.blame)
            cmd ~= ["--blame"];
        
        // Coverage
        if (config.coverage)
        {
            cmd ~= ["--collect:\"XPlat Code Coverage\""];
        }
        
        // Execute tests - use safe array form
        auto result = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.error("dotnet test failed");
            Logger.error("  Output: " ~ result.output);
            return false;
        }
        
        Logger.info("dotnet test succeeded");
        return true;
    }
    
    /// Run project with dotnet CLI
    static bool run(string projectRoot, string[] args = [])
    {
        Logger.info("Running with dotnet CLI");
        
        string[] cmd = ["dotnet", "run"];
        
        if (args.length > 0)
        {
            cmd ~= ["--"];
            cmd ~= args;
        }
        
        // Use safe array form instead of executeShell
        auto result = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.error("dotnet run failed");
            Logger.error("  Output: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Clean project with dotnet CLI
    static bool clean(string projectRoot)
    {
        Logger.info("Cleaning with dotnet CLI");
        
        string[] cmd = ["dotnet", "clean"];
        
        // Use safe array form instead of executeShell
        auto result = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.warning("dotnet clean had issues: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Pack project into NuGet package
    static bool pack(string projectRoot, CSharpConfig config)
    {
        Logger.info("Packing with dotnet CLI");
        
        string[] cmd = ["dotnet", "pack"];
        
        // Configuration
        cmd ~= ["--configuration", config.configuration];
        
        // Output directory
        if (!config.outputPath.empty)
            cmd ~= ["--output", config.outputPath];
        
        // NuGet configuration
        if (!config.nuget.packageVersion.empty)
            cmd ~= ["-p:PackageVersion=" ~ config.nuget.packageVersion];
        
        if (!config.nuget.packageId.empty)
            cmd ~= ["-p:PackageId=" ~ config.nuget.packageId];
        
        if (config.nuget.symbols)
            cmd ~= ["--include-symbols", "-p:SymbolPackageFormat=snupkg"];
        
        // Execute pack - use safe array form
        auto result = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.error("dotnet pack failed");
            Logger.error("  Output: " ~ result.output);
            return false;
        }
        
        Logger.info("dotnet pack succeeded");
        return true;
    }
}

/// Get framework moniker from config
private string getFrameworkMoniker(const CSharpConfig config)
{
    if (!config.customFramework.empty)
        return config.customFramework;
    
    final switch (config.framework)
    {
        case DotNetFramework.Auto:
            return "";
        case DotNetFramework.Net48:
            return "net48";
        case DotNetFramework.Net472:
            return "net472";
        case DotNetFramework.Net461:
            return "net461";
        case DotNetFramework.Net6:
            return "net6.0";
        case DotNetFramework.Net7:
            return "net7.0";
        case DotNetFramework.Net8:
            return "net8.0";
        case DotNetFramework.Net9:
            return "net9.0";
        case DotNetFramework.NetStandard21:
            return "netstandard2.1";
        case DotNetFramework.NetStandard20:
            return "netstandard2.0";
        case DotNetFramework.Mono:
            return "mono";
        case DotNetFramework.Custom:
            return "";
    }
}

/// Get runtime identifier from config
private string getRuntimeId(const CSharpConfig config)
{
    if (!config.customRuntime.empty)
        return config.customRuntime;
    
    final switch (config.runtime)
    {
        case RuntimeIdentifier.Auto:
            return "";
        case RuntimeIdentifier.WinX64:
            return "win-x64";
        case RuntimeIdentifier.WinX86:
            return "win-x86";
        case RuntimeIdentifier.WinArm64:
            return "win-arm64";
        case RuntimeIdentifier.LinuxX64:
            return "linux-x64";
        case RuntimeIdentifier.LinuxArm64:
            return "linux-arm64";
        case RuntimeIdentifier.LinuxArm:
            return "linux-arm";
        case RuntimeIdentifier.OsxX64:
            return "osx-x64";
        case RuntimeIdentifier.OsxArm64:
            return "osx-arm64";
        case RuntimeIdentifier.Portable:
            return "";
        case RuntimeIdentifier.Custom:
            return "";
    }
}

