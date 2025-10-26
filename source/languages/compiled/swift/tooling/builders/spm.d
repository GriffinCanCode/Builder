module languages.compiled.swift.tooling.builders.spm;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.swift.core.config;
import languages.compiled.swift.tooling.builders.base;
import languages.compiled.swift.managers.spm;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// Swift Package Manager builder
class SPMBuilder : SwiftBuilder
{
    SwiftBuildResult build(
        string[] sources,
        SwiftConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        SwiftBuildResult result;
        
        // Build command arguments
        string[] args;
        
        // Configuration
        final switch (config.buildConfig)
        {
            case SwiftBuildConfig.Debug:
                args ~= ["-c", "debug"];
                break;
            case SwiftBuildConfig.Release:
                args ~= ["-c", "release"];
                break;
            case SwiftBuildConfig.Custom:
                if (!config.customConfig.empty)
                    args ~= ["-c", config.customConfig];
                break;
        }
        
        // Product or target
        if (!config.product.empty)
            args ~= ["--product", config.product];
        else if (!config.target.empty)
            args ~= ["--target", config.target];
        
        // Build path
        if (!config.buildPath.empty)
            args ~= ["--build-path", config.buildPath];
        
        // Scratch path
        if (!config.scratchPath.empty)
            args ~= ["--scratch-path", config.scratchPath];
        
        // Package path
        if (!config.packagePath.empty)
            args ~= ["--package-path", config.packagePath];
        
        // Parallel jobs
        if (config.jobs > 0)
            args ~= ["--jobs", config.jobs.to!string];
        
        // Verbose
        if (config.verbose)
            args ~= ["--verbose"];
        if (config.veryVerbose)
            args ~= ["-v"];
        
        // Skip update
        if (config.skipUpdate)
            args ~= ["--skip-update"];
        
        // Disable sandbox
        if (config.disableSandbox)
            args ~= ["--disable-sandbox"];
        
        // Disable automatic resolution
        if (config.disableAutomaticResolution)
            args ~= ["--disable-automatic-resolution"];
        
        // Force resolved versions
        if (config.forceResolvedVersions)
            args ~= ["--force-resolved-versions"];
        
        // Static Swift stdlib
        if (config.staticSwiftStdlib)
            args ~= ["--static-swift-stdlib"];
        
        // Arch
        if (!config.arch.empty)
            args ~= ["--arch", config.arch];
        
        // Triple
        if (!config.triple.empty)
            args ~= ["--triple", config.triple];
        
        // SDK
        if (!config.sdk.empty)
            args ~= ["--sdk", config.sdk];
        
        // Add Xc flags (C compiler flags)
        foreach (flag; config.buildSettings.cFlags)
            args ~= ["-Xcc", flag];
        
        // Add Xswiftc flags (Swift compiler flags)
        foreach (flag; config.buildSettings.swiftFlags)
            args ~= ["-Xswiftc", flag];
        
        // Add Xlinker flags
        foreach (flag; config.buildSettings.linkerFlags)
            args ~= ["-Xlinker", flag];
        
        // Add linked libraries
        foreach (lib; config.buildSettings.linkedLibraries)
            args ~= ["-Xlinker", "-l" ~ lib];
        
        // Add linked frameworks
        version(OSX)
        {
            foreach (framework; config.buildSettings.linkedFrameworks)
            {
                args ~= ["-Xlinker", "-framework"];
                args ~= ["-Xlinker", framework];
            }
        }
        
        // Enable library evolution
        if (config.enableLibraryEvolution)
            args ~= ["-Xswiftc", "-enable-library-evolution"];
        
        // Emit module interface
        if (config.emitModuleInterface)
            args ~= ["-Xswiftc", "-emit-module-interface"];
        
        // Sanitizer
        final switch (config.sanitizer)
        {
            case SwiftSanitizer.None:
                break;
            case SwiftSanitizer.Address:
                args ~= ["--sanitize=address"];
                break;
            case SwiftSanitizer.Thread:
                args ~= ["--sanitize=thread"];
                break;
            case SwiftSanitizer.Undefined:
                args ~= ["--sanitize=undefined"];
                break;
        }
        
        // Code coverage
        if (config.coverage == SwiftCoverage.Generate)
            args ~= ["--enable-code-coverage"];
        
        // Testability
        if (config.enableTestability)
            args ~= ["--enable-testability"];
        
        // Run appropriate command based on mode
        auto runner = new SwiftBuildRunner(config.packagePath);
        
        ProcessPipes res;
        final switch (config.mode)
        {
            case SPMBuildMode.Build:
                res = runner.runBuild(args, config.env);
                break;
            case SPMBuildMode.Run:
                // Build first, then run
                res = runner.runBuild(args, config.env);
                if (res.status == 0)
                {
                    auto runRunner = new SwiftRunRunner(config.packagePath);
                    auto runRes = runRunner.run(
                        config.product,
                        [],
                        config.buildConfig == SwiftBuildConfig.Debug ? "debug" : "release",
                        config.env
                    );
                    result.success = runRes.status == 0;
                    if (runRes.status != 0)
                        result.error = "Run failed: " ~ runRes.output;
                }
                break;
            case SPMBuildMode.Test:
                auto testRunner = new SwiftTestRunner(config.packagePath);
                res = testRunner.test(
                    config.testing.filter,
                    config.testing.skip,
                    config.testing.parallel,
                    config.testing.enableCodeCoverage,
                    config.testing.numWorkers,
                    config.env
                );
                
                // Parse test results
                parseTestResults(res.output, result);
                break;
            case SPMBuildMode.Check:
                // Type check only
                args ~= ["--build-tests"];
                res = runner.runBuild(args, config.env);
                break;
            case SPMBuildMode.Clean:
                auto spmRunner = new SPMRunner(config.packagePath);
                res = spmRunner.clean();
                result.success = res.status == 0;
                if (res.status != 0)
                    result.error = "Clean failed: " ~ res.output;
                return result;
            case SPMBuildMode.GenerateXcodeproj:
                version(OSX)
                {
                    auto spmRunner = new SPMRunner(config.packagePath);
                    res = spmRunner.generateXcodeproj();
                    result.success = res.status == 0;
                    if (res.status != 0)
                        result.error = "Xcode project generation failed: " ~ res.output;
                    return result;
                }
                else
                {
                    result.error = "Xcode project generation only supported on macOS";
                    return result;
                }
            case SPMBuildMode.Custom:
                res = runner.runBuild(args, config.env);
                break;
        }
        
        if (res.status != 0)
        {
            result.error = "Swift build failed: " ~ res.output;
            parseWarnings(res.output, result);
            return result;
        }
        
        // Parse warnings
        parseWarnings(res.output, result);
        
        // Get build outputs
        auto outputs = getBuildOutputs(config, workspace);
        result.outputs = outputs;
        
        // Calculate hash
        if (!outputs.empty && exists(outputs[0]))
        {
            result.outputHash = FastHash.hashFile(outputs[0]);
        }
        else
        {
            result.outputHash = FastHash.hashStrings(sources);
        }
        
        result.success = true;
        return result;
    }
    
