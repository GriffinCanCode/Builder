module languages.compiled.cpp.builders.direct;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.cpp.core.config;
import languages.compiled.cpp.tooling.toolchain;
import languages.compiled.cpp.builders.base;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Direct compiler builder - compiles without external build system
class DirectBuilder : BaseCppBuilder
{
    private CompilerInfo compilerInfo;
    
    this(CppConfig config)
    {
        super(config);
        compilerInfo = Toolchain.detect(config.compiler, config.customCompiler);
    }
    
    override CppCompileResult build(
        in string[] sources,
        in CppConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        CppCompileResult result;
        
        if (!compilerInfo.isAvailable)
        {
            result.error = "Compiler not available: " ~ config.compiler.to!string;
            return result;
        }
        
        Logger.debug_("Direct compilation with " ~ compilerInfo.name);
        
        // Separate C and C++ files
        string[] cppFiles;
        string[] cFiles;
        
        foreach (source; sources)
        {
            string ext = extension(source).toLower;
            if (ext == ".cpp" || ext == ".cxx" || ext == ".cc" || ext == ".C" || ext == ".c++")
                cppFiles ~= source;
            else if (ext == ".c")
                cFiles ~= source;
        }
        
        // Determine output file
        string outputFile = config.output;
        if (outputFile.empty && !target.outputPath.empty)
        {
            outputFile = buildPath(workspace.options.outputDir, target.outputPath);
        }
        else if (outputFile.empty)
        {
            auto name = target.name.split(":")[$ - 1];
            outputFile = buildPath(workspace.options.outputDir, name);
        }
        
        // Ensure output directory exists
        string outputDir = dirName(outputFile);
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Create object directory
        string objDir = config.objDir;
        if (!objDir.isAbsolute)
            objDir = buildPath(workspace.options.outputDir, objDir);
        
        if (!exists(objDir))
            mkdirRecurse(objDir);
        
        // Compile C++ files
        string[] cppObjects;
        if (!cppFiles.empty)
        {
            auto cppResult = compileFiles(cppFiles, config, objDir, true);
            if (!cppResult.success)
            {
                result.error = cppResult.error;
                result.hadWarnings = cppResult.hadWarnings;
                result.warnings = cppResult.warnings;
                return result;
            }
            cppObjects = cppResult.objects;
            result.warnings ~= cppResult.warnings;
            result.hadWarnings = result.hadWarnings || cppResult.hadWarnings;
        }
        
        // Compile C files
        string[] cObjects;
        if (!cFiles.empty)
        {
            auto cResult = compileFiles(cFiles, config, objDir, false);
            if (!cResult.success)
            {
                result.error = cResult.error;
                result.hadWarnings = cResult.hadWarnings || result.hadWarnings;
                result.warnings ~= cResult.warnings;
                return result;
            }
            cObjects = cResult.objects;
            result.warnings ~= cResult.warnings;
            result.hadWarnings = result.hadWarnings || cResult.hadWarnings;
        }
        
        // Combine all objects
        string[] allObjects = cppObjects ~ cObjects;
        result.objects = allObjects;
        
        // Link
        auto linkResult = linkObjects(allObjects, outputFile, config, !cppFiles.empty);
        if (!linkResult.success)
        {
            result.error = linkResult.error;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputFile];
        result.outputHash = FastHash.hashFile(outputFile);
        
        return result;
    }
    
    override bool isAvailable()
    {
        return compilerInfo.isAvailable;
    }
    
    override string name() const
    {
        return "DirectBuilder (" ~ compilerInfo.name ~ ")";
    }
    
    override string getVersion()
    {
        return compilerInfo.version_;
    }
    
    override bool supportsFeature(string feature)
    {
        switch (feature)
        {
            case "compile":
            case "link":
            case "object":
            case "pch":
            case "lto":
            case "sanitizers":
                return true;
            default:
                return super.supportsFeature(feature);
        }
    }
    
    /// Compile source files to object files
    private CppCompileResult compileFiles(
        string[] sources,
        CppConfig config,
        string objDir,
        bool isCpp
    )
    {
        CppCompileResult result;
        result.success = true;
        
        string compiler = isCpp ? 
            Toolchain.getCppCompiler(compilerInfo) :
            Toolchain.getCCompiler(compilerInfo);
        
        auto flags = buildCompilerFlags(config, isCpp);
        
        foreach (source; sources)
        {
            // Generate object file path
            string objFile = buildPath(objDir, baseName(source).stripExtension ~ ".o");
            
            // Build compile command
            string[] cmd = [compiler];
            cmd ~= flags;
            cmd ~= ["-c", source];
            cmd ~= ["-o", objFile];
            
            Logger.debug_("Compiling: " ~ source);
            Logger.debug_("  Command: " ~ cmd.join(" "));
            
            // Execute compilation
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.success = false;
                result.error = "Compilation failed for " ~ source ~ ": " ~ res.output;
                return result;
            }
            
            // Check for warnings
            if (!res.output.empty)
            {
                result.hadWarnings = true;
                result.warnings ~= "In " ~ source ~ ": " ~ res.output;
            }
            
            result.objects ~= objFile;
        }
        
        return result;
    }
    
    /// Link object files to final output
    private CppCompileResult linkObjects(
        string[] objects,
        string outputFile,
        CppConfig config,
        bool isCpp
    )
    {
        CppCompileResult result;
        
        // Use C++ compiler for linking if any C++ code
        string linker = isCpp ?
            Toolchain.getCppCompiler(compilerInfo) :
            Toolchain.getCCompiler(compilerInfo);
        
        // Build link command
        string[] cmd = [linker];
        
        // Output file
        cmd ~= ["-o", outputFile];
        
        // Object files
        cmd ~= objects;
        
        // Linker flags
        cmd ~= buildLinkerFlags(config);
        
        Logger.debug_("Linking: " ~ outputFile);
        Logger.debug_("  Command: " ~ cmd.join(" "));
        
        // Execute linking
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Linking failed: " ~ res.output;
            return result;
        }
        
        // Check for warnings
        if (!res.output.empty)
        {
            result.hadWarnings = true;
            result.warnings ~= "Linker: " ~ res.output;
        }
        
        result.success = true;
        return result;
    }
}

