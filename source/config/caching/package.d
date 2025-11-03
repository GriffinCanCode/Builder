module config.caching;

/// Parse tree caching for incremental DSL parsing
/// 
/// This module provides high-performance caching of parsed AST trees
/// to avoid reparsing unchanged Builderfiles.
/// 
/// Features:
/// - Content-addressable storage with BLAKE3 hashing
/// - Two-tier validation (metadata + content)
/// - Binary AST serialization for speed
/// - Thread-safe concurrent access
/// - LRU eviction policy
/// - Automatic invalidation on file changes

public import config.caching.storage;
public import config.caching.parse;
