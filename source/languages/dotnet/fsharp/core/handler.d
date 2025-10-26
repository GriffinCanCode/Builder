module languages.dotnet.fsharp.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.base.base;
import languages.dotnet.fsharp.core.config;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// F# build handler - main orchestrator
class FSharpHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building F# target: " ~ target.name);
        
        // Parse F# configuration
        FSharpConfig fsConfig = parseFSharpConfig(target);
        
        // Auto-detect build tool if needed
        if (fsConfig.buildTool == FSharpBuildTool.Auto)
        {
            fsConfig.buildTool = detectBuildTool();
        }
        
        // Auto-detect package manager if needed
        if (fsConfig.packageManager == FSharpPackageManager.Auto)
        {
            fsConfig.packageManager = detectPackageManager();
        }
        
        // Route to appropriate build strategy
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, fsConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, fsConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, fsConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, fsConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(Target target, WorkspaceConfig config)
    {
        string[] outputs;
        FSharpConfig fsConfig = parseFSharpConfig(target);
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Determine output based on mode and platform
            final switch (fsConfig.mode)
            {
                case FSharpBuildMode.Library:
                    outputs ~= buildPath(config.options.outputDir, name ~ ".dll");
                    break;
                case FSharpBuildMode.Executable:
                    version(Windows)
                        outputs ~= buildPath(config.options.outputDir, name ~ ".exe");
                    else
                        outputs ~= buildPath(config.options.outputDir, name);
                    break;
                case FSharpBuildMode.Script:
                    // Scripts don't produce output files
                    break;
                case FSharpBuildMode.Fable:
                    if (fsConfig.fable.typescript)
                        outputs ~= buildPath(config.options.outputDir, fsConfig.fable.outDir, name ~ ".ts");
                    else
                        outputs ~= buildPath(config.options.outputDir, fsConfig.fable.outDir, name ~ ".js");
                    break;
                case FSharpBuildMode.Wasm:
                    outputs ~= buildPath(config.options.outputDir, name ~ ".wasm");
                    break;
                case FSharpBuildMode.Native:
                    version(Windows)
                        outputs ~= buildPath(config.options.outputDir, name ~ ".exe");
                    else
                        outputs ~= buildPath(config.options.outputDir, name);
                    break;
                case FSharpBuildMode.Compile:
                    outputs ~= buildPath(config.options.outputDir, name ~ ".dll");
                    break;
            }
        }
        
        return outputs;
    }
    
    override Import[] analyzeImports(string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.FSharp);
        if (spec is null)
            return [];
        
        Import[] allImports;
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            try
            {
                auto content = readText(source);
                auto imports = spec.scanImports(source, content);
                allImports ~= imports;
            }
            catch (Exception e)
            {
                Logger.warning("Failed to analyze imports in " ~ source);
            }
        }
        
        return allImports;
    }
    
    private LanguageBuildResult buildExecutable(Target target, WorkspaceConfig config, FSharpConfig fsConfig)
    {
        // Ensure mode is set to executable
        fsConfig.mode = FSharpBuildMode.Executable;
        
        // Delegate to appropriate builder based on build tool
        return buildWithTool(target, config, fsConfig);
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config, FSharpConfig fsConfig)
    {
        // Ensure mode is set to library
        fsConfig.mode = FSharpBuildMode.Library;
        
        return buildWithTool(target, config, fsConfig);
    }
    
    private LanguageBuildResult buildWithTool(Target target, WorkspaceConfig config, FSharpConfig fsConfig)
    {
        LanguageBuildResult result;
        
        final switch (fsConfig.buildTool)
        {
            case FSharpBuildTool.Auto:
                // Shouldn't reach here - auto should be resolved
                fsConfig.buildTool = FSharpBuildTool.Dotnet;
                goto case FSharpBuildTool.Dotnet;
                
            case FSharpBuildTool.Dotnet:
                result = buildWithDotnet(target, config, fsConfig);
                break;
                
            case FSharpBuildTool.FAKE:
                result = buildWithFAKE(target, config, fsConfig);
                break;
                
            case FSharpBuildTool.Direct:
                result = buildWithFSC(target, config, fsConfig);
                break;
                
            case FSharpBuildTool.None:
                result.error = "Build tool set to None - cannot build";
                break;
        }
        
        return result;
    }
    
    private LanguageBuildResult buildWithDotnet(Target target, WorkspaceConfig config, FSharpConfig fsConfig)
    {
        LanguageBuildResult result;
        
        auto outputs = getOutputs(target, config);
        if (outputs.empty)
        {
            result.error = "No output path specified";
            return result;
        }
        
        auto outputPath = outputs[0];
        auto outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build command
        string[] cmd = ["dotnet", "build"];
        
        // Add configuration
        cmd ~= ["--configuration", fsConfig.dotnet.configuration];
        
        // Add framework
        if (!fsConfig.dotnet.framework.identifier.empty)
            cmd ~= ["--framework", fsConfig.dotnet.framework.identifier];
        
        // Add runtime
        if (!fsConfig.dotnet.runtime.empty)
            cmd ~= ["--runtime", fsConfig.dotnet.runtime];
        
        // Add output directory
        if (!fsConfig.dotnet.outputDir.empty)
            cmd ~= ["--output", fsConfig.dotnet.outputDir];
        else
            cmd ~= ["--output", outputDir];
        
        // Add verbosity
        cmd ~= ["--verbosity", fsConfig.dotnet.verbosity];
        
        // Restoration options
        if (fsConfig.dotnet.noRestore)
            cmd ~= ["--no-restore"];
        
        if (fsConfig.dotnet.noDependencies)
            cmd ~= ["--no-dependencies"];
        
        if (fsConfig.dotnet.force)
            cmd ~= ["--force"];
        
        // Self-contained
        if (fsConfig.dotnet.selfContained)
        {
            cmd ~= ["--self-contained"];
            
            if (fsConfig.dotnet.singleFile)
                cmd ~= ["-p:PublishSingleFile=true"];
            
            if (fsConfig.dotnet.readyToRun)
                cmd ~= ["-p:PublishReadyToRun=true"];
            
            if (fsConfig.dotnet.trimmed)
                cmd ~= ["-p:PublishTrimmed=true"];
        }
        
        // Add custom flags
        cmd ~= target.flags;
        cmd ~= fsConfig.compilerFlags.map!(f => "-p:OtherFlags=\"" ~ f ~ "\"").array;
        
        // Find .fsproj file
        string projectFile;
        foreach (source; target.sources)
        {
            if (source.endsWith(".fsproj"))
            {
                projectFile = source;
                break;
            }
        }
        
        if (projectFile.empty)
        {
            // Look for .fsproj in current directory
            auto cwd = getcwd();
            auto fsprojFiles = dirEntries(cwd, "*.fsproj", SpanMode.shallow).array;
            if (!fsprojFiles.empty)
                projectFile = fsprojFiles[0].name;
        }
        
        if (!projectFile.empty)
            cmd ~= [projectFile];
        
        // Execute build
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "dotnet build failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = outputs;
        
        if (exists(outputPath))
            result.outputHash = FastHash.hashFile(outputPath);
        else
            result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildWithFAKE(Target target, WorkspaceConfig config, FSharpConfig fsConfig)
    {
        LanguageBuildResult result;
        
        // Check if FAKE script exists
        if (!exists(fsConfig.fake.scriptFile))
        {
            result.error = "FAKE script not found: " ~ fsConfig.fake.scriptFile;
            return result;
        }
        
        // Build command
        string[] cmd = ["dotnet", "fake", "run", fsConfig.fake.scriptFile];
        
        // Add target
        if (!fsConfig.fake.target.empty)
            cmd ~= ["--target", fsConfig.fake.target];
        
        // Add arguments
        cmd ~= fsConfig.fake.arguments;
        
        // Add flags
        if (fsConfig.fake.verbose)
            cmd ~= ["--verbose"];
        
        if (fsConfig.fake.singleTarget)
            cmd ~= ["--single-target"];
        
        if (fsConfig.fake.parallel)
            cmd ~= ["--parallel", "true"];
        
        // Execute FAKE
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "FAKE build failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = getOutputs(target, config);
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildWithFSC(Target target, WorkspaceConfig config, FSharpConfig fsConfig)
    {
        LanguageBuildResult result;
        
        auto outputs = getOutputs(target, config);
        if (outputs.empty)
        {
            result.error = "No output path specified";
            return result;
        }
        
        auto outputPath = outputs[0];
        auto outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build command
        string[] cmd = ["fsc"];
        
        // Add output
        cmd ~= ["--out:" ~ outputPath];
        
        // Add target type
        if (fsConfig.mode == FSharpBuildMode.Executable)
            cmd ~= ["--target:exe"];
        else
            cmd ~= ["--target:library"];
        
        // Add optimization flags
        if (fsConfig.optimize)
            cmd ~= ["--optimize+"];
        else
            cmd ~= ["--optimize-"];
        
        // Add debug symbols
        if (fsConfig.debug_)
            cmd ~= ["--debug+", "--debug:full"];
        else if (target.name.indexOf("release") >= 0 || target.name.indexOf("Release") >= 0)
            cmd ~= ["--debug-"];
        
        // Tail calls
        if (fsConfig.tailcalls)
            cmd ~= ["--tailcalls+"];
        else
            cmd ~= ["--tailcalls-"];
        
        // Checked arithmetic
        if (fsConfig.checked)
            cmd ~= ["--checked+"];
        else
            cmd ~= ["--checked-"];
        
        // Deterministic
        if (fsConfig.deterministic)
            cmd ~= ["--deterministic+"];
        
        // Cross-optimize
        if (fsConfig.crossoptimize)
            cmd ~= ["--crossoptimize+"];
        
        // Defines
        foreach (define; fsConfig.defines)
            cmd ~= ["--define:" ~ define];
        
        // Warnings
        cmd ~= ["--warn:" ~ fsConfig.analysis.warningLevel.to!string];
        
        if (fsConfig.analysis.warningsAsErrors)
            cmd ~= ["--warnaserror+"];
        
        foreach (warn; fsConfig.analysis.warningsAsErrorsList)
            cmd ~= ["--warnaserror:" ~ warn.to!string];
        
        foreach (warn; fsConfig.analysis.disableWarnings)
            cmd ~= ["--nowarn:" ~ warn.to!string];
        
        // XML documentation
        if (!fsConfig.xmlDoc.empty)
            cmd ~= ["--doc:" ~ fsConfig.xmlDoc];
        
        // Add references for dependencies
        foreach (dep; target.deps)
        {
            auto depTarget = config.findTarget(dep);
            if (depTarget !is null)
            {
                auto depOutputs = getOutputs(*depTarget, config);
                foreach (depOut; depOutputs)
                    cmd ~= ["--reference:" ~ depOut];
            }
        }
        
        // Add compiler flags
        cmd ~= target.flags;
        cmd ~= fsConfig.compilerFlags;
        
        // Add source files
        cmd ~= target.sources.filter!(s => s.endsWith(".fs") || s.endsWith(".fsx") || s.endsWith(".fsi")).array;
        
        // Execute compilation
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "fsc failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config, FSharpConfig fsConfig)
    {
        LanguageBuildResult result;
        
        // Use dotnet test if available
        if (fsConfig.buildTool == FSharpBuildTool.Dotnet || fsConfig.buildTool == FSharpBuildTool.Auto)
        {
            string[] cmd = ["dotnet", "test"];
            
            // Add configuration
            cmd ~= ["--configuration", fsConfig.dotnet.configuration];
            
            // Add framework
            if (!fsConfig.dotnet.framework.identifier.empty)
                cmd ~= ["--framework", fsConfig.dotnet.framework.identifier];
            
            // Add verbosity
            cmd ~= ["--verbosity", fsConfig.dotnet.verbosity];
            
            // Test options
            if (!fsConfig.test.filter.empty)
                cmd ~= ["--filter", fsConfig.test.filter];
            
            // Coverage
            if (fsConfig.test.coverage)
            {
                cmd ~= ["--collect:\"XPlat Code Coverage\""];
            }
            
            // Find .fsproj test file
            string testProject;
            foreach (source; target.sources)
            {
                if (source.endsWith(".fsproj"))
                {
                    testProject = source;
                    break;
                }
            }
            
            if (!testProject.empty)
                cmd ~= [testProject];
            
            // Add test flags
            cmd ~= fsConfig.test.testFlags;
            
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Tests failed: " ~ res.output;
                return result;
            }
            
            result.success = true;
            result.outputHash = FastHash.hashStrings(target.sources);
        }
        else
        {
            // Build and run tests manually
            auto buildResult = buildExecutable(target, config, fsConfig);
            if (!buildResult.success)
            {
                result.error = buildResult.error;
                return result;
            }
            
            // Run the test executable
            if (!buildResult.outputs.empty)
            {
                auto res = execute([buildResult.outputs[0]]);
                
                if (res.status != 0)
                {
                    result.error = "Test execution failed: " ~ res.output;
                    return result;
                }
            }
            
            result.success = true;
            result.outputHash = buildResult.outputHash;
        }
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(Target target, WorkspaceConfig config, FSharpConfig fsConfig)
    {
        LanguageBuildResult result;
        
        if (!target.commands.empty)
        {
            foreach (cmd; target.commands)
            {
                auto res = executeShell(cmd);
                if (res.status != 0)
                {
                    result.error = "Command failed: " ~ cmd ~ "\n" ~ res.output;
                    return result;
                }
            }
        }
        
        result.success = true;
        result.outputs = getOutputs(target, config);
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Detect build tool from project structure
    private FSharpBuildTool detectBuildTool()
    {
        // Check for .fsproj (dotnet)
        auto fsprojFiles = dirEntries(".", "*.fsproj", SpanMode.shallow, false);
        if (!fsprojFiles.empty)
            return FSharpBuildTool.Dotnet;
        
        // Check for FAKE script
        if (exists("build.fsx") || exists("Build.fsx"))
            return FSharpBuildTool.FAKE;
        
        // Default to dotnet CLI
        return FSharpBuildTool.Dotnet;
    }
    
    /// Detect package manager from project structure
    private FSharpPackageManager detectPackageManager()
    {
        // Check for Paket
        if (exists("paket.dependencies") || exists("paket.lock"))
            return FSharpPackageManager.Paket;
        
        // Check for NuGet
        if (exists("packages.config") || exists("nuget.config"))
            return FSharpPackageManager.NuGet;
        
        // Default to NuGet (most common)
        return FSharpPackageManager.NuGet;
    }
}

