module languages.scripting.lua.tooling.builders.base;

import languages.scripting.lua.core.config;
import infrastructure.config.schema.schema;
import infrastructure.analysis.targets.spec;
import engine.caching.actions.action : ActionCache;

/// Build result structure
struct BuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
}

/// Base interface for Lua builders
interface LuaBuilder
{
    /// Build Lua sources
    BuildResult build(
        in string[] sources,
        in LuaConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if this builder can be used
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Set action cache for this builder
    void setActionCache(ActionCache cache);
}

/// Factory for creating appropriate Lua builders
class BuilderFactory
{
    /// Create builder based on build mode
    /// 
    /// Safety: This function is @system because:
    /// 1. Creates instances of builder classes (memory allocation via `new`)
    /// 2. Builder classes perform @system operations (file I/O, process execution)
    /// 3. Factory pattern allows @system code to obtain builders
    /// 4. All builder instances are properly initialized
    /// 
    /// Invariants:
    /// - Returns non-null builder instance for all valid modes
    /// - Builder selection based on validated config
    /// - final switch ensures all modes are handled
    /// 
    /// What could go wrong:
    /// - Builder construction fails: D's `new` handles allocation failure
    /// - Invalid mode: prevented by final switch (compile-time check)
    static LuaBuilder create(LuaBuildMode mode, LuaConfig config, ActionCache cache = null) @system
    {
        import languages.scripting.lua.tooling.builders.script;
        import languages.scripting.lua.tooling.builders.bytecode;
        import languages.scripting.lua.tooling.builders.luajit;
        
        final switch (mode)
        {
            case LuaBuildMode.Script:
            case LuaBuildMode.Application:
                // Check if LuaJIT should be used
                if (config.luajit.enabled || config.runtime == LuaRuntime.LuaJIT)
                {
                    auto builder = new LuaJITBuilder();
                    if (cache) builder.setActionCache(cache);
                    return builder;
                }
                auto builder = new ScriptBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
                
            case LuaBuildMode.Bytecode:
                if (config.luajit.bytecode || config.runtime == LuaRuntime.LuaJIT)
                {
                    auto builder = new LuaJITBuilder();
                    if (cache) builder.setActionCache(cache);
                    return builder;
                }
                auto builder = new BytecodeBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
                
            case LuaBuildMode.Library:
                // Libraries are just validated scripts
                auto builder = new ScriptBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
                
            case LuaBuildMode.Rock:
                // Rock building uses script builder with LuaRocks
                auto builder = new ScriptBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
        }
    }
}

