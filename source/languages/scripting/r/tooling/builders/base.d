module languages.scripting.r.tooling.builders.base;

import infrastructure.config.schema.schema;
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
        in Target target,
        in WorkspaceConfig config,
        in RConfig rConfig,
        in string rCmd
    );
    
    /// Get build outputs
    string[] getOutputs(in Target target, in WorkspaceConfig config, in RConfig rConfig);
    
    /// Validate build configuration
    bool validate(in Target target, in RConfig rConfig);
}

