module languages.scripting.go.builders.cgo;

import std.array;
import std.range;
import languages.scripting.go.builders.standard;
import languages.scripting.go.builders.base;
import languages.scripting.go.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.logging.logger;
import utils.process : isCommandAvailable;
import core.caching.actions.action : ActionCache;

/// CGO builder - handles C interop compilation
class CGoBuilder : StandardBuilder
{
    this(ActionCache actionCache = null)
    {
        super(actionCache);
    }
    
    override GoBuildResult build(
        in string[] sources,
        in GoConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        // Ensure CGO is enabled
        GoConfig mutableConfig = cast(GoConfig)config;
        if (!mutableConfig.cgo.enabled)
        {
            Logger.info("Enabling CGO for C interop build");
            mutableConfig.cgo.enabled = true;
        }
        
        // Validate C/C++ compiler availability if specified
        if (!mutableConfig.cgo.cc.empty)
        {
            if (!isCommandAvailable(mutableConfig.cgo.cc))
            {
                GoBuildResult result;
                result.error = "C compiler not found: " ~ mutableConfig.cgo.cc;
                return result;
            }
        }
        
        if (!mutableConfig.cgo.cxx.empty)
        {
            if (!isCommandAvailable(mutableConfig.cgo.cxx))
            {
                GoBuildResult result;
                result.error = "C++ compiler not found: " ~ mutableConfig.cgo.cxx;
                return result;
            }
        }
        
        Logger.info("Building with CGO enabled");
        if (!mutableConfig.cgo.cflags.empty)
            Logger.debugLog("CGO_CFLAGS: " ~ mutableConfig.cgo.cflags.join(" "));
        if (!mutableConfig.cgo.ldflags.empty)
            Logger.debugLog("CGO_LDFLAGS: " ~ mutableConfig.cgo.ldflags.join(" "));
        
        // Use standard builder with CGO configuration
        return super.build(sources, mutableConfig, target, workspace);
    }
    
    override string name() const
    {
        return "cgo";
    }
    
    override bool supportsMode(GoBuildMode mode)
    {
        return mode == GoBuildMode.CArchive ||
               mode == GoBuildMode.CShared ||
               mode == GoBuildMode.Executable ||
               mode == GoBuildMode.Library;
    }
    
}

