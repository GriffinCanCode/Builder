module infrastructure.repository.storage;

/// Storage Module
/// 
/// Manages local caching of fetched repositories.
/// 
/// Components:
/// - RepositoryCache: Content-addressable cache management
/// 
/// Features:
/// - Content-addressable storage by hash
/// - JSON metadata persistence
/// - Cache statistics and management
/// - Automatic invalidation of corrupt entries
/// - Efficient disk space management

public import infrastructure.repository.storage.cache;

