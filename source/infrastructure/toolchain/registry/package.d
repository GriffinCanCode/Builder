module infrastructure.toolchain.registry;

/// Toolchain Registry and Constraint System
/// 
/// This module provides centralized toolchain management and version
/// constraint resolution. The registry maintains all available toolchains
/// and supports lookup by name, platform, and constraint matching.
/// 
/// ## Modules
/// 
/// - `registry` - Central toolchain registry (singleton)
/// - `constraints` - Version and capability constraint system
/// 
/// ## Usage
/// 
/// ```d
/// // Get registry instance
/// auto registry = ToolchainRegistry.instance();
/// registry.initialize();
/// 
/// // Find toolchain by platform
/// auto toolchain = registry.findFor(Platform.host());
/// 
/// // Find with constraints
/// auto constraint = ToolchainConstraint.parse("gcc@>=11.0.0");
/// auto tc = registry.findMatching(constraint.unwrap());
/// ```

public import infrastructure.toolchain.registry.registry;
public import infrastructure.toolchain.registry.constraints;

