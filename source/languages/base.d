module languages.base;

import config.schema;

/// Base interface for language-specific build handlers
interface LanguageHandler
{
    /// Build a target
    LanguageBuildResult build(Target target, WorkspaceConfig config);
    
    /// Check if target needs rebuild
    bool needsRebuild(Target target, WorkspaceConfig config);
    
    /// Clean build artifacts
    void clean(Target target, WorkspaceConfig config);
    
    /// Get output files for a target
    string[] getOutputs(Target target, WorkspaceConfig config);
}

/// Base implementation with common functionality
abstract class BaseLanguageHandler : LanguageHandler
{
    LanguageBuildResult build(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        try
        {
            result = buildImpl(target, config);
        }
        catch (Exception e)
        {
            result.success = false;
            result.error = e.msg;
        }
        
        return result;
    }
    
    bool needsRebuild(Target target, WorkspaceConfig config)
    {
        import std.file : exists;
        
        auto outputs = getOutputs(target, config);
        
        // Rebuild if any output is missing
        foreach (output; outputs)
        {
            if (!exists(output))
                return true;
        }
        
        return false;
    }
    
    void clean(Target target, WorkspaceConfig config)
    {
        import std.file : remove, exists;
        
        auto outputs = getOutputs(target, config);
        
        foreach (output; outputs)
        {
            if (exists(output))
                remove(output);
        }
    }
    
    /// Subclasses implement the actual build logic
    protected abstract LanguageBuildResult buildImpl(Target target, WorkspaceConfig config);
}

