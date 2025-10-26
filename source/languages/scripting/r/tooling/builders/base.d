module languages.scripting.r.builders.base;

import config.schema.schema;
import languages.scripting.r.core.config;

/// Build result specific to builders
struct BuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    string[] toolWarnings;
}

/// Base interface for R builders
interface RBuilder
{
    /// Build the target
    BuildResult build(
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

