module toolchain;

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

public import toolchain.platform;
public import toolchain.spec;
public import toolchain.detector;
public import toolchain.registry;

