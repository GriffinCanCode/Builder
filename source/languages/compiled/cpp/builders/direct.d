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
import core.caching.actions.action : ActionCache, ActionCacheConfig, ActionId, ActionType;

/// Direct compiler builder - compiles without external build system with action-level caching
class DirectBuilder : BaseCppBuilder
{
    private CompilerInfo compilerInfo;
    private ActionCache actionCache;
    
    this(CppConfig config, ActionCache cache = null)
    {
        super(config);
        compilerInfo = Toolchain.detect(config.compiler, config.customCompiler);
        if (cache is null)
        {
            auto cacheConfig = ActionCacheConfig.fromEnvironment();
            actionCache = new ActionCache(".builder-cache/actions/cpp", cacheConfig);
        }
        else
        {
            actionCache = cache;
        }
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
        
        Logger.debugLog("Direct compilation with " ~ compilerInfo.name);
        
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
            auto cppResult = compileFiles(cppFiles, config, objDir, true, target);
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
            auto cResult = compileFiles(cFiles, config, objDir, false, target);
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
        auto linkResult = linkObjects(allObjects, outputFile, config, !cppFiles.empty, target);
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
    
    /// Compile source files to object files with action-level caching
    private CppCompileResult compileFiles(
        string[] sources,
        in CppConfig config,
        string objDir,
        bool isCpp,
        in Target target
    )
    {
        CppCompileResult result;
        result.success = true;
        
        string compiler = isCpp ? 
            Toolchain.getCppCompiler(compilerInfo) :
            Toolchain.getCCompiler(compilerInfo);
        
        auto flags = buildCompilerFlags(config, isCpp);
        
        // Build metadata for cache validation
        string[string] metadata;
        metadata["compiler"] = compiler;
        metadata["flags"] = flags.join(" ");
        metadata["isCpp"] = isCpp.to!string;
        
        foreach (source; sources)
        {
            // Generate object file path
            string objFile = buildPath(objDir, baseName(source).stripExtension ~ ".o");
            
            // Create action ID for this compilation
            ActionId actionId;
            actionId.targetId = target.name;
            actionId.type = ActionType.Compile;
            actionId.subId = baseName(source);
            actionId.inputHash = FastHash.hashFile(source);
            
            // Check if this compilation is cached
            if (actionCache.isCached(actionId, [source], metadata) && exists(objFile))
            {
                Logger.debugLog("  [Cached] " ~ source);
                result.objects ~= objFile;
                continue;
            }
            
            // Build compile command
            string[] cmd = [compiler];
            cmd ~= flags;
            cmd ~= ["-c", source];
            cmd ~= ["-o", objFile];
            
            Logger.debugLog("Compiling: " ~ source);
            Logger.debugLog("  Command: " ~ cmd.join(" "));
            
            // Execute compilation
            auto res = execute(cmd);
            
            bool success = (res.status == 0);
            
            if (!success)
            {
                result.success = false;
                result.error = "Compilation failed for " ~ source ~ ": " ~ res.output;
                
                // Update cache with failure
                actionCache.update(
                    actionId,
                    [source],
                    [],
                    metadata,
                    false
                );
                
                return result;
            }
            
            // Check for warnings
            if (!res.output.empty)
            {
                result.hadWarnings = true;
                result.warnings ~= "In " ~ source ~ ": " ~ res.output;
            }
            
            // Update cache with success
            actionCache.update(
                actionId,
                [source],
                [objFile],
                metadata,
                true
            );
            
            result.objects ~= objFile;
        }
        
        return result;
    }
    
    /// Link object files to final output with action-level caching
    private CppCompileResult linkObjects(
        string[] objects,
        string outputFile,
        in CppConfig config,
        bool isCpp,
        in Target target
    )
    {
        CppCompileResult result;
        
        // Use C++ compiler for linking if any C++ code
        string linker = isCpp ?
            Toolchain.getCppCompiler(compilerInfo) :
            Toolchain.getCCompiler(compilerInfo);
        
        // Build linker flags
        auto linkerFlags = buildLinkerFlags(config);
        
        // Build metadata for cache validation
        string[string] metadata;
        metadata["linker"] = linker;
        metadata["linkerFlags"] = linkerFlags.join(" ");
        metadata["isCpp"] = isCpp.to!string;
        
        // Create action ID for linking
        ActionId actionId;
        actionId.targetId = target.name;
        actionId.type = ActionType.Link;
        actionId.subId = baseName(outputFile);
        // Hash all object files together for input hash
        actionId.inputHash = FastHash.hashStrings(objects);
        
        // Check if linking is cached
        if (actionCache.isCached(actionId, objects, metadata) && exists(outputFile))
        {
            Logger.debugLog("  [Cached] Linking: " ~ outputFile);
            result.success = true;
            return result;
        }
        
        // Build link command
        string[] cmd = [linker];
        
        // Output file
        cmd ~= ["-o", outputFile];
        
        // Object files
        cmd ~= objects;
        
        // Linker flags
        cmd ~= linkerFlags;
        
        Logger.debugLog("Linking: " ~ outputFile);
        Logger.debugLog("  Command: " ~ cmd.join(" "));
        
        // Execute linking
        auto res = execute(cmd);
        
        bool success = (res.status == 0);
        
        if (!success)
        {
            result.error = "Linking failed: " ~ res.output;
            
            // Update cache with failure
            actionCache.update(
                actionId,
                objects,
                [],
                metadata,
                false
            );
            
            return result;
        }
        
        // Check for warnings
        if (!res.output.empty)
        {
            result.hadWarnings = true;
            result.warnings ~= "Linker: " ~ res.output;
        }
        
        // Update cache with success
        actionCache.update(
            actionId,
            objects,
            [outputFile],
            metadata,
            true
        );
        
        result.success = true;
        return result;
    }
}

