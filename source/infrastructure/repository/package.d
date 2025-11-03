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
/// Module Structure:
/// - core: Core data structures, enums, and error types
/// - acquisition: Repository fetching and integrity verification
/// - storage: Local cache management
/// - resolution: @repo// reference resolution

// Core types and data structures
public import infrastructure.repository.core;

// Acquisition (fetching and verification)
public import infrastructure.repository.acquisition;

// Storage (caching)
public import infrastructure.repository.storage;

// Resolution (@repo// references)
public import infrastructure.repository.resolution;

