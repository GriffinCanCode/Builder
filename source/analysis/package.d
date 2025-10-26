module analysis;

/// Build Analysis Package
/// Dependency resolution and build graph analysis
/// 
/// Architecture:
///   scanner.d   - File and dependency scanning
///   resolver.d  - Dependency resolution logic
///   types.d     - Type definitions for analysis
///   analyzer.d  - Build target analysis
///   spec.d      - Build specification handling
///   metagen.d   - Metadata generation
///
/// Usage:
///   import analysis;
///   
///   auto scanner = new DependencyScanner();
///   auto deps = scanner.scan(sourceFiles);
///   
///   auto resolver = new DependencyResolver();
///   auto resolved = resolver.resolve(deps);

public import analysis.scanning.scanner;
public import analysis.resolution.resolver;
public import analysis.targets.types;
public import analysis.inference.analyzer;
public import analysis.targets.spec;
public import analysis.metadata.metagen;

