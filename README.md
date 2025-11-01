# Builder

A high-performance build system for mixed-language monorepos, leveraging D's compile-time metaprogramming for zero-cost abstractions and type-safe dependency analysis.

## Features

- **Modern DSL**: Clean, readable Builderfile syntax with comprehensive error messages and IDE integration
- **BLAKE3 Hashing**: 3-5x faster than SHA-256 with SIMD acceleration (AVX2/AVX-512/NEON)
- **SIMD Acceleration**: Hardware-agnostic runtime dispatch with 2-6x performance improvements
- **Compile-time Code Generation**: Uses D's metaprogramming to generate optimized analyzers with zero runtime overhead
- **Type-Safe Error Handling**: Result monad with rich error context, automatic retry logic, and recovery strategies
- **Error Recovery**: Circuit breaker pattern with exponential backoff, build checkpointing, and smart resumption
- **Event-Driven CLI**: Multiple render modes (interactive, plain, verbose, quiet) with lock-free progress tracking
- **Build Telemetry**: Comprehensive analytics, bottleneck identification, and performance regression detection
- **Query Language**: Powerful Bazel inspired query syntax for exploring dependencies and target relationships
- **Extensive Multi-language Support**: 26+ languages including Python, JavaScript/TypeScript, Elm, Go, Rust, C/C++, Java, Kotlin, C#, Zig, Swift, Ruby, Perl, PHP, R, Scala, Elixir, Nim, Lua, OCaml, Haskell, and D
- **Incremental Builds**: Smart caching with BLAKE3 content hashing and configurable eviction policies
- **Action-Level Caching**: Fine-grained caching for individual build steps (compile, link, test) with 2-3x better cache utilization
- **Parallel Execution**: Wave-based parallel builds with thread pool management and optimal CPU utilization
- **Monorepo Optimized**: Efficient workspace scanning and dependency resolution for large-scale repos

## Architecture

```
source/
├── app.d                    # CLI entry point
├── core/                    # Build execution engine
│   ├── graph/              # Dependency graph and topological sorting
│   ├── execution/          # Task execution, parallelization, checkpointing, retry
│   ├── caching/            # Two-tier caching: target-level and action-level
│   └── telemetry/          # Build analytics, bottleneck detection, trends
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
│   ├── compiled/           # Rust, C++, D, Nim, Zig, OCaml
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
│   ├── crypto/             # BLAKE3 C bindings with SIMD dispatch
│   ├── simd/               # Hardware-agnostic SIMD acceleration (AVX2/AVX-512/NEON)
│   ├── files/              # Glob, BLAKE3 hashing, chunking, metadata
│   ├── concurrency/        # Parallel processing and thread pools
│   ├── security/           # Memory safety, sandboxing, validation
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

# Resume failed build (with checkpointing)
builder resume

# Query targets and dependencies
builder query '//...'                    # List all targets
builder query 'deps(//src:app)'          # Show dependencies
builder query 'rdeps(//lib:utils)'       # Show reverse dependencies
builder query 'kind(binary, //...)'      # Filter by type

# View build analytics and performance metrics
builder telemetry

# Show recent builds with bottleneck analysis
builder telemetry recent 10

# Clean build cache and checkpoints
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

## Performance

Builder is engineered for speed with multiple layers of optimization:

### BLAKE3 Hashing
- **3-5x faster** than SHA-256 across all file sizes
- Full build: 33% faster | Incremental: 60% faster | Cache validation: 75% faster
- Cryptographically secure with 128-bit collision resistance

### SIMD Acceleration
- **Hardware-agnostic** runtime dispatch (AVX-512/AVX2/NEON/SSE4.1/SSE2)
- **2-6x performance improvements** for hashing and memory operations
- Automatic CPU feature detection with fallback chains
- Throughput: 600 MB/s (portable) → 3.6 GB/s (AVX-512)

### Error Recovery
- **Automatic retry** with exponential backoff for transient failures
- **Build checkpointing** saves successful work on failures
- **Smart resumption** rebuilds only affected targets
- Time savings: 45-88% when resuming from mid-build failures

### Telemetry & Analytics
- **Real-time performance tracking** with < 0.5% overhead
- **Bottleneck identification** and regression detection
- **Build optimization insights** for continuous improvement
- Binary format: 4-5x faster than JSON, 30% smaller

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

See [docs/development/TESTING.md](docs/development/TESTING.md) for complete testing guide.

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

## 📚 Documentation

### API Documentation

Auto-generated API documentation is available:

```bash
# Generate and view documentation
make docs-open

# Or generate and serve on localhost:8000
make docs-serve
```

View online: [API Documentation](docs/api/index.html)

- **517 modules** documented
- **83.6% coverage** with DDoc comments
- Organized by package with search-friendly structure
- Includes safety documentation for all `@trusted` blocks

### Architecture & Design
- [Architecture Guide](docs/architecture/ARCHITECTURE.md) - System design and internals
- [DSL Specification](docs/architecture/DSL.md) - Builderfile DSL syntax and semantics

### User Guides
- [CLI Guide](docs/user-guides/CLI.md) - Command-line interface reference
- [Examples](docs/user-guides/EXAMPLES.md) - Usage examples and tutorials
- [Builderignore](docs/user-guides/BUILDERIGNORE.md) - File exclusion patterns

### Implementation Details
- [BLAKE3 Integration](docs/implementation/BLAKE3.md) - 3-5x faster hashing
- [SIMD Acceleration](docs/implementation/SIMD.md) - Hardware-agnostic performance
- [Error Recovery](docs/implementation/RECOVERY.md) - Retry and checkpointing system
- [Telemetry](docs/implementation/TELEMETRY.md) - Build analytics and monitoring
- [Performance Guide](docs/implementation/PERFORMANCE.md) - Optimization strategies
- [Concurrency](docs/implementation/CONCURRENCY.md) - Parallel execution details

### Security & Development
- [Security Guide](docs/security/SECURITY.md) - Security practices and guidelines
- [Memory Safety Audit](docs/security/MEMORY_SAFETY_AUDIT.md) - Safety analysis
- [Testing Guide](docs/development/TESTING.md) - Testing infrastructure

## Why D?

- **True Compile-time Metaprogramming**: Generate code, validate types, and optimize dispatch at compile-time using templates, mixins, and CTFE
- **Zero-Cost Abstractions**: Strong typing and metaprogramming compiled away to optimal machine code
- **Performance**: Native compilation with LLVM backend (LDC), comparable to C++ speed
- **Memory Safety**: @safe by default with compile-time verification
- **Modern Language**: Ranges, UFCS, templates, mixins, static introspection, and compile-time function execution
- **C/C++ Interop**: Seamless integration with existing build tools and libraries

## License

Griffin License v1.0 - See [LICENSE](LICENSE) for full terms.

Key terms:
- ✅ Free to use, modify, and distribute
- ✅ Commercial use permitted
- ⚠️ Attribution required: "Griffin" must be credited in all derivative works
- 🚫 No patents or trademarks on concepts contained herein

