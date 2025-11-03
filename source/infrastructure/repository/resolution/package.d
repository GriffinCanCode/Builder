module infrastructure.repository.resolution;

/// Resolution Module
/// 
/// Resolves @repo// references to actual filesystem paths.
/// 
/// Components:
/// - RepositoryResolver: Resolves external repository references
/// 
/// Features:
/// - Lazy fetching (on-demand download)
/// - Reference format parsing (@repo//path:target)
/// - Cache-first resolution strategy
/// - Path resolution for build targets
/// - Reference validation

public import infrastructure.repository.resolution.resolver;

