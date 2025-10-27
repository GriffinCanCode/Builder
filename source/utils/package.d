module utils;

/// Utilities Package
/// Common utilities for file handling, parallelization, cryptography, and benchmarking
/// 
/// Architecture:
///   glob.d      - Glob pattern matching
///   hash.d      - File hashing and checksums (now uses BLAKE3)
///   ignore.d    - Ignore patterns for dependency and build directories
///   parallel.d  - Parallel processing utilities
///   pool.d      - Thread pool implementation
///   chunking.d  - File chunking utilities
///   logger.d    - Logging infrastructure
///   metadata.d  - File metadata handling
///   bench.d     - Benchmarking utilities
///   blake3.d    - BLAKE3 cryptographic hashing (3-5x faster than SHA-256)
///   pycheck.d   - Python validation
///   pywrap.d    - Python wrapper utilities
///   validation.d - Security validation for paths and command arguments
///   process.d   - Process and tool availability checking utilities
///
/// Usage:
///   import utils;
///   
///   auto files = glob("src/**/*.d");
///   auto hash = hashFile("source.d");  // Uses BLAKE3 with SIMD automatically
///   
///   auto pool = new ThreadPool(4);
///   pool.submit({ /* work */ });
///   
///   // SIMD operations
///   CPU.printInfo();              // Show CPU capabilities
///   SIMDOps.copy(dest, src);      // Fast SIMD memcpy
///   SIMDBench.compareAll();       // Benchmark SIMD implementations

public import utils.files.glob;
public import utils.files.hash;
public import utils.files.ignore;
public import utils.concurrency.parallel;
public import utils.concurrency.pool;
public import utils.concurrency.simd;
public import utils.concurrency.lockfree;
public import utils.files.chunking;
public import utils.logging.logger;
public import utils.files.metadata;
public import utils.benchmarking.bench;
public import utils.crypto.blake3;
public import utils.python.pycheck;
public import utils.python.pywrap;
public import utils.simd;
public import utils.security.validation;
public import utils.process;

