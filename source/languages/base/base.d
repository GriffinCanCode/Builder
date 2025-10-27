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
    Result!(string, BuildError) build(Target target, WorkspaceConfig config) @safe
    {
        try
        {
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
    
    bool needsRebuild(in Target target, in WorkspaceConfig config) @safe
    {
        import std.file : exists;
        
        auto outputs = () @trusted { return getOutputs(target, config); }();
        
        // Rebuild if any output is missing
        foreach (output; outputs)
        {
            if (!exists(output))
                return true;
        }
        
        return false;
    }
    
    void clean(in Target target, in WorkspaceConfig config) @safe
    {
        import std.file : remove, exists;
        
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

