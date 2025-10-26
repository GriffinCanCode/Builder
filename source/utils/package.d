module utils;

/// Utilities Package
/// Common utilities for file handling, parallelization, and benchmarking
/// 
/// Architecture:
///   glob.d      - Glob pattern matching
///   hash.d      - File hashing and checksums
///   parallel.d  - Parallel processing utilities
///   pool.d      - Thread pool implementation
///   chunking.d  - File chunking utilities
///   logger.d    - Logging infrastructure
///   metadata.d  - File metadata handling
///   bench.d     - Benchmarking utilities
///   pycheck.d   - Python validation
///   pywrap.d    - Python wrapper utilities
///
/// Usage:
///   import utils;
///   
///   auto files = glob("src/**/*.d");
///   auto hash = hashFile("source.d");
///   
///   auto pool = new ThreadPool(4);
///   pool.submit({ /* work */ });

public import utils.files.glob;
public import utils.files.hash;
public import utils.concurrency.parallel;
public import utils.concurrency.pool;
public import utils.files.chunking;
public import utils.logging.logger;
public import utils.files.metadata;
public import utils.benchmarking.bench;
public import utils.python.pycheck;
public import utils.python.pywrap;

