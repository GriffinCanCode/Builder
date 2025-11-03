module infrastructure.repository.acquisition;

/// Acquisition Module
/// 
/// Handles downloading and verifying external repositories.
/// 
/// Components:
/// - RepositoryFetcher: Downloads repositories via HTTP/Git/Local
/// - IntegrityVerifier: Cryptographic verification using BLAKE3
/// 
/// Features:
/// - HTTP downloads with retry logic and exponential backoff
/// - Archive extraction (tar.gz, zip, tar.xz, tar.bz2)
/// - Git clone with commit/tag pinning
/// - Local filesystem validation
/// - BLAKE3/SHA256 integrity verification

public import infrastructure.repository.acquisition.fetcher;
public import infrastructure.repository.acquisition.verifier;

