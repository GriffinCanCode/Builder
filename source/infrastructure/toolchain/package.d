module infrastructure.toolchain;

/// Platform/Toolchain Abstraction System
/// 
/// Provides unified platform and toolchain management for cross-compilation
/// and build tool configuration. This module consolidates toolchain detection,
/// version management, and cross-compilation support across all language handlers.
/// 
/// ## Core Concepts
/// 
/// **Platform**: OS + Architecture + ABI triple (e.g., x86_64-unknown-linux-gnu)
/// **Toolchain**: Collection of tools (compiler, linker, archiver, etc.)
/// **Tool**: Individual executable with version and capabilities
/// 
/// ## Usage
/// 
/// ```d
/// // Get current host platform
/// auto host = Platform.host();
/// 
/// // Parse target platform
/// auto target = Platform.parse("aarch64-unknown-linux-gnu");
/// 
/// // Auto-detect toolchains
/// auto registry = ToolchainRegistry.instance();
/// registry.initialize();
/// 
/// // Find toolchain for platform
/// auto toolchain = registry.findFor(target.unwrap());
/// 
/// // Resolve toolchain reference
/// auto tc = resolveToolchain("@toolchains//arm:gcc-11");
/// ```
/// 
/// ## DSL Integration
/// 
/// ```
/// target("app") {
///     type: executable;
///     platform: "linux-arm64";
///     toolchain: "@toolchains//arm:gcc-11";
///     sources: ["main.c"];
/// }
/// ```

public import infrastructure.toolchain.platform;
public import infrastructure.toolchain.spec;
public import infrastructure.toolchain.detector;
public import infrastructure.toolchain.detectors;
public import infrastructure.toolchain.registry;
public import infrastructure.toolchain.providers;
public import infrastructure.toolchain.constraints;

import infrastructure.errors : Result, BuildError;

/// Convenience function to get a toolchain by name with optional version constraint
Result!(Toolchain, BuildError) getToolchainByName(string name, string versionConstraint = "") @system
{
    auto registry = ToolchainRegistry.instance();
    registry.initialize();
    
    if (versionConstraint.empty)
    {
        auto toolchains = registry.getByName(name);
        if (toolchains.empty)
        {
            return Err!(Toolchain, BuildError)(
                new SystemError("Toolchain not found: " ~ name, ErrorCode.ToolNotFound));
        }
        // Return latest version
        return Ok!(Toolchain, BuildError)(toolchains[$ - 1]);
    }
    
    // Use constraint matching
    auto constraintResult = ToolchainConstraint.parse(name ~ "@" ~ versionConstraint);
    if (constraintResult.isErr)
        return Err!(Toolchain, BuildError)(constraintResult.unwrapErr());
    
    return registry.findMatching(constraintResult.unwrap());
}

/// Get compiler tool path for a toolchain by name
string getCompilerPath(string toolchainName) @system
{
    auto result = getToolchainByName(toolchainName);
    if (result.isErr)
        return "";
    
    auto tc = result.unwrap();
    auto compiler = tc.compiler();
    return compiler ? compiler.path : "";
}

