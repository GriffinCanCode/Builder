# Builder - Smart Build System

A high-performance build system for mixed-language monorepos, leveraging D's compile-time metaprogramming for dependency analysis.

## Features

- **Compile-time Dependency Analysis**: Uses D's metaprogramming to analyze dependencies at compile-time
- **Multi-language Support**: Python, JavaScript, TypeScript, Go, Rust, C/C++, and more
- **Incremental Builds**: Smart caching and change detection
- **Parallel Execution**: Efficient task scheduling and parallel builds
- **Monorepo Optimized**: Designed for large-scale monorepos with complex dependencies

## Architecture

```
source/
├── app.d                    # CLI entry point
├── core/                    # Core build system
│   ├── graph.d             # Build graph representation
│   ├── cache.d             # Caching system
│   └── executor.d          # Build execution engine
├── analysis/                # Dependency analysis
│   ├── analyzer.d          # Main analyzer with metaprogramming
│   ├── scanner.d           # File scanning and change detection
│   └── resolver.d          # Dependency resolution
├── languages/               # Language-specific handlers
│   ├── base.d              # Base language interface
│   ├── python.d            # Python support
│   ├── javascript.d        # JavaScript/TypeScript support
│   ├── go.d                # Go support
│   └── rust.d              # Rust support
├── config/                  # Configuration management
│   ├── parser.d            # Config file parser
│   └── schema.d            # Build configuration schema
└── utils/                   # Utilities
    ├── hash.d              # Fast hashing for cache keys
    ├── parallel.d          # Parallel execution utilities
    └── logger.d            # Logging system
```

## Installation

```bash
# Install D compiler (LDC)
brew install ldc dub

# Build the project
dub build

# Run
./bin/builder
```

## Usage

```bash
# Build all targets
builder build

# Build specific target
builder build //path/to:target

# Clean build cache
builder clean

# Show dependency graph
builder graph
```

## Configuration

Create a `BUILD` file in your project directories:

```d
// BUILD
target("my-library",
    type: TargetType.Library,
    sources: ["src/**/*.py"],
    deps: ["//common:utils"]
);

target("my-binary",
    type: TargetType.Executable,
    sources: ["main.py"],
    deps: [":my-library"]
);
```

## Why D?

- **Compile-time Metaprogramming**: Analyze dependencies without runtime overhead
- **Performance**: Native compilation with LLVM backend
- **Memory Safety**: @safe by default with opt-in unsafe code
- **Modern Language**: Ranges, UFCS, mixins, and more
- **C/C++ Interop**: Easy integration with existing tools

## License

MIT

