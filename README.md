# Builder - Smart Build System

A high-performance build system for mixed-language monorepos, leveraging D's compile-time metaprogramming for zero-cost abstractions and type-safe dependency analysis.

## Features

- **Compile-time Code Generation**: Uses D's metaprogramming to generate optimized analyzers at compile-time with zero runtime overhead
- **Strongly Typed Domain**: Type-safe Import, Dependency, and Analysis types eliminate runtime errors
- **Multi-language Support**: Python, JavaScript, TypeScript, Go, Rust, C/C++, D, Java with pluggable architecture
- **Incremental Builds**: Smart caching with SHA-256 content hashing
- **Parallel Execution**: Wave-based parallel builds respecting dependency order
- **Monorepo Optimized**: O(1) import resolution with indexed lookups for large-scale repos

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

- **True Compile-time Metaprogramming**: Generate code, validate types, and optimize dispatch at compile-time using templates, mixins, and CTFE
- **Zero-Cost Abstractions**: Strong typing and metaprogramming compiled away to optimal machine code
- **Performance**: Native compilation with LLVM backend (LDC), comparable to C++ speed
- **Memory Safety**: @safe by default with compile-time verification
- **Modern Language**: Ranges, UFCS, templates, mixins, static introspection, and compile-time function execution
- **C/C++ Interop**: Seamless integration with existing build tools and libraries

## License

MIT

