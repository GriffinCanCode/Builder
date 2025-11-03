# Core Module

**Core data structures and types for the repository rules system**

## Overview

The Core module defines fundamental data structures, enumerations, and error types used throughout the repository system. It provides the foundational types that all other modules depend on.

## Components

### RepositoryRule

Defines an external repository with its source, integrity hash, and configuration:

```d
struct RepositoryRule {
    string name;                    // Repository name (used in @name// references)
    RepositoryKind kind;           // Source type (Http, Git, Local)
    string url;                     // URL or path
    string integrity;               // BLAKE3/SHA256 hash for verification
    ArchiveFormat format;          // Archive format (for HTTP)
    string stripPrefix;            // Strip this prefix from extracted paths
    string gitCommit;              // Git commit SHA (for Git repositories)
    string gitTag;                 // Git tag (alternative to commit)
    string[string] patches;        // Patches to apply after fetch
}
```

### RepositoryKind

Repository source type enumeration:

- `Http`: HTTP/HTTPS archive (tar.gz, zip, etc.)
- `Git`: Git repository with specific commit
- `Local`: Local filesystem path (for development)

### ArchiveFormat

Archive format enumeration for HTTP repositories:

- `Auto`: Auto-detect from URL/content
- `TarGz`: .tar.gz
- `Tar`: .tar
- `Zip`: .zip
- `TarXz`: .tar.xz
- `TarBz2`: .tar.bz2

### CachedRepository

Metadata for cached repositories:

```d
struct CachedRepository {
    string name;                    // Repository name
    string cacheKey;               // Cache key
    string localPath;              // Path in cache directory
    SysTime fetchedAt;             // When it was fetched
    size_t size;                   // Size in bytes
    string[] files;                // List of files (for dependency tracking)
}
```

### ResolvedRepository

Result of repository resolution:

```d
struct ResolvedRepository {
    string name;                   // Repository name
    string path;                   // Absolute path to repository root
    RepositoryRule rule;          // Original rule
}
```

### RepositoryError

Custom error type for repository operations:

```d
final class RepositoryError : BaseBuildError {
    this(string message, ErrorCode code = ErrorCode.RepositoryError);
    override ErrorCategory category() const;
    override bool recoverable() const;
}
```

## Usage

This module is typically imported through the parent `infrastructure.repository` module:

```d
import infrastructure.repository;

// Define a repository rule
auto rule = RepositoryRule(
    "llvm",
    RepositoryKind.Http,
    "https://github.com/llvm/llvm-project/releases/...",
    "abc123...",
    ArchiveFormat.TarXz,
    "llvm-17.0.1",
    null,
    null,
    null
);

// Validate the rule
auto result = rule.validate();
if (result.isErr) {
    // Handle validation error
}
```

## Design Principles

1. **Immutability**: Types are designed to be immutable where possible
2. **Validation**: Built-in validation methods ensure data integrity
3. **Type Safety**: Strong typing prevents misuse
4. **Self-Documenting**: Comprehensive inline documentation

## Dependencies

- `std.datetime`: For timestamp handling
- `infrastructure.errors`: For error handling types

## See Also

- [Repository Rules System](../README.md) - System overview
- [Acquisition Module](../acquisition/README.md) - Fetching and verification
- [Storage Module](../storage/README.md) - Cache management
- [Resolution Module](../resolution/README.md) - Reference resolution

