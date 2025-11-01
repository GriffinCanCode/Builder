module languages.compiled.haskell.tooling.stack;

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

/// Stack build tool wrapper
struct StackWrapper
{
    /// Check if Stack is available
    static bool isAvailable() nothrow
    {
        try
        {
            auto result = execute(["stack", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Get Stack version
    static string getVersion()
    {
        try
        {
            auto result = execute(["stack", "--version"]);
            if (result.status == 0)
            {
                // Output format: "Version X.Y.Z, Git revision ..."
                auto lines = result.output.lineSplitter.front;
                auto parts = lines.split(",");
                if (parts.length >= 1)
                {
                    return parts[0].replace("Version ", "").strip;
                }
                return lines;
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to get Stack version: " ~ e.msg);
        }
        return "unknown";
    }
    
    /// Build with Stack
    static LanguageBuildResult build(
        in Target target,
        in WorkspaceConfig config,
        const HaskellConfig hsConfig
    )
    {
        LanguageBuildResult result;
        
        if (!isAvailable())
        {
            result.error = "Stack not found";
            return result;
        }
        
        // Ensure we have a stack.yaml
        string stackFile = hsConfig.stackFile.empty ? 
                          buildPath(config.root, "stack.yaml") : 
                          hsConfig.stackFile;
        
        if (!exists(stackFile))
        {
            result.error = "No stack.yaml found. Run 'stack init' to create one.";
            return result;
        }
        
        Logger.debugLog("Using Stack file: " ~ stackFile);
        
        // Build command based on mode
        string[] args = ["stack"];
        
        final switch (hsConfig.mode)
        {
            case HaskellBuildMode.Compile:
            case HaskellBuildMode.Library:
                args ~= "build";
                break;
            case HaskellBuildMode.Test:
                args ~= "test";
                break;
            case HaskellBuildMode.Doc:
                args ~= "haddock";
                break;
            case HaskellBuildMode.REPL:
                result.error = "REPL mode not supported in build";
                return result;
            case HaskellBuildMode.Custom:
                args ~= "build";
                break;
        }
        
        // Resolver (LTS version)
        if (!hsConfig.resolver.empty)
        {
            args ~= "--resolver";
            args ~= hsConfig.resolver;
        }
        
        // Parallel jobs
        if (hsConfig.parallel && hsConfig.jobs > 0)
        {
            args ~= "--jobs";
            args ~= hsConfig.jobs.to!string;
        }
        
        // GHC options
        if (!hsConfig.ghcOptions.empty)
        {
            args ~= "--ghc-options";
            args ~= hsConfig.ghcOptions.join(" ");
        }
        
        // Test options (for test mode)
        if (hsConfig.mode == HaskellBuildMode.Test)
        {
            args ~= hsConfig.testOptions;
        }
        
        // Execute build
        Logger.debugLog("Running: " ~ args.join(" "));
        
        try
        {
            auto execResult = execute(args, null, Config.none, size_t.max, config.root);
            
            if (execResult.status == 0)
            {
                result.success = true;
                
                // Find output executables
                string stackWorkDir = buildPath(config.root, ".stack-work");
                if (exists(stackWorkDir))
                {
                    result.outputs = findBuiltExecutables(stackWorkDir);
                }
                
                if (!execResult.output.empty)
                {
                    Logger.debugLog("Stack output: " ~ execResult.output);
                }
            }
            else
            {
                result.error = execResult.output;
                Logger.error("Stack build failed:");
                Logger.error(execResult.output);
            }
        }
        catch (Exception e)
        {
            result.error = "Stack execution failed: " ~ e.msg;
            Logger.error(result.error);
        }
        
        return result;
    }
    
    /// Find built executables in .stack-work directory
    private static string[] findBuiltExecutables(string stackWorkDir)
    {
        string[] executables;
        
        try
        {
            // Look in .stack-work/dist/*/build/*/
            foreach (entry; dirEntries(stackWorkDir, SpanMode.depth))
            {
                if (entry.isFile)
                {
                    // Check if file is executable (has execute permissions)
                    version (Posix)
                    {
                        import core.sys.posix.sys.stat;
                        stat_t statbuf;
                        if (stat(entry.name.toStringz, &statbuf) == 0)
                        {
                            if ((statbuf.st_mode & S_IXUSR) != 0)
                            {
                                executables ~= entry.name;
                            }
                        }
                    }
                    else
                    {
                        // On Windows, check for .exe extension
                        if (extension(entry.name) == ".exe")
                        {
                            executables ~= entry.name;
                        }
                    }
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to find executables: " ~ e.msg);
        }
        
        return executables;
    }
}

