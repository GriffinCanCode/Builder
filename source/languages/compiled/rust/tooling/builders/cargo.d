module languages.compiled.rust.tooling.builders.cargo;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.rust.tooling.builders.base;
import languages.compiled.rust.core.config;
import languages.compiled.rust.analysis.manifest;
import languages.compiled.rust.managers.toolchain;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// Cargo builder - uses cargo for compilation
class CargoBuilder : RustBuilder
{
    RustCompileResult build(
        in string[] sources,
        in RustConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        RustCompileResult result;
        
        // Find or use specified manifest
        string manifestPath = config.manifest.empty
            ? CargoParser.findManifest(sources)
            : config.manifest;
        
        if (manifestPath.empty)
        {
            result.error = "No Cargo.toml found. Use rustc builder for single-file builds.";
            return result;
        }
        
        string projectDir = dirName(manifestPath);
        Logger.debugLog("Building Rust project in: " ~ projectDir);
        
        // Parse manifest for metadata
        auto manifest = CargoParser.parse(manifestPath);
        Logger.debugLog("Package: " ~ manifest.package_.name ~ " v" ~ manifest.package_.version_);
        
        // Build command based on mode
        final switch (config.mode)
        {
            case RustBuildMode.Compile:
                return buildTarget(config, projectDir, workspace);
            case RustBuildMode.Check:
                return checkTarget(config, projectDir, workspace);
            case RustBuildMode.Test:
                return testTarget(config, projectDir, workspace);
            case RustBuildMode.Doc:
                return buildDoc(config, projectDir, workspace);
            case RustBuildMode.Bench:
                return benchTarget(config, projectDir, workspace);
            case RustBuildMode.Example:
                return buildExample(config, projectDir, workspace);
            case RustBuildMode.Custom:
                return buildCustom(config, projectDir, workspace);
        }
    }
    
    bool isAvailable()
    {
        return Cargo.isAvailable();
    }
    
    string name() const
    {
        return "cargo";
    }
    
    string getVersion()
    {
        return Cargo.getVersion();
    }
    
    bool supportsFeature(string feature)
    {
        // Cargo supports all features
        return true;
    }
    
    private RustCompileResult buildTarget(in RustConfig config, string projectDir, in WorkspaceConfig workspace)
    {
        RustCompileResult result;
        
        // Build cargo command
        string[] cmd = ["cargo", "build"];
        
        // Add profile
        if (config.release || config.profile == RustProfile.Release)
            cmd ~= ["--release"];
        else if (config.profile == RustProfile.Custom && !config.customProfile.empty)
            cmd ~= ["--profile", config.customProfile];
        
        // Add target triple
        if (!config.target.empty)
            cmd ~= ["--target", config.target];
        
        // Add features
        if (config.allFeatures)
            cmd ~= ["--all-features"];
        else if (config.noDefaultFeatures)
            cmd ~= ["--no-default-features"];
        
        if (!config.features.empty)
            cmd ~= ["--features", config.features.join(",")];
        
        // Add package selection
        if (!config.package_.empty)
            cmd ~= ["--package", config.package_];
        else if (config.workspace)
            cmd ~= ["--workspace"];
        
        if (!config.exclude.empty)
        {
            foreach (ex; config.exclude)
                cmd ~= ["--exclude", ex];
        }
        
        // Add specific binary/lib
        if (!config.bin.empty)
            cmd ~= ["--bin", config.bin];
        
        // Add target directory
        if (!config.targetDir.empty)
            cmd ~= ["--target-dir", config.targetDir];
        
        // Add jobs
        if (config.jobs > 0)
            cmd ~= ["--jobs", config.jobs.to!string];
        
        // Add verbosity
        if (config.verbose > 0)
        {
            foreach (i; 0 .. config.verbose)
                cmd ~= ["-v"];
        }
        
        // Add color
        if (config.color != "auto")
            cmd ~= ["--color", config.color];
        
        // Add lockfile options
        if (config.frozen)
            cmd ~= ["--frozen"];
        else if (config.locked)
            cmd ~= ["--locked"];
        
        // Add offline mode
        if (config.offline)
            cmd ~= ["--offline"];
        
        // Add additional cargo flags
        cmd ~= config.cargoFlags;
        
        Logger.debugLog("Cargo command: " ~ cmd.join(" "));
        
        // Set environment variables
        string[string] env = null;
        if (!config.env.empty)
            env = cast(string[string])config.env.dup;
        
        // Add RUSTFLAGS
        if (!config.rustcFlags.empty)
        {
            string rustflags = config.rustcFlags.join(" ");
            if (env is null)
                env = ["RUSTFLAGS": rustflags];
            else
                env["RUSTFLAGS"] = rustflags;
        }
        
        // Execute build
        auto res = execute(cmd, env, Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = "Cargo build failed:\n" ~ res.output;
            return result;
        }
        
        // Parse warnings
        parseCargoOutput(res.output, result);
        
        // Determine output path
        string targetDir = config.targetDir.empty ? "target" : config.targetDir;
        string profileDir = config.release ? "release" : "debug";
        
        if (!config.target.empty)
            targetDir = buildPath(targetDir, config.target, profileDir);
        else
            targetDir = buildPath(targetDir, profileDir);
        
        string fullTargetDir = buildPath(projectDir, targetDir);
        
        // Find built artifacts
        if (exists(fullTargetDir) && isDir(fullTargetDir))
        {
            foreach (entry; dirEntries(fullTargetDir, SpanMode.shallow))
            {
                if (entry.isFile)
                {
                    auto name = baseName(entry.name);
                    // Add executables and libraries
                    if (!name.endsWith(".d") && !name.endsWith(".rlib"))
                        result.outputs ~= entry.name;
                    else if (name.endsWith(".rlib"))
                        result.artifacts ~= entry.name;
                }
            }
        }
        
        result.success = true;
        
        // Hash outputs
        if (!result.outputs.empty)
            result.outputHash = FastHash.hashFile(result.outputs[0]);
        else
            result.outputHash = FastHash.hashString(res.output);
        
        return result;
    }
    
