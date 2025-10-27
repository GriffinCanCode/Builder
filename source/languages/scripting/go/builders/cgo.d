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

/// CGO builder - handles C interop compilation
class CGoBuilder : StandardBuilder
{
    override GoBuildResult build(
        in string[] sources,
        in GoConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        // Ensure CGO is enabled
        if (!config.cgo.enabled)
        {
            Logger.info("Enabling CGO for C interop build");
            config.cgo.enabled = true;
        }
        
        // Validate C/C++ compiler availability if specified
        if (!config.cgo.cc.empty)
        {
            if (!isCommandAvailable(config.cgo.cc))
            {
                GoBuildResult result;
                result.error = "C compiler not found: " ~ config.cgo.cc;
                return result;
            }
        }
        
        if (!config.cgo.cxx.empty)
        {
            if (!isCommandAvailable(config.cgo.cxx))
            {
                GoBuildResult result;
                result.error = "C++ compiler not found: " ~ config.cgo.cxx;
                return result;
            }
        }
        
        Logger.info("Building with CGO enabled");
        if (!config.cgo.cflags.empty)
            Logger.debug_("CGO_CFLAGS: " ~ config.cgo.cflags.join(" "));
        if (!config.cgo.ldflags.empty)
            Logger.debug_("CGO_LDFLAGS: " ~ config.cgo.ldflags.join(" "));
        
        // Use standard builder with CGO configuration
        return super.build(sources, config, target, workspace);
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

