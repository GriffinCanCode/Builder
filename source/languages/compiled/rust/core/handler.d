module languages.compiled.rust.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import std.string;
import languages.base.base;
import languages.compiled.rust.core.config;
import languages.compiled.rust.analysis.manifest;
import languages.compiled.rust.managers.toolchain;
import languages.compiled.rust.tooling.builders;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// Advanced Rust build handler with cargo, rustup, and toolchain support
class RustHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Rust target: " ~ target.name);
        
        // Parse Rust configuration
        RustConfig rustConfig = parseRustConfig(target);
        
        // Check and install toolchain if needed
        if (!rustConfig.toolchain.empty && rustConfig.installToolchain)
        {
            if (!ensureToolchain(rustConfig.toolchain))
            {
                result.error = "Failed to ensure toolchain: " ~ rustConfig.toolchain;
                return result;
            }
        }
        
        // Check and install target if needed
        if (!rustConfig.target.empty)
        {
            if (!ensureTarget(rustConfig.target, rustConfig.toolchain))
            {
                Logger.warning("Target triple may not be installed: " ~ rustConfig.target);
            }
        }
        
        // Run clippy if requested
        if (rustConfig.clippy)
        {
            auto clippyResult = runClippy(target, rustConfig, config);
            if (clippyResult.hadClippyIssues)
            {
                Logger.warning("Clippy found issues:");
                foreach (issue; clippyResult.clippyIssues)
                {
                    Logger.warning("  " ~ issue);
                }
            }
        }
        
        // Run rustfmt if requested
        if (rustConfig.fmt)
        {
            runRustfmt(target, rustConfig);
        }
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, rustConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, rustConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, rustConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, rustConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        RustConfig rustConfig = parseRustConfig(target);
        
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputs ~= buildPath(config.options.outputDir, name);
        }
        
        return outputs;
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.Rust);
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
    
    private LanguageBuildResult buildExecutable(Target target, WorkspaceConfig config, RustConfig rustConfig)
    {
        LanguageBuildResult result;
        
        // Set crate type to binary
        if (rustConfig.crateType == CrateType.Lib)
            rustConfig.crateType = CrateType.Bin;
        
        // Auto-detect entry point if not specified
        if (rustConfig.entry.empty && !target.sources.empty)
        {
            rustConfig.entry = target.sources[0];
        }
        
        // Build with selected compiler
        return compileTarget(target, config, rustConfig);
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config, RustConfig rustConfig)
    {
        LanguageBuildResult result;
        
        // Set crate type to library if not specified
        if (rustConfig.crateType == CrateType.Bin)
            rustConfig.crateType = CrateType.Lib;
        
        // Auto-detect entry point
        if (rustConfig.entry.empty && !target.sources.empty)
        {
            // Look for lib.rs first
            foreach (source; target.sources)
            {
                if (baseName(source) == "lib.rs")
                {
                    rustConfig.entry = source;
                    break;
                }
            }
            
            // Fallback to first source
            if (rustConfig.entry.empty)
                rustConfig.entry = target.sources[0];
        }
        
        return compileTarget(target, config, rustConfig);
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config, RustConfig rustConfig)
    {
        LanguageBuildResult result;
        
        // Set mode to test
        rustConfig.mode = RustBuildMode.Test;
        
        // Use test profile
        if (rustConfig.profile == RustProfile.Release)
            rustConfig.profile = RustProfile.Test;
        
        return compileTarget(target, config, rustConfig);
    }
    
    private LanguageBuildResult buildCustom(Target target, WorkspaceConfig config, RustConfig rustConfig)
    {
        LanguageBuildResult result;
        
        rustConfig.mode = RustBuildMode.Custom;
        
        return compileTarget(target, config, rustConfig);
    }
    
    private LanguageBuildResult compileTarget(Target target, WorkspaceConfig config, RustConfig rustConfig)
    {
        LanguageBuildResult result;
        
        // Create builder
        auto builder = RustBuilderFactory.create(rustConfig.compiler, rustConfig);
        
        if (!builder.isAvailable())
        {
            result.error = "Rust compiler '" ~ builder.name() ~ "' is not available. " ~
                          "Install Rust from https://rustup.rs/";
            return result;
        }
        
        Logger.debug_("Using Rust builder: " ~ builder.name() ~ " (" ~ builder.getVersion() ~ ")");
        
        // Compile
        auto compileResult = builder.build(target.sources, rustConfig, target, config);
        
        if (!compileResult.success)
        {
            result.error = compileResult.error;
            return result;
        }
        
        // Report warnings
        if (compileResult.hadWarnings)
        {
            Logger.warning("Compilation warnings:");
            foreach (warn; compileResult.warnings)
            {
                Logger.warning("  " ~ warn);
            }
        }
        
        result.success = true;
        result.outputs = compileResult.outputs ~ compileResult.artifacts;
        result.outputHash = compileResult.outputHash;
        
        return result;
    }
    
    private RustConfig parseRustConfig(Target target)
    {
        RustConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("rust" in target.langConfig)
            configKey = "rust";
        else if ("rustConfig" in target.langConfig)
            configKey = "rustConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = RustConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse Rust config, using defaults: " ~ e.msg);
            }
        }
        
        // Auto-detect Cargo.toml if not specified
        if (config.manifest.empty)
        {
            config.manifest = CargoParser.findManifest(target.sources);
            if (!config.manifest.empty)
            {
                Logger.debug_("Found Cargo.toml: " ~ config.manifest);
            }
        }
        
        // Auto-detect entry point if not specified
        if (config.entry.empty && !target.sources.empty)
        {
            config.entry = target.sources[0];
        }
        
        // Apply target flags to rustc flags
        if (!target.flags.empty)
        {
            config.rustcFlags ~= target.flags;
        }
        
        return config;
    }
    
    private bool ensureToolchain(string toolchain)
    {
        if (!Rustup.isAvailable())
        {
            Logger.warning("rustup not available, cannot ensure toolchain");
            return false;
        }
        
        auto toolchains = Rustup.listToolchains();
        
        foreach (tc; toolchains)
        {
            if (tc.name == toolchain && tc.isInstalled)
            {
                Logger.debug_("Toolchain already installed: " ~ toolchain);
                return true;
            }
        }
        
        // Install toolchain
        return Rustup.installToolchain(toolchain);
    }
    
    private bool ensureTarget(string target, string toolchain)
    {
        if (!Rustup.isAvailable())
        {
            Logger.warning("rustup not available, cannot ensure target");
            return false;
        }
        
        auto targets = Rustup.listTargets(toolchain);
        
        foreach (t; targets)
        {
            if (t.name == target && t.isInstalled)
            {
                Logger.debug_("Target already installed: " ~ target);
                return true;
            }
        }
        
        // Install target
        return Rustup.installTarget(target, toolchain);
    }
    
    private RustCompileResult runClippy(Target target, RustConfig config, WorkspaceConfig workspace)
    {
        RustCompileResult result;
        
        if (!Clippy.isAvailable())
        {
            Logger.warning("Clippy not available, skipping");
            result.success = true;
            return result;
        }
        
        Logger.info("Running clippy...");
        
        string manifestPath = config.manifest.empty
            ? CargoParser.findManifest(target.sources)
            : config.manifest;
        
        if (manifestPath.empty)
        {
            Logger.warning("No Cargo.toml found, skipping clippy");
            result.success = true;
            return result;
        }
        
        string projectDir = dirName(manifestPath);
        
        auto res = Clippy.run(projectDir, config.clippyFlags);
        
        if (res.status != 0)
        {
            result.hadClippyIssues = true;
            
            // Parse clippy output
            foreach (line; res.output.split("\n"))
            {
                if (line.canFind("warning:") || line.canFind("error:"))
                {
                    result.clippyIssues ~= line;
                }
            }
        }
        
        result.success = true;
        return result;
    }
    
    private void runRustfmt(Target target, RustConfig config)
    {
        if (!Rustfmt.isAvailable())
        {
            Logger.warning("rustfmt not available, skipping");
            return;
        }
        
        Logger.info("Running rustfmt...");
        
        string manifestPath = config.manifest.empty
            ? CargoParser.findManifest(target.sources)
            : config.manifest;
        
        if (manifestPath.empty)
        {
            Logger.warning("No Cargo.toml found, skipping rustfmt");
            return;
        }
        
        string projectDir = dirName(manifestPath);
        
        auto res = Rustfmt.format(projectDir);
        
        if (res.status != 0)
        {
            Logger.warning("rustfmt failed: " ~ res.output);
        }
        else
        {
            Logger.info("Code formatted successfully");
        }
    }
}


