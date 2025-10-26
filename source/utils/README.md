# Utils Package

The utils package provides common utilities for file handling, parallelization, hashing, and benchmarking used throughout the Builder system.

## Modules

- **glob.d** - Glob pattern matching for file selection
- **hash.d** - Fast file hashing with SHA-256
- **parallel.d** - Parallel processing utilities
- **pool.d** - Thread pool implementation
- **chunking.d** - File chunking for parallel processing
- **logger.d** - Structured logging infrastructure
- **metadata.d** - File metadata and timestamps
- **bench.d** - Performance benchmarking utilities
- **pycheck.d** - Python environment validation
- **pywrap.d** - Python integration wrapper

## Usage

```d
import utils;

auto files = glob("src/**/*.d");
auto hash = hashFile("source.d");

auto pool = new ThreadPool(4);
pool.submit({ /* work */ });

Logger.info("Build completed");
```

## Key Features

- Fast glob matching with pattern compilation
- Content-based hashing for cache keys
- Work-stealing thread pool
- Structured logging with levels
- File chunking for parallel I/O
- Python environment detection and validation

