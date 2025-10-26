module languages.compiled.swift.tooling.builders.swiftc;

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
import languages.compiled.swift.managers.toolchain;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// Direct swiftc compiler builder
class SwiftcBuilder : SwiftBuilder
{
    SwiftBuildResult build(
        string[] sources,
        SwiftConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        SwiftBuildResult result;
        
        // Get output path
        auto outputs = getOutputPath(config, target, workspace);
        auto outputPath = outputs[0];
        auto outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build command
        string[] cmd = [config.swiftcPath.empty ? "swiftc" : config.swiftcPath];
        
        // Output
        cmd ~= ["-o", outputPath];
        
        // Configuration-specific flags
        final switch (config.buildConfig)
        {
            case SwiftBuildConfig.Debug:
                cmd ~= ["-g"];
                break;
            case SwiftBuildConfig.Release:
                // Add optimization
                final switch (config.optimization)
                {
                    case SwiftOptimization.None:
                        cmd ~= ["-Onone"];
                        break;
                    case SwiftOptimization.Speed:
                        cmd ~= ["-O"];
                        break;
                    case SwiftOptimization.Size:
                        cmd ~= ["-Osize"];
                        break;
                    case SwiftOptimization.Unchecked:
                        cmd ~= ["-Ounchecked"];
                        break;
                }
                break;
            case SwiftBuildConfig.Custom:
                // Custom flags from config
                break;
        }
        
        // Project type specific flags
        final switch (config.projectType)
        {
            case SwiftProjectType.Executable:
                // Default behavior
                break;
            case SwiftProjectType.Library:
                // Emit library
                if (config.libraryType == SwiftLibraryType.Static)
                    cmd ~= ["-emit-library", "-static"];
                else if (config.libraryType == SwiftLibraryType.Dynamic)
                    cmd ~= ["-emit-library"];
                else
                    cmd ~= ["-emit-library"]; // Auto
                break;
            case SwiftProjectType.SystemModule:
                cmd ~= ["-emit-module"];
                break;
            case SwiftProjectType.Test:
                cmd ~= ["-enable-testing"];
                break;
            case SwiftProjectType.Macro:
                version(none) // Requires Swift 5.9+
                {
                    cmd ~= ["-load-plugin-library"];
                }
                break;
            case SwiftProjectType.Plugin:
                cmd ~= ["-emit-module"];
                break;
        }
        
        // Swift language version
        string langVersion = getLanguageVersionString(config.languageVersion);
        if (!langVersion.empty)
            cmd ~= ["-swift-version", langVersion];
        
        // Target triple
        if (!config.triple.empty)
            cmd ~= ["-target", config.triple];
        
        // SDK
        if (!config.sdk.empty)
            cmd ~= ["-sdk", config.sdk];
        
        // Module name
        if (!config.product.empty)
            cmd ~= ["-module-name", config.product];
        
        // Enable library evolution
        if (config.enableLibraryEvolution)
            cmd ~= ["-enable-library-evolution"];
        
        // Emit module interface
        if (config.emitModuleInterface)
            cmd ~= ["-emit-module-interface"];
        
        // Whole module optimization
        if (config.wholeModuleOptimization)
            cmd ~= ["-whole-module-optimization"];
        
        // Incremental compilation
        if (config.incrementalCompilation)
            cmd ~= ["-incremental"];
        
        // Enable batch mode
        if (config.batchMode)
            cmd ~= ["-enable-batch-mode"];
        
        // Number of threads
        if (config.jobs > 0)
            cmd ~= ["-num-threads", config.jobs.to!string];
        
        // Index while building
        if (config.indexWhileBuilding)
            cmd ~= ["-index-store-path", buildPath(outputDir, "index")];
        
        // Debug info
        if (config.debugInfo)
            cmd ~= ["-g"];
        
        // Testability
        if (config.enableTestability)
            cmd ~= ["-enable-testing"];
        
        // Sanitizers
        final switch (config.sanitizer)
        {
            case SwiftSanitizer.None:
                break;
            case SwiftSanitizer.Address:
                cmd ~= ["-sanitize=address"];
                break;
            case SwiftSanitizer.Thread:
                cmd ~= ["-sanitize=thread"];
                break;
            case SwiftSanitizer.Undefined:
                cmd ~= ["-sanitize=undefined"];
                break;
        }
        
        // Framework paths
        version(OSX)
        {
            foreach (framework; config.buildSettings.linkedFrameworks)
            {
                cmd ~= ["-framework", framework];
            }
        }
        
        // Linked libraries
        foreach (lib; config.buildSettings.linkedLibraries)
        {
            cmd ~= ["-l" ~ lib];
        }
        
        // Linker flags
        foreach (flag; config.buildSettings.linkerFlags)
        {
            cmd ~= ["-Xlinker", flag];
        }
        
        // Custom Swift flags
        cmd ~= config.buildSettings.swiftFlags;
        
        // Defines
        foreach (define; config.buildSettings.defines)
        {
            cmd ~= ["-D", define];
        }
        
        // Import paths
        foreach (path; config.buildSettings.headerSearchPaths)
        {
            cmd ~= ["-I", path];
        }
        
        // Add sources
        cmd ~= sources;
        
        // Run compiler
        Logger.debug_("Running: " ~ cmd.join(" `);
        
        auto res = execute(cmd, config.env);
        
        if (res.status != 0)
        {
            result.error = "swiftc failed: " ~ res.output;
            parseWarnings(res.output, result);
            return result;
        }
        
        // Parse warnings
        parseWarnings(res.output, result);
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    bool isAvailable()
    {
        return SwiftCompilerRunner.isAvailable();
    }
    
    string name() const
    {
        return "swiftc";
    }
    
    string getVersion()
    {
        return SwiftCompilerRunner.getVersion();
    }
    
    bool supportsFeature(string feature)
    {
        switch (feature)
        {
            case "compile":
            case "simple-projects":
                return true;
            default:
                return false;
        }
    }
    
    private string[] getOutputPath(SwiftConfig config, Target target, WorkspaceConfig workspace)
    {
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(workspace.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Adjust extension based on platform and library type
            version(OSX)
            {
                if (config.projectType == SwiftProjectType.Library)
                {
                    if (config.libraryType == SwiftLibraryType.Static)
                        outputs ~= buildPath(workspace.options.outputDir, "lib" ~ name ~ ".a");
                    else
                        outputs ~= buildPath(workspace.options.outputDir, "lib" ~ name ~ ".dylib");
                }
                else
                {
                    outputs ~= buildPath(workspace.options.outputDir, name);
                }
            }
            else version(linux)
            {
                if (config.projectType == SwiftProjectType.Library)
                {
                    if (config.libraryType == SwiftLibraryType.Static)
                        outputs ~= buildPath(workspace.options.outputDir, "lib" ~ name ~ ".a");
                    else
                        outputs ~= buildPath(workspace.options.outputDir, "lib" ~ name ~ ".so");
                }
                else
                {
                    outputs ~= buildPath(workspace.options.outputDir, name);
                }
            }
            else version(Windows)
            {
                if (config.projectType == SwiftProjectType.Library)
                {
                    if (config.libraryType == SwiftLibraryType.Static)
                        outputs ~= buildPath(workspace.options.outputDir, name ~ ".lib");
                    else
                        outputs ~= buildPath(workspace.options.outputDir, name ~ ".dll");
                }
                else
                {
                    outputs ~= buildPath(workspace.options.outputDir, name ~ ".exe");
                }
            }
            else
            {
                outputs ~= buildPath(workspace.options.outputDir, name);
            }
        }
        
        return outputs;
    }
    
    private string getLanguageVersionString(SwiftLanguageVersion version_)
    {
        final switch (version_)
        {
            case SwiftLanguageVersion.Swift4: return "4";
            case SwiftLanguageVersion.Swift4_2: return "4.2";
            case SwiftLanguageVersion.Swift5: return "5";
            case SwiftLanguageVersion.Swift5_1: return "5.1";
            case SwiftLanguageVersion.Swift5_2: return "5.2";
            case SwiftLanguageVersion.Swift5_3: return "5.3";
            case SwiftLanguageVersion.Swift5_4: return "5.4";
            case SwiftLanguageVersion.Swift5_5: return "5.5";
            case SwiftLanguageVersion.Swift5_6: return "5.6";
            case SwiftLanguageVersion.Swift5_7: return "5.7";
            case SwiftLanguageVersion.Swift5_8: return "5.8";
            case SwiftLanguageVersion.Swift5_9: return "5.9";
            case SwiftLanguageVersion.Swift5_10: return "5.10";
            case SwiftLanguageVersion.Swift6: return "6";
        }
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
}

