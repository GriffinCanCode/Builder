module languages.scripting.go.builders.standard;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.scripting.go.builders.base;
import languages.scripting.go.core.config;
import languages.scripting.go.managers.modules;
import languages.scripting.go.tooling.tools;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Standard Go builder - uses go build command
class StandardBuilder : GoBuilder
{
    override GoBuildResult build(
        in string[] sources,
        in GoConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        GoBuildResult result;
        
        if (!isAvailable())
        {
            result.error = "Go compiler not available. Install Go from https://golang.org/dl/";
            return result;
        }
        
        // Determine working directory (module root)
        string workDir = workspace.root;
        if (!sources.empty)
            workDir = dirName(sources[0]);
        
        // Check if in a module
        auto goModPath = ModuleAnalyzer.findGoMod(workDir);
        bool inModule = !goModPath.empty;
        
        if (!inModule && config.modMode != GoModMode.Off)
        {
            Logger.warning("No go.mod found. Consider running: go mod init <module-path>");
        }
        
        // Run go generate if requested
        if (config.generate)
        {
            auto genResult = GoTools.generate([], workDir);
            if (!genResult.success)
            {
                result.error = "go generate failed: " ~ genResult.errors.join("\n");
                return result;
            }
        }
        
        // Run go mod tidy if requested
        if (config.modTidy && inModule)
        {
            auto tidyResult = GoTools.modTidy(workDir);
            if (!tidyResult.success)
            {
                result.error = "go mod tidy failed: " ~ tidyResult.errors.join("\n");
                return result;
            }
        }
        
        // Install dependencies if requested
        if (config.installDeps && inModule)
        {
            auto downloadResult = GoTools.modDownload(workDir);
            if (!downloadResult.success)
            {
                Logger.warning("Failed to download dependencies: " ~ downloadResult.errors.join("\n"));
            }
        }
        
        // Vendor dependencies if requested
        if (config.vendor && inModule)
        {
            auto vendorResult = GoTools.modVendor(workDir);
            if (!vendorResult.success)
            {
                Logger.warning("Failed to vendor dependencies: " ~ vendorResult.errors.join("\n"));
            }
        }
        
        // Run formatting if requested
        if (config.runFmt)
        {
            auto fmtResult = GoTools.format(sources, true);
            if (!fmtResult.success)
            {
                Logger.warning("Formatting issues: " ~ fmtResult.errors.join("\n"));
            }
            result.toolWarnings ~= fmtResult.warnings;
        }
        
        // Run go vet if requested
        if (config.runVet)
        {
            auto vetResult = GoTools.vet([], workDir);
            if (!vetResult.success)
            {
                result.hadToolErrors = true;
                result.toolWarnings ~= vetResult.errors;
                Logger.warning("go vet found issues:\n" ~ vetResult.errors.join("\n"));
            }
        }
        
        // Run linter if requested
        if (config.runLint)
        {
            ToolResult lintResult;
            
            if (config.linter == "golangci-lint")
                lintResult = GoTools.lintGolangCI(workDir);
            else if (config.linter == "staticcheck")
                lintResult = GoTools.lintStaticCheck(workDir);
            else if (config.linter == "golint")
                lintResult = GoTools.lintGoLint([], workDir);
            else
                lintResult = GoTools.lintGolangCI(workDir); // Default
            
            if (lintResult.hasIssues())
            {
                result.toolWarnings ~= lintResult.warnings;
                Logger.info("Linter found issues:\n" ~ lintResult.warnings.join("\n"));
            }
        }
        
        // Build the actual binary
        auto buildResult = executeBuild(sources, config, target, workspace, workDir);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    bool isAvailable()
    {
        return GoTools.isGoAvailable();
    }
    
    string name() const
    {
        return "standard";
    }
    
    string getVersion()
    {
        return GoTools.getGoVersion();
    }
    
    bool supportsMode(GoBuildMode mode)
    {
        return mode == GoBuildMode.Executable ||
               mode == GoBuildMode.Library ||
               mode == GoBuildMode.PIE ||
               mode == GoBuildMode.Shared;
    }
    
    private GoBuildResult executeBuild(
        string[] sources,
        GoConfig config,
        Target target,
        WorkspaceConfig workspace,
        string workDir
    )
    {
        GoBuildResult result;
        
        // Determine output path
        string outputPath;
        if (!target.outputPath.empty)
        {
            outputPath = buildPath(workspace.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputPath = buildPath(workspace.options.outputDir, name);
        }
        
        // Create output directory
        auto outputDir = dirName(outputPath);
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build go build command
        string[] cmd = ["go", "build"];
        
        // Build mode
        if (config.mode != GoBuildMode.Executable)
        {
            cmd ~= "-buildmode";
            cmd ~= buildModeToString(config.mode);
        }
        
        // Output path
        cmd ~= ["-o", outputPath];
        
        // Trimpath
        if (config.trimpath)
            cmd ~= "-trimpath";
        
        // Build tags
        auto allTags = config.buildTags ~ config.constraints.tags;
        if (!allTags.empty)
        {
            cmd ~= "-tags";
            cmd ~= allTags.join(",");
        }
        
        // Compiler flags
        if (!config.gcflags.empty)
        {
            cmd ~= "-gcflags";
            cmd ~= config.gcflags.join(" ");
        }
        
        // Linker flags
        if (!config.ldflags.empty)
        {
            cmd ~= "-ldflags";
            cmd ~= config.ldflags.join(" ");
        }
        
        // Assembly flags
        if (!config.asmflags.empty)
        {
            cmd ~= "-asmflags";
            cmd ~= config.asmflags.join(" ");
        }
        
        // GCC flags (for gccgo)
        if (!config.gccgoflags.empty)
        {
            cmd ~= "-gccgoflags";
            cmd ~= config.gccgoflags.join(" ");
        }
        
        // Work directory
        if (!config.workDir.empty)
        {
            cmd ~= "-work";
            cmd ~= "-workdir";
            cmd ~= config.workDir;
        }
        
        // Vendor mode
        if (config.vendor || config.modMode == GoModMode.Vendor)
        {
            cmd ~= "-mod";
            cmd ~= "vendor";
        }
        else if (config.modMode != GoModMode.Auto)
        {
            cmd ~= "-mod";
            cmd ~= modModeToString(config.modMode);
        }
        
        // Add target flags
        cmd ~= target.flags;
        
        // Add sources or packages
        if (sources.empty)
            cmd ~= ".";
        else
            cmd ~= sources;
        
        Logger.debug_("Building Go binary: " ~ cmd.join(" "));
        
        // Prepare environment
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        // Add CGO environment
        if (config.cgo.enabled)
        {
            foreach (key, value; config.cgo.toEnv())
                env[key] = value;
        }
        
        // Add module mode environment
        if (config.modMode != GoModMode.Auto)
        {
            env["GO111MODULE"] = modModeToEnvString(config.modMode);
        }
        
        // Add module cache directory
        if (!config.modCacheDir.empty)
        {
            env["GOMODCACHE"] = config.modCacheDir;
        }
        
        // Execute build
        auto res = execute(cmd, env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "Go build failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        
        // Calculate hash
        if (exists(outputPath))
            result.outputHash = FastHash.hashFile(outputPath);
        else
            result.outputHash = FastHash.hashStrings(sources);
        
        return result;
    }
    
    private string buildModeToString(GoBuildMode mode)
    {
        final switch (mode)
        {
            case GoBuildMode.Executable: return "exe";
            case GoBuildMode.CArchive: return "c-archive";
            case GoBuildMode.CShared: return "c-shared";
            case GoBuildMode.Plugin: return "plugin";
            case GoBuildMode.PIE: return "pie";
            case GoBuildMode.Shared: return "shared";
            case GoBuildMode.Library: return "default";
        }
    }
    
    private string modModeToString(GoModMode mode)
    {
        final switch (mode)
        {
            case GoModMode.Auto: return "";
            case GoModMode.On: return "mod";
            case GoModMode.Off: return ""; // Handled by GO111MODULE
            case GoModMode.Readonly: return "readonly";
            case GoModMode.Vendor: return "vendor";
        }
    }
    
    private string modModeToEnvString(GoModMode mode)
    {
        final switch (mode)
        {
            case GoModMode.Auto: return "auto";
            case GoModMode.On: return "on";
            case GoModMode.Off: return "off";
            case GoModMode.Readonly: return "on";
            case GoModMode.Vendor: return "on";
        }
    }
}

