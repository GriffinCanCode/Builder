# Builder - Smart Build System

A high-performance build system for mixed-language monorepos, leveraging D's compile-time metaprogramming for zero-cost abstractions and type-safe dependency analysis.

## Features

- **Modern DSL**: Clean, readable Builderfile syntax with comprehensive error messages and IDE integration
- **Compile-time Code Generation**: Uses D's metaprogramming to generate optimized analyzers with zero runtime overhead
- **Type-Safe Error Handling**: Result monad with rich error context, recovery strategies, and formatted diagnostics
- **Event-Driven CLI**: Multiple render modes (interactive, plain, verbose, quiet) with lock-free progress tracking
- **Extensive Multi-language Support**: 20+ languages including Python, JavaScript/TypeScript, Go, Rust, C/C++, Java, Kotlin, C#, Zig, Swift, Ruby, PHP, R, Scala, Elixir, Nim, Lua, and D
- **Incremental Builds**: Smart caching with SHA-256 content hashing and configurable eviction policies
- **Parallel Execution**: Wave-based parallel builds with thread pool management
- **Monorepo Optimized**: Efficient workspace scanning and dependency resolution for large-scale repos

## Architecture

```
source/
├── app.d                    # CLI entry point
├── core/                    # Build execution engine
│   ├── graph/              # Dependency graph and topological sorting
│   ├── execution/          # Task execution and parallelization
│   └── caching/            # Build cache with storage and eviction
├── analysis/                # Dependency analysis and resolution
│   ├── inference/          # Build target analysis
│   ├── scanning/           # File and dependency scanning
│   ├── resolution/         # Dependency resolution logic
│   ├── targets/            # Target types and specifications
│   └── metadata/           # Metadata generation
├── config/                  # Configuration and workspace management
│   ├── parsing/            # Lexer and parser for Builderfile
│   ├── interpretation/     # DSL semantic analysis
│   ├── workspace/          # AST and workspace handling
│   └── schema/             # Configuration schema
├── languages/               # Multi-language support (20+ languages)
│   ├── base/               # Base language interface
│   ├── scripting/          # Python, JS, TS, Go, Ruby, PHP, R, Lua, Elixir
│   ├── compiled/           # Rust, C++, D, Nim, Zig
│   ├── jvm/                # Java, Kotlin, Scala
│   └── dotnet/             # C#, Swift
├── cli/                     # Event-driven CLI rendering
│   ├── events/             # Strongly-typed build events
│   ├── control/            # Terminal control and capabilities
│   ├── output/             # Progress tracking and stream management
│   └── display/            # Message formatting and rendering
├── errors/                  # Type-safe error handling
│   ├── handling/           # Result monad, error codes, recovery
│   ├── types/              # Error type definitions
│   ├── context/            # Error context chains
│   ├── formatting/         # Rich error formatting
│   └── adaptation/         # Error adaptation utilities
├── utils/                   # Common utilities
│   ├── files/              # Glob, hashing, chunking, metadata
│   ├── concurrency/        # Parallel processing and thread pools
│   ├── logging/            # Logging infrastructure
│   ├── benchmarking/       # Performance benchmarking
│   └── python/             # Python validation and wrappers
└── tools/                   # Developer tooling
    └── vscode/             # VS Code extension integration
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

# Build with specific CLI mode
builder build --mode interactive

# Clean build cache
builder clean

# Show dependency graph
builder graph

# Initialize new Builderfile
builder init

# Install VS Code extension
builder install-extension
```

## Configuration

Create a `Builderfile` in your project directories using the DSL syntax:

```d
// Builderfile - Clean DSL syntax
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

## IDE Integration

### VS Code Extension

Builder includes a VS Code extension for enhanced editing experience:

**Features:**
- Syntax highlighting for `Builderfile` and `Builderspace`
- Auto-closing brackets and quotes
- Comment toggling (Cmd+/)
- Code folding and bracket matching
- Custom file icons

**Installation:**
```bash
# Using Builder CLI (recommended)
builder install-extension

# Or manually
code --install-extension tools/vscode/builder-lang-1.0.0.vsix
```

After installation, reload VS Code: `Cmd+Shift+P` → "Developer: Reload Window"

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
- [CLI Guide](docs/CLI.md) - CLI modes and rendering system
- [DSL Specification](docs/DSL.md) - Builderfile DSL syntax and semantics
- [Testing Guide](docs/TESTING.md) - How to write and run tests
- [Performance Guide](docs/PERFORMANCE.md) - Optimization and benchmarking
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

