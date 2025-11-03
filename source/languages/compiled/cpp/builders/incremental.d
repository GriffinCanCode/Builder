module languages.compiled.cpp.builders.incremental;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.process;
import std.string;
import languages.compiled.cpp.core.config;
import languages.compiled.cpp.tooling.toolchain;
import languages.compiled.cpp.builders.base;
import languages.compiled.cpp.analysis.incremental;
import config.schema.schema;
import analysis.targets.types;
import compilation.incremental.engine;
import caching.incremental.dependency;
import caching.actions.action;
import utils.files.hash;
import utils.logging.logger;
import errors;

/// Incremental C++ builder with module-level dependency tracking
/// Only recompiles files affected by header changes
class IncrementalCppBuilder : BaseCppBuilder
{
    private CompilerInfo compilerInfo;
    private ActionCache actionCache;
    private DependencyCache depCache;
    private IncrementalEngine incEngine;
    private CppDependencyAnalyzer analyzer;
    
    this(CppConfig config, ActionCache actionCache = null, DependencyCache depCache = null)
    {
        super(config);
        compilerInfo = Toolchain.detect(config.compiler, config.customCompiler);
        
        // Initialize caches
        if (actionCache is null)
        {
            auto cacheConfig = ActionCacheConfig.fromEnvironment();
            this.actionCache = new ActionCache(".builder-cache/actions/cpp", cacheConfig);
        }
        else
        {
            this.actionCache = actionCache;
        }
        
        if (depCache is null)
        {
            this.depCache = new DependencyCache(".builder-cache/incremental/cpp");
        }
        else
        {
            this.depCache = depCache;
        }
        
        // Initialize incremental engine
        this.incEngine = new IncrementalEngine(this.depCache, this.actionCache);
        
        // Initialize dependency analyzer
        this.analyzer = new CppDependencyAnalyzer(config.includeDirs);
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
        
        Logger.info("Incremental C++ compilation with " ~ compilerInfo.name);
        
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
        
        // Determine output paths
        string outputFile = determineOutputPath(config, target, workspace);
        string outputDir = dirName(outputFile);
        string objDir = determineObjDir(config, workspace);
        
        // Ensure directories exist
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        if (!exists(objDir))
            mkdirRecurse(objDir);
        
        // Compile with incremental optimization
        string[] cppObjects;
        if (!cppFiles.empty)
        {
            auto cppResult = compileIncremental(
                cppFiles, config, objDir, true, target, workspace
            );
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
            auto cResult = compileIncremental(
                cFiles, config, objDir, false, target, workspace
            );
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
        
        // Combine and link
        string[] allObjects = cppObjects ~ cObjects;
        result.objects = allObjects;
        
        auto linkResult = linkObjects(
            allObjects, outputFile, config, !cppFiles.empty, target
        );
        if (!linkResult.success)
        {
            result.error = linkResult.error;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputFile];
        result.outputHash = FastHash.hashFile(outputFile);
        
        // Log incremental statistics
        auto stats = incEngine.getStats();
        Logger.success("Incremental compilation complete: " ~
                      stats.validDependencies.to!string ~ " dependencies tracked");
        
        return result;
    }
    
    /// Compile files with incremental dependency tracking
    private CppCompileResult compileIncremental(
        string[] sources,
        in CppConfig config,
        string objDir,
        bool isCpp,
        in Target target,
        in WorkspaceConfig workspace
    ) @system
    {
        CppCompileResult result;
        result.success = true;
        
        string compiler = isCpp ? 
            Toolchain.getCppCompiler(compilerInfo) :
            Toolchain.getCCompiler(compilerInfo);
        
        auto flags = buildCompilerFlags(config, isCpp);
        
        // Build metadata for cache
        string[string] baseMetadata;
        baseMetadata["compiler"] = compiler;
        baseMetadata["flags"] = flags.join(" ");
        baseMetadata["isCpp"] = isCpp.to!string;
        
        // Determine rebuild set using incremental engine
        auto rebuildResult = incEngine.determineRebuildSet(
            sources,
            [],  // Changed files detected by file watching or user
            (file) {
                ActionId actionId;
                actionId.targetId = target.name;
                actionId.type = ActionType.Compile;
                actionId.subId = baseName(file);
                actionId.inputHash = FastHash.hashFile(file);
                return actionId;
            },
            (file) => baseMetadata
        );
        
        Logger.info("Incremental: " ~ rebuildResult.compiledFiles.to!string ~ 
                   " files to compile, " ~ rebuildResult.cachedFiles_.to!string ~ 
                   " cached (" ~ rebuildResult.reductionRate.to!string[0..min(5, $)] ~ "%)");
        
        // Compile only necessary files
        foreach (source; rebuildResult.filesToCompile)
        {
            auto compileResult = compileOneFile(
                source, compiler, flags, objDir, target, baseMetadata
            );
            
            if (!compileResult.success)
            {
                result.success = false;
                result.error = compileResult.error;
                result.hadWarnings = compileResult.hadWarnings;
                result.warnings ~= compileResult.warnings;
                return result;
            }
            
            result.objects ~= compileResult.objects;
            result.warnings ~= compileResult.warnings;
            result.hadWarnings = result.hadWarnings || compileResult.hadWarnings;
        }
        
        // Add cached object files
        foreach (cachedFile; rebuildResult.cachedFiles)
        {
            string objFile = buildPath(objDir, baseName(cachedFile).stripExtension ~ ".o");
            if (exists(objFile))
            {
                result.objects ~= objFile;
                Logger.debugLog("  [Using Cached] " ~ objFile);
            }
        }
        
        return result;
    }
    
    /// Compile a single file and record dependencies
    private CppCompileResult compileOneFile(
        string source,
        string compiler,
        string[] flags,
        string objDir,
        in Target target,
        string[string] metadata
    ) @system
    {
        CppCompileResult result;
        
        string objFile = buildPath(objDir, baseName(source).stripExtension ~ ".o");
        
        // Analyze dependencies before compilation
        auto depsResult = analyzer.analyzeDependencies(source);
        string[] dependencies;
        if (depsResult.isOk)
        {
            dependencies = depsResult.unwrap();
            Logger.debugLog("  Dependencies for " ~ source ~ ": " ~ 
                          dependencies.length.to!string);
        }
        
        // Build compile command
        string[] cmd = [compiler];
        cmd ~= flags;
        cmd ~= ["-c", source];
        cmd ~= ["-o", objFile];
        
        Logger.info("Compiling: " ~ source);
        Logger.debugLog("  Command: " ~ cmd.join(" "));
        
        // Execute compilation
        auto res = execute(cmd);
        bool success = (res.status == 0);
        
        if (!success)
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
        
        // Record successful compilation with dependencies
        ActionId actionId;
        actionId.targetId = target.name;
        actionId.type = ActionType.Compile;
        actionId.subId = baseName(source);
        actionId.inputHash = FastHash.hashFile(source);
        
        incEngine.recordCompilation(
            source,
            dependencies,
            actionId,
            [objFile],
            metadata
        );
        
        result.success = true;
        result.objects = [objFile];
        return result;
    }
    
    /// Link object files
    private CppCompileResult linkObjects(
        string[] objects,
        string outputFile,
        in CppConfig config,
        bool isCpp,
        in Target target
    ) @system
    {
        CppCompileResult result;
        
        string linker = isCpp ?
            Toolchain.getCppCompiler(compilerInfo) :
            Toolchain.getCCompiler(compilerInfo);
        
        auto linkerFlags = buildLinkerFlags(config);
        
        // Build link command
        string[] cmd = [linker];
        cmd ~= ["-o", outputFile];
        cmd ~= objects;
        cmd ~= linkerFlags;
        
        Logger.info("Linking: " ~ outputFile);
        Logger.debugLog("  Command: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Linking failed: " ~ res.output;
            return result;
        }
        
        if (!res.output.empty)
        {
            result.hadWarnings = true;
            result.warnings ~= "Linker: " ~ res.output;
        }
        
        result.success = true;
        return result;
    }
    
    private string determineOutputPath(
        in CppConfig config,
        in Target target,
        in WorkspaceConfig workspace
    ) @system
    {
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
        return outputFile;
    }
    
    private string determineObjDir(
        in CppConfig config,
        in WorkspaceConfig workspace
    ) @system
    {
        string objDir = config.objDir;
        if (!objDir.isAbsolute)
            objDir = buildPath(workspace.options.outputDir, objDir);
        return objDir;
    }
    
    override bool isAvailable()
    {
        return compilerInfo.isAvailable;
    }
    
    override string name() const
    {
        return "IncrementalBuilder (" ~ compilerInfo.name ~ ")";
    }
    
    override string getVersion()
    {
        return compilerInfo.version_;
    }
    
    override bool supportsFeature(string feature)
    {
        switch (feature)
        {
            case "incremental":
            case "dependency_tracking":
                return true;
            default:
                return super.supportsFeature(feature);
        }
    }
}

