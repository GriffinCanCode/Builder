/**
 * Example: Action-Level Caching in C++ Handler
 * 
 * This example demonstrates how to implement action-level caching
 * in a language handler for fine-grained incremental builds.
 */

module examples.action_caching_example;

import std.stdio;
import std.algorithm;
import std.array;
import std.path;
import std.file;
import config.schema.schema;
import languages.base.base;
import core.caching.action;
import utils.files.hash;
import errors;

/**
 * Enhanced C++ handler with action-level caching
 * 
 * Demonstrates:
 * - Per-file compilation caching
 * - Separate linking action
 * - Dependency tracking
 * - Metadata management
 */
class EnhancedCppHandler : BaseLanguageHandler
{
    /**
     * Build with action-level granularity
     * 
     * Strategy:
     * 1. Check each source file's compilation action in cache
     * 2. Recompile only changed files
     * 3. Check linking action in cache
     * 4. Relink only if objects changed or linker flags changed
     */
    override Result!(string, BuildError) buildWithContext(BuildContext context) @safe
    {
        auto target = context.target;
        auto config = context.config;
        
        writeln("Building C++ target with action-level caching: ", target.name);
        
        // Phase 1: Compilation (per-file actions)
        string[] objectFiles;
        bool anyCompilationFailed = false;
        
        foreach (source; target.sources)
        {
            auto compileResult = compileSourceFile(
                context,
                source,
                target,
                config
            );
            
            if (compileResult.isErr)
            {
                anyCompilationFailed = true;
                writeln("  [Failed] ", source);
                continue;  // Try to compile other files
            }
            
            objectFiles ~= compileResult.unwrap();
        }
        
        if (anyCompilationFailed)
        {
            auto error = new BuildFailureError(
                target.name,
                "One or more compilation actions failed",
                ErrorCode.BuildFailed
            );
            return Err!(string, BuildError)(error);
        }
        
        // Phase 2: Linking (single action for all objects)
        auto linkResult = linkObjectFiles(
            context,
            objectFiles,
            target,
            config
        );
        
        if (linkResult.isErr)
        {
            return linkResult;  // Propagate link error
        }
        
        writeln("Build completed: ", target.name);
        return linkResult;
    }
    
    /**
     * Compile a single source file with action-level caching
     */
    private Result!(string, BuildError) compileSourceFile(
        ref BuildContext context,
        string source,
        Target target,
        WorkspaceConfig config
    ) @safe
    {
        // Generate object file path
        immutable objectFile = generateObjectPath(source, config.options.outputDir);
        
        // Create action ID for this compilation
        // Hash includes: source content, compiler flags, includes
        string inputHash = computeCompileInputHash(source, target);
        
        auto actionId = ActionId(
            target.name,
            ActionType.Compile,
            inputHash,
            source  // Sub-ID distinguishes different source files
        );
        
        // Prepare metadata (execution context)
        string[string] metadata;
        metadata["compiler"] = "g++";
        metadata["flags"] = target.flags.join(" ");
        metadata["includes"] = target.includes.join(",");
        metadata["language"] = "c++17";
        
        // Check if this compilation action is cached
        // (In real implementation, this would be done by ActionCache)
        if (isActionCachedAndValid(actionId, [source], objectFile, metadata))
        {
            writeln("  [Cached] ", source);
            
            // Record successful cache hit (updates LRU)
            context.recordAction(
                actionId,
                [source],
                [objectFile],
                metadata,
                true
            );
            
            return Ok!(string, BuildError)(objectFile);
        }
        
        writeln("  [Compiling] ", source);
        
        // Execute actual compilation
        auto compileResult = executeCompilation(source, objectFile, target, config);
        
        // Record action result for future builds
        context.recordAction(
            actionId,
            [source],
            [objectFile],
            metadata,
            compileResult.success
        );
        
        if (compileResult.success)
        {
            return Ok!(string, BuildError)(objectFile);
        }
        else
        {
            auto error = new BuildFailureError(
                target.name,
                "Compilation failed: " ~ source ~ "\n" ~ compileResult.error,
                ErrorCode.BuildFailed
            );
            return Err!(string, BuildError)(error);
        }
    }
    
    /**
     * Link object files with action-level caching
     */
    private Result!(string, BuildError) linkObjectFiles(
        ref BuildContext context,
        string[] objectFiles,
        Target target,
        WorkspaceConfig config
    ) @safe
    {
        immutable executable = buildPath(
            config.options.outputDir,
            target.name
        );
        
        // Create action ID for linking
        // Hash includes: all object files, linker flags, dependencies
        string inputHash = computeLinkInputHash(objectFiles, target);
        
        auto actionId = ActionId(
            target.name,
            ActionType.Link,
            inputHash,
            ""  // No sub-ID for linking (single action)
        );
        
        // Prepare linker metadata
        string[string] metadata;
        metadata["linker"] = "g++";
        metadata["flags"] = target.flags.join(" ");
        metadata["libs"] = target.deps.join(",");
        
        // Check if linking action is cached
        if (isActionCachedAndValid(actionId, objectFiles, executable, metadata))
        {
            writeln("  [Cached] Linking");
            
            context.recordAction(
                actionId,
                objectFiles,
                [executable],
                metadata,
                true
            );
            
            // Return hash of executable
            return Ok!(string, BuildError)(FastHash.hashFile(executable));
        }
        
        writeln("  [Linking] ", objectFiles.length, " object files");
        
        // Execute actual linking
        auto linkResult = executeLinking(objectFiles, executable, target, config);
        
        // Record linking action
        context.recordAction(
            actionId,
            objectFiles,
            [executable],
            metadata,
            linkResult.success
        );
        
        if (linkResult.success)
        {
            return Ok!(string, BuildError)(FastHash.hashFile(executable));
        }
        else
        {
            auto error = new BuildFailureError(
                target.name,
                "Linking failed: " ~ linkResult.error,
                ErrorCode.BuildFailed
            );
            return Err!(string, BuildError)(error);
        }
    }
    
