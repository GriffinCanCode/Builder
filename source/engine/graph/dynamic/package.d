module engine.graph.dynamic;

/// Dynamic graph extension - runtime dependency discovery
/// 
/// Exports:
/// - DynamicBuildGraph: Extends BuildGraph with runtime mutation capabilities
/// - DiscoveryMetadata: Discovery protocol metadata structure
/// - DiscoveryBuilder: Builder for creating discovery metadata
/// - GraphExtension: Thread-safe graph mutation engine
/// - DiscoveryPatterns: Common discovery patterns (codegen, tests, libraries)
/// - DiscoverableAction: Interface for actions with discovery support
/// 
/// Design Philosophy:
/// - Static analysis produces initial graph (analysis phase)
/// - Dynamic discovery extends graph during execution (discovery phase)
/// - Maintains all invariants: DAG property, correct topological order
/// - Thread-safe: all mutations are synchronized
/// 
/// Use Cases:
/// - Code generation (protobuf, GraphQL) discovering output files
/// - Template expansion creating new targets at runtime
/// - Build scripts determining platform-specific dependencies
/// - Dynamic linking discovering shared libraries
/// - Test generation discovering test files
/// 
/// Thread Safety:
/// - All mutations synchronized with mutex
/// - Discovery recording is lock-free and thread-safe
/// - Safe to call from parallel action execution

public import engine.graph.dynamic.dynamic;
public import engine.graph.dynamic.discovery;

