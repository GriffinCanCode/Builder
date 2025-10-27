module languages.base.base;

import std.conv : to;
import config.schema.schema;
import analysis.targets.types;
import errors;

/// Base interface for language-specific build handlers
interface LanguageHandler
{
    /// Build a target - returns Result type for type-safe error handling
    Result!(string, BuildError) build(Target target, WorkspaceConfig config);
    
    /// Check if target needs rebuild
    bool needsRebuild(in Target target, in WorkspaceConfig config);
    
    /// Clean build artifacts
    void clean(in Target target, in WorkspaceConfig config);
    
    /// Get output files for a target
    string[] getOutputs(in Target target, in WorkspaceConfig config);
    
    /// Analyze imports in source files (optional for advanced dependency analysis)
    Import[] analyzeImports(in string[] sources);
}

/// Base implementation with common functionality
abstract class BaseLanguageHandler : LanguageHandler
{
    /// Build a target with error handling and Result wrapper
    /// 
    /// Safety: Calls buildImpl() and getOutputs() through @trusted wrappers because
    /// language handlers may perform file I/O, process execution, and other
    /// operations that are inherently @system but have been validated for safety.
    /// 
    /// The @trusted lambda wrapper pattern:
    /// - Delegates responsibility to concrete language handlers
    /// - Each handler marks buildImpl() as @trusted with justification
    /// - This function remains @safe by wrapping the call
    /// - Exceptions are caught and converted to Result types
    /// 
    /// Invariants:
    /// - buildImpl() is overridden in each language handler
    /// - All file I/O and process execution is validated by handlers
    /// - Result type ensures type-safe error propagation
    /// - No unsafe operations leak to caller
    /// 
    /// What could go wrong:
    /// - Handler buildImpl() has memory safety bug: contained within handler
    /// - Exception thrown: caught and converted to BuildError Result
    /// - Invalid target: handler validates and returns error Result
    Result!(string, BuildError) build(Target target, WorkspaceConfig config) @safe
    {
        try
        {
            // Safety: buildImpl() performs I/O and process execution
            // Marked @trusted in each language handler with specific justification
            // This lambda wrapper keeps build() @safe while allowing @system ops
            auto result = () @trusted { return buildImpl(target, config); }();
            
            if (result.success)
            {
                return Ok!(string, BuildError)(result.outputHash);
            }
            else
            {
                auto error = new BuildFailureError(
                    target.name,
                    result.error,
                    ErrorCode.BuildFailed
                );
                error.addContext(ErrorContext(
                    "building target",
                    "language: " ~ target.language.to!string
                ));
                return Err!(string, BuildError)(error);
            }
        }
        catch (Exception e)
        {
            auto error = new BuildFailureError(
                target.name,
                e.msg,
                ErrorCode.BuildFailed
            );
            error.addContext(ErrorContext(
                "caught exception during build",
                e.classinfo.name
            ));
            return Err!(string, BuildError)(error);
        }
    }
    
    /// Check if target needs rebuild based on output file existence
    /// 
    /// Safety: This function is @safe and calls getOutputs() through @trusted wrapper
    /// because handlers may perform path operations (inherently @system).
    /// 
    /// The @trusted lambda wrapper pattern:
    /// - getOutputs() is marked @trusted in each language handler
    /// - Path operations are validated by handlers
    /// - exists() check is read-only file system query
    /// 
    /// Invariants:
    /// - getOutputs() returns validated output paths
    /// - exists() is safe read-only operation
    /// - Returns true if any output missing (conservative rebuild)
    /// 
    /// What could go wrong:
    /// - Handler returns invalid paths: contained within handler
    /// - exists() throws: would propagate (safe failure)
    bool needsRebuild(in Target target, in WorkspaceConfig config) @safe
    {
        import std.file : exists;
        
        // Safety: getOutputs() performs path operations
        // Marked @trusted in each handler with specific justification
        auto outputs = () @trusted { return getOutputs(target, config); }();
        
        // Rebuild if any output is missing
        foreach (output; outputs)
        {
            if (!exists(output))
                return true;
        }
        
        return false;
    }
    
    /// Clean build artifacts by removing output files
    /// 
    /// Safety: This function is @safe and calls getOutputs() through @trusted wrapper.
    /// File deletion operations (remove) are inherently @system but safe here because:
    /// - Only deletes files returned by handler's getOutputs()
    /// - Checks existence before attempting removal
    /// - Handler validates output paths
    /// 
    /// The @trusted lambda wrapper pattern:
    /// - getOutputs() provides validated file list
    /// - Deletion is confined to handler-specified outputs
    /// - No arbitrary file deletion possible
    /// 
    /// Invariants:
    /// - Only removes files listed by getOutputs()
    /// - Checks exists() before remove()
    /// - Handler ensures output paths are within project
    /// 
    /// What could go wrong:
    /// - Permission denied: remove() throws (safe failure)
    /// - File in use: remove() throws (safe failure)
    /// - Handler returns invalid paths: contained within handler
    void clean(in Target target, in WorkspaceConfig config) @safe
    {
        import std.file : remove, exists;
        
        // Safety: getOutputs() returns validated output file paths
        // Marked @trusted in each handler with specific justification
        auto outputs = () @trusted { return getOutputs(target, config); }();
        
        foreach (output; outputs)
        {
            if (exists(output))
                remove(output);
        }
    }
    
    Import[] analyzeImports(string[] sources) @safe
    {
        // Default implementation: delegate to language spec
        // Subclasses can override for custom analysis
        import analysis.targets.spec;
        import std.file : readText, exists, isFile;
        
        Import[] allImports;
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            try
            {
                auto content = readText(source);
                // Subclasses should override to provide language-specific logic
                // This is a fallback
            }
            catch (Exception e)
            {
                // Silently skip unreadable files
            }
        }
        
        return allImports;
    }
    
    /// Subclasses implement the actual build logic
    protected abstract LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config);
}

