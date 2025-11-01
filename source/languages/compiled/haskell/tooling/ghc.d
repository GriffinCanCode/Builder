module languages.compiled.haskell.tooling.ghc;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.haskell.core.config;
import config.schema.schema;
import utils.logging.logger;

/// GHC compiler wrapper
struct GHCWrapper
{
    /// Check if GHC is available
    static bool isAvailable() nothrow
    {
        try
        {
            auto result = execute(["ghc", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Get GHC version
    static string getVersion()
    {
        try
        {
            auto result = execute(["ghc", "--version"]);
            if (result.status == 0)
            {
                // Output format: "The Glorious Glasgow Haskell Compilation System, version X.Y.Z"
                auto lines = result.output.strip;
                auto parts = lines.split(",");
                if (parts.length >= 2)
                {
                    return parts[$ - 1].strip.replace("version ", "");
                }
                return lines;
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to get GHC version: " ~ e.msg);
        }
        return "unknown";
    }
    
    /// Check if HLint is available
    static bool isHLintAvailable() nothrow
    {
        try
        {
            auto result = execute(["hlint", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Check if Ormolu is available
    static bool isOroluAvailable() nothrow
    {
        try
        {
            auto result = execute(["ormolu", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Check if Fourmolu is available
    static bool isFourmoluAvailable() nothrow
    {
        try
        {
            auto result = execute(["fourmolu", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Compile with GHC
    static LanguageBuildResult compile(
        in Target target,
        in WorkspaceConfig config,
        const HaskellConfig hsConfig
    )
    {
        LanguageBuildResult result;
        
        if (!isAvailable())
        {
            result.error = "GHC not found";
            return result;
        }
        
        string[] args = ["ghc"];
        
        // Optimization level
        final switch (hsConfig.optLevel)
        {
            case GHCOptLevel.O0: args ~= "-O0"; break;
            case GHCOptLevel.O1: args ~= "-O1"; break;
            case GHCOptLevel.O2: args ~= "-O2"; break;
        }
        
        // Language standard
        final switch (hsConfig.standard)
        {
            case HaskellStandard.Haskell98: args ~= "-XHaskell98"; break;
            case HaskellStandard.Haskell2010: args ~= "-XHaskell2010"; break;
        }
        
        // Language extensions
        foreach (ext; hsConfig.extensions)
        {
            args ~= "-X" ~ ext;
        }
        
        // Warnings
        if (hsConfig.warnings)
        {
            args ~= "-Wall";
        }
        if (hsConfig.werror)
        {
            args ~= "-Werror";
        }
        
        // Profiling
        if (hsConfig.profiling)
        {
            args ~= "-prof";
            args ~= "-fprof-auto";
        }
        
        // Threaded runtime
        if (hsConfig.threaded)
        {
            args ~= "-threaded";
        }
        
        // Static linking
        if (hsConfig.static_)
        {
            args ~= "-static";
        }
        
        // Dynamic linking
        if (hsConfig.dynamic)
        {
            args ~= "-dynamic";
        }
        
        // Include directories
        foreach (dir; hsConfig.includeDirs)
        {
            args ~= "-i" ~ dir;
        }
        
        // Library directories
        foreach (dir; hsConfig.libDirs)
        {
            args ~= "-L" ~ dir;
        }
        
        // Packages
        foreach (pkg; hsConfig.packages)
        {
            args ~= "-package";
            args ~= pkg;
        }
        
        // GHC options
        args ~= hsConfig.ghcOptions;
        
        // Custom flags
        args ~= hsConfig.customFlags;
        
        // Output directory
        string outputDir = hsConfig.outputDir.empty ? config.options.outputDir : hsConfig.outputDir;
        if (!exists(outputDir))
        {
            mkdirRecurse(outputDir);
        }
        
        // Output path
        string outputName = target.name.split(":")[$ - 1];
        string outputPath = buildPath(outputDir, outputName);
        args ~= "-o";
        args ~= outputPath;
        
        // Mode-specific options
        final switch (hsConfig.mode)
        {
            case HaskellBuildMode.Compile:
                // Default executable compilation
                break;
            case HaskellBuildMode.Library:
                // For libraries, we'd typically use Cabal
                Logger.warning("Library compilation with GHC directly is limited. Consider using Cabal.");
                break;
            case HaskellBuildMode.Test:
                // Tests are usually managed by Cabal/Stack
                break;
            case HaskellBuildMode.Doc:
                result.error = "Documentation generation requires Cabal or Haddock";
                return result;
            case HaskellBuildMode.REPL:
                result.error = "REPL mode not supported in build";
                return result;
            case HaskellBuildMode.Custom:
                break;
        }
        
        // Add source files
        string mainFile = hsConfig.entry.empty ? "" : hsConfig.entry;
        if (mainFile.empty && !target.sources.empty)
        {
            // Find main file
            foreach (src; target.sources)
            {
                if (extension(src) == ".hs")
                {
                    mainFile = src;
                    break;
                }
            }
        }
        
        if (mainFile.empty)
        {
            result.error = "No Haskell source file specified";
            return result;
        }
        
        args ~= mainFile;
        
        // Execute compilation
        Logger.debugLog("Running: " ~ args.join(" "));
        
        try
        {
            auto execResult = execute(args, null, Config.none, size_t.max, config.root);
            
            if (execResult.status == 0)
            {
                result.success = true;
                result.outputs = [outputPath];
                
                // Hash the output
                if (exists(outputPath))
                {
                    import utils.files.hash : FastHash;
                    result.outputHash = FastHash.hashFile(outputPath);
                }
                
                if (!execResult.output.empty)
                {
                    Logger.debugLog("GHC output: " ~ execResult.output);
                }
            }
            else
            {
                result.error = execResult.output;
                Logger.error("GHC compilation failed:");
                Logger.error(execResult.output);
            }
        }
        catch (Exception e)
        {
            result.error = "GHC execution failed: " ~ e.msg;
            Logger.error(result.error);
        }
        
        return result;
    }
    
    /// Run HLint on sources
    static HaskellCompileResult runHLint(in string[] sources)
    {
        HaskellCompileResult result;
        result.success = true;
        
        if (!isHLintAvailable())
        {
            return result;
        }
        
        string[] args = ["hlint"] ~ sources.dup;
        
        try
        {
            auto execResult = execute(args);
            
            if (execResult.status != 0 && !execResult.output.empty)
            {
                // HLint found suggestions
                result.hadHLintIssues = true;
                result.hlintIssues = execResult.output.lineSplitter.array;
            }
        }
        catch (Exception e)
        {
            Logger.warning("HLint execution failed: " ~ e.msg);
        }
        
        return result;
    }
    
    /// Run Ormolu formatter
    static void runOrmolu(in string[] sources)
    {
        if (!isOroluAvailable())
        {
            Logger.warning("Ormolu not available");
            return;
        }
        
        foreach (source; sources)
        {
            string[] args = ["ormolu", "--mode", "inplace", source];
            
            try
            {
                auto execResult = execute(args);
                if (execResult.status == 0)
                {
                    Logger.debugLog("Formatted: " ~ source);
                }
                else
                {
                    Logger.warning("Ormolu failed for " ~ source ~ ": " ~ execResult.output);
                }
            }
            catch (Exception e)
            {
                Logger.warning("Ormolu execution failed: " ~ e.msg);
            }
        }
    }
    
    /// Run Fourmolu formatter
    static void runFourmolu(in string[] sources)
    {
        if (!isFourmoluAvailable())
        {
            Logger.warning("Fourmolu not available");
            return;
        }
        
        foreach (source; sources)
        {
            string[] args = ["fourmolu", "--mode", "inplace", source];
            
            try
            {
                auto execResult = execute(args);
                if (execResult.status == 0)
                {
                    Logger.debugLog("Formatted: " ~ source);
                }
                else
                {
                    Logger.warning("Fourmolu failed for " ~ source ~ ": " ~ execResult.output);
                }
            }
            catch (Exception e)
            {
                Logger.warning("Fourmolu execution failed: " ~ e.msg);
            }
        }
    }
}

