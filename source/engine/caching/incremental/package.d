module engine.caching.incremental;

/// Incremental compilation infrastructure
/// 
/// Provides multiple levels of incremental compilation:
/// - File-level: Track file-to-file dependencies
/// - AST-level: Track symbol-to-symbol dependencies (classes, functions)

public import engine.caching.incremental.dependency;
public import engine.caching.incremental.storage;
public import engine.caching.incremental.ast_dependency;
public import engine.caching.incremental.ast_storage;
