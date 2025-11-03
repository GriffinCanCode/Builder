module infrastructure.repository;

/// Repository Rules System
/// 
/// Provides external dependency management for Builder through repository rules.
/// Repositories are fetched, cached, and referenced using the @repo// syntax.
/// 
/// Features:
/// - HTTP/Archive fetching with integrity verification (BLAKE3/SHA256)
/// - Git repository support with commit/tag pinning
/// - Local filesystem repositories for development
/// - Content-addressable caching with automatic deduplication
/// - Lazy fetching (on-demand download)
/// - Hermetic builds with cryptographic verification
/// 
/// Usage:
/// ```d
/// // In Builderspace:
/// repository("llvm") {
///     url: "https://github.com/llvm/llvm-project/releases/download/...";
///     integrity: "sha256-abc123...";  // BLAKE3 or SHA256 hash
/// }
/// 
/// // In Builderfile:
/// target("my-app") {
///     deps: ["@llvm//lib:Support"];
/// }
/// ```
/// 
/// Architecture:
/// - types.d: Core data structures (RepositoryRule, CachedRepository, etc.)
/// - fetcher.d: Downloads and extracts repositories
/// - cache.d: Manages local cache of fetched repositories
/// - resolver.d: Resolves @repo// references to filesystem paths
/// - verifier.d: Integrity verification using BLAKE3/SHA256

public import infrastructure.repository.types;
public import infrastructure.repository.fetcher;
public import infrastructure.repository.cache;
public import infrastructure.repository.resolver;
public import infrastructure.repository.verifier;