    private RustCompileResult checkTarget(in RustConfig config, string projectDir, in WorkspaceConfig workspace)
    {
        RustCompileResult result;
        
        string[] cmd = ["cargo", "check"];
        
        // Similar flags as build but no output generation
        addCommonFlags(cmd, config);
        
        Logger.debugLog("Cargo check: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = "Cargo check failed:\n" ~ res.output;
            return result;
        }
        
        parseCargoOutput(res.output, result);
        
        result.success = true;
        result.outputHash = FastHash.hashString(res.output);
        
        return result;
    }
    
    private RustCompileResult testTarget(in RustConfig config, string projectDir, in WorkspaceConfig workspace)
    {
        RustCompileResult result;
        
        string[] cmd = ["cargo", "test"];
        
        addCommonFlags(cmd, config);
        
        // Add test-specific flags
        if (!config.test.empty)
            cmd ~= [config.test];
        
        cmd ~= config.testFlags;
        
        Logger.debugLog("Cargo test: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = "Tests failed:\n" ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashString(res.output);
        
        return result;
    }
    
    private RustCompileResult buildDoc(in RustConfig config, string projectDir, in WorkspaceConfig workspace)
    {
        RustCompileResult result;
        
        string[] cmd = ["cargo", "doc"];
        
        addCommonFlags(cmd, config);
        
        if (!config.noDefaultFeatures && !config.allFeatures)
            cmd ~= ["--no-deps"];
        
        if (config.docOpen)
            cmd ~= ["--open"];
        
        Logger.debugLog("Cargo doc: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = "Documentation generation failed:\n" ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashString(res.output);
        
        // Documentation is in target/doc
        string docDir = buildPath(projectDir, "target", "doc");
        if (exists(docDir))
            result.outputs ~= [docDir];
        
        return result;
    }
    
    private RustCompileResult benchTarget(in RustConfig config, string projectDir, in WorkspaceConfig workspace)
    {
        RustCompileResult result;
        
        string[] cmd = ["cargo", "bench"];
        
        addCommonFlags(cmd, config);
        
        if (!config.bench.empty)
            cmd ~= [config.bench];
        
        cmd ~= config.benchFlags;
        
        Logger.debugLog("Cargo bench: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = "Benchmarks failed:\n" ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashString(res.output);
        
        return result;
    }
    
    private RustCompileResult buildExample(in RustConfig config, string projectDir, in WorkspaceConfig workspace)
    {
        RustCompileResult result;
        
        string[] cmd = ["cargo", "build"];
        
        if (config.example.empty)
        {
            result.error = "No example specified for example mode";
            return result;
        }
        
        cmd ~= ["--example", config.example];
        addCommonFlags(cmd, config);
        
        Logger.debugLog("Cargo example: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = "Example build failed:\n" ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashString(res.output);
        
        return result;
    }
    
    private RustCompileResult buildCustom(in RustConfig config, string projectDir, in WorkspaceConfig workspace)
    {
        RustCompileResult result;
        result.success = true;
        result.outputHash = FastHash.hashString("custom");
        return result;
    }
    
    private void addCommonFlags(ref string[] cmd, in RustConfig config)
    {
        if (config.release || config.profile == RustProfile.Release)
            cmd ~= ["--release"];
        
        if (!config.target.empty)
            cmd ~= ["--target", config.target];
        
        if (config.allFeatures)
            cmd ~= ["--all-features"];
        else if (config.noDefaultFeatures)
            cmd ~= ["--no-default-features"];
        
        if (!config.features.empty)
            cmd ~= ["--features", config.features.join(",")];
        
        if (!config.package_.empty)
            cmd ~= ["--package", config.package_];
        else if (config.workspace)
            cmd ~= ["--workspace"];
        
        if (config.verbose > 0)
        {
            foreach (i; 0 .. config.verbose)
                cmd ~= ["-v"];
        }
        
        if (config.frozen)
            cmd ~= ["--frozen"];
        else if (config.locked)
            cmd ~= ["--locked"];
        
        if (config.offline)
            cmd ~= ["--offline"];
        
        cmd ~= config.cargoFlags;
    }
    
    private void parseCargoOutput(string output, ref RustCompileResult result)
    {
        foreach (line; output.split("\n"))
        {
            if (line.canFind("warning:"))
            {
                result.hadWarnings = true;
                result.warnings ~= line;
            }
        }
    }
}