    // Helper methods
    
    private string generateObjectPath(string source, string outputDir) @safe
    {
        auto basename = baseName(source, extension(source));
        return buildPath(outputDir, basename ~ ".o");
    }
    
    private string computeCompileInputHash(string source, Target target) @safe
    {
        import std.digest.sha : SHA256, toHexString;
        
        SHA256 hash;
        hash.start();
        
        // Hash source file content
        hash.put(cast(ubyte[])FastHash.hashFile(source));
        
        // Hash compiler flags
        foreach (flag; target.flags)
            hash.put(cast(ubyte[])flag);
        
        // Hash include paths
        foreach (inc; target.includes)
            hash.put(cast(ubyte[])inc);
        
        return toHexString(hash.finish()).to!string;
    }
    
    private string computeLinkInputHash(string[] objectFiles, Target target) @safe
    {
        import std.digest.sha : SHA256, toHexString;
        
        SHA256 hash;
        hash.start();
        
        // Hash all object files
        foreach (obj; objectFiles)
        {
            if (exists(obj))
                hash.put(cast(ubyte[])FastHash.hashFile(obj));
        }
        
        // Hash linker flags
        foreach (flag; target.flags)
            hash.put(cast(ubyte[])flag);
        
        // Hash dependencies
        foreach (dep; target.deps)
            hash.put(cast(ubyte[])dep);
        
        return toHexString(hash.finish()).to!string;
    }
    
    private bool isActionCachedAndValid(
        ActionId actionId,
        string[] inputs,
        string output,
        string[string] metadata
    ) @safe
    {
        // In real implementation, this would call ActionCache.isCached()
        // For this example, we check if output exists and is newer than inputs
        
        if (!exists(output))
            return false;
        
        auto outputTime = timeLastModified(output);
        
        foreach (input; inputs)
        {
            if (!exists(input))
                return false;
            
            if (timeLastModified(input) > outputTime)
                return false;
        }
        
        return true;
    }
    
    // Stub implementations (would call actual compiler/linker)
    
    private struct ExecutionResult
    {
        bool success;
        string error;
    }
    
    private ExecutionResult executeCompilation(
        string source,
        string output,
        Target target,
        WorkspaceConfig config
    ) @safe
    {
        // In real implementation:
        // - Build compiler command
        // - Execute via process
        // - Capture output
        // - Return result
        
        ExecutionResult result;
        result.success = true;  // Stub
        return result;
    }
    
    private ExecutionResult executeLinking(
        string[] objectFiles,
        string executable,
        Target target,
        WorkspaceConfig config
    ) @safe
    {
        // In real implementation:
        // - Build linker command
        // - Execute via process
        // - Capture output
        // - Return result
        
        ExecutionResult result;
        result.success = true;  // Stub
        return result;
    }
    
    // Required by base interface
    protected override LanguageBuildResult buildImpl(
        in Target target,
        in WorkspaceConfig config
    )
    {
        LanguageBuildResult result;
        result.success = false;
        result.error = "Use buildWithContext() instead";
        return result;
    }
}

/**
 * Example usage in a build scenario
 */
void demonstrateActionCaching()
{
    writeln("=== Action-Level Caching Example ===\n");
    
    // Setup target
    Target target;
    target.name = "myapp";
    target.type = TargetType.Executable;
    target.language = TargetLanguage.Cpp;
    target.sources = [
        "src/main.cpp",
        "src/utils.cpp",
        "src/parser.cpp"
    ];
    target.flags = ["-O2", "-Wall", "-std=c++17"];
    target.includes = ["include/"];
    
    WorkspaceConfig config;
    config.options.outputDir = "bin";
    
    // Create handler
    auto handler = new EnhancedCppHandler();
    
    // Build context with action recorder
    BuildContext context;
    context.target = target;
    context.config = config;
    context.recorder = (ActionId id, string[] inputs, string[] outputs, 
                        string[string] metadata, bool success)
    {
        writeln("  [Recorded] Action: ", id.toString());
        writeln("    Inputs: ", inputs);
        writeln("    Outputs: ", outputs);
        writeln("    Success: ", success);
    };
    
    // First build (all actions executed)
    writeln("First build (cold cache):");
    auto result1 = handler.buildWithContext(context);
    writeln();
    
    // Second build (all actions cached)
    writeln("Second build (warm cache):");
    auto result2 = handler.buildWithContext(context);
    writeln();
    
    // Third build (modify one source, only recompile that file + relink)
    writeln("Third build (modified src/main.cpp):");
    // In real scenario, touch src/main.cpp here
    auto result3 = handler.buildWithContext(context);
    
    writeln("\n=== Benefits Demonstrated ===");
    writeln("✓ Per-file compilation caching");
    writeln("✓ Incremental rebuild on source changes");
    writeln("✓ Separate link caching");
    writeln("✓ Detailed action tracking");
    writeln("✓ Partial rebuild on failure");
}

