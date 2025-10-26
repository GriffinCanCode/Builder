module utils.crypto;

/// Cryptographic utilities module
/// 
/// This module provides high-performance hashing via BLAKE3,
/// offering 3-5x speedup over SHA-256 for build system operations.

public import utils.crypto.blake3;
public import utils.crypto.blake3_bindings;

