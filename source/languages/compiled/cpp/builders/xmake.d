module languages.compiled.cpp.builders.xmake;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.cpp.core.config;
// import toolchain; // Replaced by unified toolchain system
import infrastructure.toolchain.spec;
import languages.compiled.cpp.builders.base;
import infrastructure.config.schema.schema;
import infrastructure.analysis.targets.types;
import infrastructure.utils.files.hash;
import infrastructure.utils.logging.logger;

/// Xmake build system builder
class XmakeBuilder : BaseCppBuilder
{
    this(CppConfig config)
    {
        super(config);
    }
    
    override CppCompileResult build(
        in string[] sources,
        in CppConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        CppCompileResult result;
        
        if (!isAvailable())
        {
            result.error = "Xmake is not available. Install from https://xmake.io/";
            return result;
        }
        
        Logger.info("Building with Xmake");
        
        // Find xmake.lua
        string xmakeFile = findXmakeFile(workspace.root);
        if (xmakeFile.empty)
        {
            result.error = "No xmake.lua file found";
            return result;
        }
        
        string projectDir = dirName(xmakeFile);
        
        // Configure if needed
        if (!exists(buildPath(projectDir, ".xmake")))
        {
            auto configResult = configureXmake(projectDir, config);
            if (!configResult.success)
            {
                result.error = "Xmake config failed: " ~ configResult.error;
                return result;
            }
        }
        
        // Build
        auto buildResult = buildXmake(projectDir, target);
        if (!buildResult.success)
        {
            result.error = "Xmake build failed: " ~ buildResult.error;
            return result;
        }
        
        // Find output files
        string outputPath = findXmakeOutput(projectDir, target, workspace);
        if (!outputPath.empty && exists(outputPath))
        {
            result.outputs ~= outputPath;
            result.outputHash = FastHash.hashFile(outputPath);
        }
        
        result.success = true;
        
        Logger.info("Xmake build completed successfully");
        
        return result;
    }
    
    override bool isAvailable()
    {
        return Toolchain.isAvailable("xmake");
    }
    
    override string name() const
    {
        return "Xmake";
    }
    
    override string getVersion()
    {
        auto res = execute(["xmake", "--version"]);
        if (res.status == 0)
        {
            auto lines = res.output.split("\n");
            if (lines.length > 0)
                return lines[0].strip;
        }
        return "unknown";
    }
    
    override bool supportsFeature(string feature)
    {
        switch (feature)
        {
            case "pch":
            case "lto":
            case "sanitizers":
                return true;
            default:
                return false;
        }
    }
    
    private string findXmakeFile(string startDir)
    {
        string candidate = buildPath(startDir, "xmake.lua");
        return exists(candidate) ? candidate : "";
    }
    
    private CppCompileResult configureXmake(string projectDir, in CppConfig config)
    {
        CppCompileResult result;
        
        Logger.debugLog("Configuring Xmake");
        
        string[] cmd = ["xmake", "config"];
        
        // Add mode
        if (config.debugInfo)
            cmd ~= ["-m", "debug"];
        else if (config.optLevel == OptLevel.O3)
            cmd ~= ["-m", "release"];
        
        // Add compiler if specified
        if (config.compiler != Compiler.Auto)
        {
            string toolchain;
            final switch (config.compiler)
            {
                case Compiler.GCC:
                    toolchain = "gcc";
                    break;
                case Compiler.Clang:
                    toolchain = "clang";
                    break;
                case Compiler.MSVC:
                    toolchain = "msvc";
                    break;
                case Compiler.Intel:
                    toolchain = "icc";
                    break;
                case Compiler.Auto:
                case Compiler.Custom:
                    toolchain = "";
                    break;
            }
            
            if (!toolchain.empty)
                cmd ~= ["--toolchain=" ~ toolchain];
        }
        
        Logger.debugLog("Running: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = res.output;
            return result;
        }
        
        result.success = true;
        return result;
    }
    
    private CppCompileResult buildXmake(string projectDir, in Target target)
    {
        CppCompileResult result;
        
        Logger.debugLog("Building with Xmake");
        
        string[] cmd = ["xmake", "build"];
        
        // Add target name if specified
        string name = target.name.split(":")[$ - 1];
        if (!name.empty)
            cmd ~= [name];
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = res.output;
            return result;
        }
        
        result.success = true;
        return result;
    }
    
    private string findXmakeOutput(string projectDir, in Target target, in WorkspaceConfig workspace)
    {
        // Xmake typically puts outputs in build/<os>/<arch>/<mode>/
        string buildDir = buildPath(projectDir, "build");
        if (!exists(buildDir))
            return "";
        
        string name = target.name.split(":")[$ - 1];
        
        import std.file : dirEntries, SpanMode;
        
        // Search recursively for the output
        try
        {
            foreach (entry; dirEntries(buildDir, SpanMode.depth))
            {
                if (entry.isFile)
                {
                    string baseName = entry.name.baseName;
                    if (baseName == name || 
                        baseName == "lib" ~ name ~ ".a" ||
                        baseName == "lib" ~ name ~ ".so" ||
                        baseName == name ~ ".exe")
                    {
                        return entry.name;
                    }
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Error searching for xmake output: " ~ e.msg);
        }
        
        return "";
    }
}

