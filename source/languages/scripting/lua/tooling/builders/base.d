module languages.scripting.lua.tooling.builders.base;

import languages.scripting.lua.core.config;
import config.schema.schema;
import analysis.targets.spec;

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
}

/// Factory for creating appropriate Lua builders
class BuilderFactory
{
    /// Create builder based on build mode
    static LuaBuilder create(LuaBuildMode mode, LuaConfig config) @trusted
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
                    return new LuaJITBuilder();
                }
                return new ScriptBuilder();
                
            case LuaBuildMode.Bytecode:
                if (config.luajit.bytecode || config.runtime == LuaRuntime.LuaJIT)
                {
                    return new LuaJITBuilder();
                }
                return new BytecodeBuilder();
                
            case LuaBuildMode.Library:
                // Libraries are just validated scripts
                return new ScriptBuilder();
                
            case LuaBuildMode.Rock:
                // Rock building uses script builder with LuaRocks
                return new ScriptBuilder();
        }
    }
}

