module languages.compiled.swift.tooling.builders.base;

import std.range;
import languages.compiled.swift.config;
import config.schema.schema;

/// Base interface for Swift builders
interface SwiftBuilder
{
    /// Build Swift project
    SwiftBuildResult build(
        in string[] sources,
        in SwiftConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if builder is available on system
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Get builder version
    string getVersion();
    
    /// Supports specific features
    bool supportsFeature(string feature);
}

/// Factory for creating Swift builders
class SwiftBuilderFactory
{
    /// Create builder based on configuration
    static SwiftBuilder create(SwiftConfig config)
    {
        import languages.compiled.swift.tooling.builders.spm;
        import languages.compiled.swift.tooling.builders.swiftc;
        import languages.compiled.swift.tooling.builders.xcode;
        
        // If Package.swift exists, use SPM
        if (!config.manifest.manifestPath.empty)
        {
            return new SPMBuilder();
        }
        
        // If Xcode integration requested
        version(OSX)
        {
            if (config.xcodeIntegration)
            {
                auto xcode = new XcodeBuilder();
                if (xcode.isAvailable())
                    return xcode;
            }
        }
        
        // Fallback to direct swiftc compilation
        return new SwiftcBuilder();
    }
}