    bool isAvailable()
    {
        return SPMRunner.isAvailable();
    }
    
    string name() const
    {
        return "swift-package-manager";
    }
    
    string getVersion()
    {
        return SPMRunner.getVersion();
    }
    
    bool supportsFeature(string feature)
    {
        switch (feature)
        {
            case "packages":
            case "dependencies":
            case "cross-compile":
            case "library-evolution":
            case "testing":
                return true;
            default:
                return false;
        }
    }
    
    private string[] getBuildOutputs(SwiftConfig config, WorkspaceConfig workspace)
    {
        string[] outputs;
        
        // Get build path
        string buildPath = config.buildPath;
        if (buildPath.empty)
            buildPath = ".build";
        
        // Determine configuration directory
        string configDir;
        final switch (config.buildConfig)
        {
            case SwiftBuildConfig.Debug:
                configDir = "debug";
                break;
            case SwiftBuildConfig.Release:
                configDir = "release";
                break;
            case SwiftBuildConfig.Custom:
                configDir = config.customConfig.empty ? "debug" : config.customConfig;
                break;
        }
        
        string outputDir = buildPath(buildPath, configDir);
        
        // Find built products
        if (exists(outputDir) && isDir(outputDir))
        {
            // Look for executable or library
            if (config.projectType == SwiftProjectType.Executable)
            {
                string productName = config.product;
                if (productName.empty && !config.target.empty)
                    productName = config.target;
                
                if (!productName.empty)
                {
                    string exePath = buildPath(outputDir, productName);
                    if (exists(exePath))
                        outputs ~= exePath;
                }
            }
            else if (config.projectType == SwiftProjectType.Library)
            {
                // Look for .a, .dylib, .so, or .dll files
                foreach (entry; dirEntries(outputDir, SpanMode.shallow))
                {
                    if (entry.isFile)
                    {
                        string ext = extension(entry.name);
                        if (ext == ".a" || ext == ".dylib" || ext == ".so" || ext == ".dll")
                        {
                            outputs ~= entry.name;
                        }
                    }
                }
            }
        }
        
        return outputs;
    }
    
    private void parseWarnings(string output, ref SwiftBuildResult result)
    {
        foreach (line; output.split("\n`)
        {
            if (line.canFind("warning:`)
            {
                result.warnings ~= line.strip;
            }
        }
    }
    
    private void parseTestResults(string output, ref SwiftBuildResult result)
    {
        result.testsRan = true;
        
        // Parse test output for pass/fail counts
        foreach (line; output.split("\n`)
        {
            // Look for test summary lines
            if (line.canFind("Test Suite") && line.canFind("passed`)
            {
                // Parse counts
                import std.regex;
                auto match = line.matchFirst(regex(`(\d+) tests?.*?(\d+) failures?`);
                if (!match.empty)
                {
                    result.testsPassed = match[1].to!int - match[2].to!int;
                    result.testsFailed = match[2].to!int;
                }
            }
        }
    }
}

