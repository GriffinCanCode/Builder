module languages.compiled.cpp.builders.cmake;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.cpp.config;
import languages.compiled.cpp.toolchain;
import languages.compiled.cpp.builders.base;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// CMake-based builder
class CMakeBuilder : BaseCppBuilder
{
    this(CppConfig config)
    {
        super(config);
    }
    
    override CppCompileResult build(
        string[] sources,
        CppConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        CppCompileResult result;
        
        if (!isAvailable())
        {
            result.error = "CMake is not available";
            return result;
        }
        
        Logger.debug_("Building with CMake");
        
        // Find CMakeLists.txt
        string cmakeFile = findCMakeFile(sources);
        if (cmakeFile.empty)
        {
            result.error = "CMakeLists.txt not found";
            return result;
        }
        
        string projectDir = dirName(cmakeFile);
        string buildDir = buildPath(projectDir, "build");
        
        // Create build directory
        if (!exists(buildDir))
            mkdirRecurse(buildDir);
        
        // Configure
        auto configResult = configureCMake(projectDir, buildDir, config);
        if (!configResult.success)
        {
            result.error = "CMake configuration failed: " ~ configResult.error;
            return result;
        }
        
        // Build
        auto buildResult = buildCMake(buildDir, config);
        if (!buildResult.success)
        {
            result.error = "CMake build failed: " ~ buildResult.error;
            return result;
        }
        
        // Find output files
        string outputFile = findCMakeOutput(buildDir, target, workspace);
        if (outputFile.empty || !exists(outputFile))
        {
            result.error = "CMake output file not found";
            return result;
        }
        
        result.success = true;
        result.outputs = [outputFile];
        result.outputHash = FastHash.hashFile(outputFile);
        result.warnings = buildResult.warnings;
        result.hadWarnings = buildResult.hadWarnings;
        
        // Handle compile_commands.json
        if (config.compileCommands)
        {
            string compileCommandsPath = buildPath(buildDir, "compile_commands.json");
            if (exists(compileCommandsPath))
            {
                result.compileCommands = compileCommandsPath;
            }
        }
        
        return result;
    }
    
    override bool isAvailable()
    {
        return Toolchain.isAvailable("cmake");
    }
    
    override string name() const
    {
        return "CMake";
    }
    
    override string getVersion()
    {
        auto res = execute(["cmake", "--version"]);
        if (res.status == 0)
        {
            auto lines = res.output.split("\n");
            if (!lines.empty)
                return lines[0].strip;
        }
        return "unknown";
    }
    
    override bool supportsFeature(string feature)
    {
        switch (feature)
        {
            case "compile":
            case "link":
            case "configure":
            case "generators":
            case "compile_commands":
                return true;
            default:
                return super.supportsFeature(feature);
        }
    }
    
    private string findCMakeFile(string[] sources)
    {
        if (sources.empty)
            return "";
        
        string dir = dirName(sources[0]);
        
        // Search upwards for CMakeLists.txt
        while (dir != "/" && dir.length > 1)
        {
            string cmakePath = buildPath(dir, "CMakeLists.txt");
            if (exists(cmakePath))
                return cmakePath;
            
            dir = dirName(dir);
        }
        
        return "";
    }
    
    private CppCompileResult configureCMake(string projectDir, string buildDir, CppConfig config)
    {
        CppCompileResult result;
        
        string[] cmd = ["cmake", "-S", projectDir, "-B", buildDir];
        
        // Generator
        if (!config.cmakeGenerator.empty)
        {
            cmd ~= ["-G", config.cmakeGenerator];
        }
        
        // Build type
        string buildType = config.cmakeBuildType;
        if (buildType.empty)
        {
            buildType = config.debugInfo ? "Debug" : "Release";
        }
        cmd ~= ["-DCMAKE_BUILD_TYPE=" ~ buildType];
        
        // Export compile commands
        if (config.compileCommands)
        {
            cmd ~= "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON";
        }
        
        // Compiler
        auto compilerInfo = Toolchain.detect(config.compiler, config.customCompiler);
        if (compilerInfo.isAvailable)
        {
            string cppCompiler = Toolchain.getCppCompiler(compilerInfo);
            string cCompiler = Toolchain.getCCompiler(compilerInfo);
            cmd ~= ["-DCMAKE_CXX_COMPILER=" ~ cppCompiler];
            cmd ~= ["-DCMAKE_C_COMPILER=" ~ cCompiler];
        }
        
        // Custom options
        cmd ~= config.cmakeOptions;
        
        Logger.debug_("Configuring CMake: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = res.output;
            return result;
        }
        
        result.success = true;
        return result;
    }
    
    private CppCompileResult buildCMake(string buildDir, CppConfig config)
    {
        CppCompileResult result;
        
        string[] cmd = ["cmake", "--build", buildDir];
        
        // Parallel jobs
        if (config.jobs > 0)
        {
            cmd ~= ["-j", config.jobs.to!string];
        }
        
        // Verbose
        if (config.verbose)
        {
            cmd ~= ["--verbose"];
        }
        
        Logger.info("Building with CMake...");
        Logger.debug_("Command: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = res.output;
            return result;
        }
        
        // Parse warnings from output
        foreach (line; res.output.split("\n"))
        {
            if (line.canFind("warning:") || line.canFind("Warning:"))
            {
                result.hadWarnings = true;
                result.warnings ~= line;
            }
        }
        
        result.success = true;
        return result;
    }
    
    private string findCMakeOutput(string buildDir, Target target, WorkspaceConfig workspace)
    {
        // CMake typically outputs to build/ or build/Release/ or build/Debug/
        string[] searchDirs = [
            buildDir,
            buildPath(buildDir, "Release"),
            buildPath(buildDir, "Debug"),
            buildPath(buildDir, "bin"),
            buildPath(buildDir, "lib")
        ];
        
        string targetName = target.name.split(":")[$ - 1];
        
        foreach (dir; searchDirs)
        {
            if (!exists(dir))
                continue;
            
            foreach (entry; dirEntries(dir, SpanMode.shallow))
            {
                if (entry.isFile && baseName(entry.name).canFind(targetName))
                {
                    return entry.name;
                }
            }
        }
        
        return "";
    }
}

