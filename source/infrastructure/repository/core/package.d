module infrastructure.repository.core;

/// Core Types Module
/// 
/// Contains fundamental data structures, enums, and error types
/// for the repository rules system.
/// 
/// Exports:
/// - RepositoryRule: Repository definition with URL, integrity, etc.
/// - RepositoryKind: Repository type (Http, Git, Local)
/// - ArchiveFormat: Archive format enumeration
/// - CachedRepository: Cached repository metadata
/// - ResolvedRepository: Resolved repository result
/// - RepositoryError: Repository-specific error type

public import infrastructure.repository.core.types;

