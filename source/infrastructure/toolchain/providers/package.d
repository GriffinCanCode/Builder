module infrastructure.toolchain.providers;

/// Toolchain Provider System
/// 
/// This module provides mechanisms for fetching and provisioning toolchains
/// from various sources, including local filesystem, remote repositories,
/// and package managers.
/// 
/// ## Modules
/// 
/// - `providers` - Toolchain provider implementations (Local, Repository-based)
/// 
/// ## Usage
/// 
/// ```d
/// // Local toolchain provider
/// auto provider = new LocalToolchainProvider("/opt/toolchains/gcc-11");
/// auto result = provider.provide();
/// 
/// // Repository-based provider
/// auto repoProvider = new RepositoryToolchainProvider(repositoryRule);
/// auto toolchains = repoProvider.provide();
/// ```

public import infrastructure.toolchain.providers.providers;

