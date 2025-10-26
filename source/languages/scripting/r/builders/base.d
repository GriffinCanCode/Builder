module languages.scripting.r.builders.base;

import languages.base.base : LanguageBuildResult;
import config.schema.schema : WorkspaceConfig, Target;
import languages.scripting.r.config;

/// Base interface for R builders
interface RBuilder
{
    /// Build the target
    LanguageBuildResult build(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig,
        string rCmd
    );
    
    /// Get build outputs
    string[] getOutputs(Target target, WorkspaceConfig config, RConfig rConfig);
    
    /// Validate build configuration
    bool validate(Target target, RConfig rConfig);
}

