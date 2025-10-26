# Builder - Smart Build System

A high-performance build system for mixed-language monorepos, leveraging D's compile-time metaprogramming for zero-cost abstractions and type-safe dependency analysis.

## Features

- **Modern DSL**: Clean, readable D-based DSL for BUILD files with comprehensive error messages
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
│   ├── lexer.d             # DSL tokenization
│   ├── ast.d               # AST node types
│   ├── dsl.d               # DSL parser and semantic analysis
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

Create a `BUILD` file in your project directories using the modern DSL syntax:

```d
// BUILD file - Clean DSL syntax
target("my-library") {
    type: library;
    sources: ["src/**/*.py"];
    deps: ["//common:utils"];
}

target("my-binary") {
    type: executable;
    sources: ["main.py"];
    deps: [":my-library"];
}
```

The system also supports legacy JSON format (`BUILD.json`) with automatic detection.

## Testing

Builder has a comprehensive test infrastructure:

```bash
# Run all tests
dub test

# Run with script (includes coverage)
./run-tests.sh --verbose --coverage

# Run specific tests
dub test -- --filter="glob"

# Parallel execution
dub test -- --parallel
```

See [docs/TESTING.md](docs/TESTING.md) for complete testing guide.

## Development

### Project Structure

- `source/` - Main source code
- `tests/` - Comprehensive test suite
  - `unit/` - Unit tests mirroring source/
  - `integration/` - Integration tests
  - `bench/` - Performance benchmarks
- `docs/` - Documentation
- `examples/` - Example projects

### Running Tests

```bash
# Quick test
dub test

# With coverage
./run-tests.sh --coverage

# Verbose output
./run-tests.sh --verbose
```

## Documentation

- [Architecture Guide](docs/ARCHITECTURE.md) - System design and internals
- [DSL Specification](docs/DSL.md) - BUILD file DSL syntax and semantics
- [Testing Guide](docs/TESTING.md) - How to write and run tests
- [Examples](docs/EXAMPLES.md) - Usage examples

## Why D?

- **True Compile-time Metaprogramming**: Generate code, validate types, and optimize dispatch at compile-time using templates, mixins, and CTFE
- **Zero-Cost Abstractions**: Strong typing and metaprogramming compiled away to optimal machine code
- **Performance**: Native compilation with LLVM backend (LDC), comparable to C++ speed
- **Memory Safety**: @safe by default with compile-time verification
- **Modern Language**: Ranges, UFCS, templates, mixins, static introspection, and compile-time function execution
- **C/C++ Interop**: Seamless integration with existing build tools and libraries

## License

MIT

