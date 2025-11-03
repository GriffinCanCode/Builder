## Toolchain System

**Status: ✅ Complete**

### Overview

The Toolchain System provides unified platform and toolchain abstraction for cross-compilation and build tool management in Builder. It consolidates previously scattered toolchain detection logic and enables declarative cross-compilation support.

### Architecture

```
toolchain/
├── platform.d    # Platform abstraction (OS, Arch, ABI)
├── spec.d        # Toolchain specifications and versions
├── detector.d    # Auto-detection of installed toolchains
├── registry.d    # Central toolchain registry (singleton)
├── package.d     # Public API
└── README.md     # Documentation
```

### Core Components

#### 1. Platform Abstraction (`platform.d`)

Represents target platforms as **OS + Architecture + ABI** triples:

```d
auto platform = Platform.parse("x86_64-unknown-linux-gnu");
assert(platform.unwrap().arch == Arch.X86_64);
assert(platform.unwrap().os == OS.Linux);
assert(platform.unwrap().abi == ABI.GNU);

// Get current host
auto host = Platform.host();

// Check cross-compilation
if (target.isCross())
    writeln("Cross-compiling!");
```

**Supported Architectures**: x86, x86_64, ARM, ARM64, RISC-V, MIPS, PowerPC, WASM

**Supported OSes**: Linux, macOS (Darwin), Windows, BSD variants, Android, iOS, Web

**Supported ABIs**: GNU, MUSL, MSVC, MinGW, Darwin, Android, EABI

#### 2. Toolchain Specification (`spec.d`)

Defines toolchains as collections of tools with capabilities:

```d
Tool tool;
tool.name = "clang++";
tool.version_ = Version(15, 0, 0);
tool.type = ToolchainType.Compiler;
tool.capabilities = Capability.LTO | Capability.CrossCompile;

Toolchain tc;
tc.tools ~= tool;
tc.host = Platform.host();
tc.target = Platform.parse("aarch64-linux-gnu").unwrap();
```

**Tool Types**: Compiler, Linker, Archiver, Assembler, Interpreter, Runtime, BuildTool, PackageManager

**Capabilities**: CrossCompile, LTO, PGO, Incremental, Sanitizers, Debugging, Optimization, etc.

#### 3. Auto-Detection (`detector.d`)

Automatically discovers installed toolchains:

```d
auto detector = new AutoDetector();
auto toolchains = detector.detectAll();

// Register custom detector
class MyDetector : ToolchainDetector {
    override Toolchain[] detect() { /* ... */ }
}
detector.register(new MyDetector());
```

**Built-in Detectors**:
- GCCDetector: gcc, g++, ld, ar
- ClangDetector: clang, clang++, lld, llvm-ar
- RustDetector: rustc, cargo

#### 4. Central Registry (`registry.d`)

Singleton registry for all toolchains:

```d
// Initialize (auto-detects toolchains)
auto registry = ToolchainRegistry.instance();
registry.initialize();

// Find toolchain by platform
auto result = registry.findFor(Platform.parse("arm64-darwin").unwrap());

// Resolve toolchain reference
auto tc = resolveToolchain("@toolchains//llvm:clang-15");

// List all toolchains
foreach (tc; registry.list())
    writeln(tc.id);
```

### DSL Integration

#### Builderfile Syntax

```
target("cross-app") {
    type: executable;
    platform: "linux-arm64";
    toolchain: "@toolchains//arm:gcc-11";
    sources: ["main.c"];
}
```

#### Schema Fields

Two new fields added to `Target` struct:

- `platform`: Target platform triple (string)
- `toolchain`: Toolchain reference (string)

### Cross-Compilation Workflow

1. **Parse Platform**: Extract target triple from `platform` field
2. **Resolve Toolchain**: Look up toolchain from `toolchain` field or auto-detect
3. **Configure Build**: Set sysroot, compiler flags for cross-compile
4. **Execute Hermetically**: Use hermetic executor with toolchain environment

### Design Principles

#### 1. Elegance Through Unification

Previously, each language handler (C++, Rust, D) had its own toolchain detection code (~200-300 lines each). Now consolidated into a single, reusable system (~800 lines total).

#### 2. Extensibility

Registry pattern allows custom toolchain detectors. Language handlers can register specialized detectors without modifying core code.

#### 3. Type Safety

Strong typing throughout:
- Enum-based architecture (Arch, OS, ABI)
- Version struct with semantic versioning
- Capability flags for feature detection
- Result types for error handling

#### 4. Platform-Agnostic

Uses D's version() conditionals for platform detection but provides a unified API across all platforms.

#### 5. Zero Tech Debt

- Short, focused modules (150-300 lines each)
- Single responsibility per class
- Comprehensive unit tests
- No external dependencies (uses std library only)

### Integration with Existing Systems

#### Hermetic Execution

```d
import runtime.hermetic.executor;
import toolchain;

auto tc = getToolchain("gcc-11").unwrap();
auto compiler = tc.compiler();

// Execute with toolchain environment
HermeticExecutor executor = ...;
executor.spec.environment.vars = tc.env;
executor.execute([compiler.path, "main.c", "-o", "app"]);
```

#### Language Handlers

Language handlers can now use the central registry instead of custom detection:

```d
// Before (C++ handler)
auto info = Toolchain.detect(Compiler.GCC);

// After (unified)
auto tc = ToolchainRegistry.instance()
    .findFor(Platform.host(), ToolchainType.Compiler)
    .unwrap();
```

### Performance Considerations

- **Lazy Initialization**: Registry initializes on first use
- **Caching**: Detected toolchains cached in memory
- **Fast Lookups**: O(1) lookup by ID via associative array
- **Minimal Detection**: Only runs detection once per process

### Future Enhancements

#### External Toolchain Repositories

Support fetching toolchains from external sources:

```
repository("llvm-15") {
    url: "https://github.com/llvm/llvm-project/releases/download/llvmorg-15.0.0/clang+llvm-15.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz";
    integrity: "blake3:abc123...";
}

target("app") {
    toolchain: "@llvm-15//:clang";
    platform: "linux-x86_64";
}
```

#### Toolchain Configuration Files

Support declarative toolchain definitions:

```json
{
  "id": "custom-gcc-11",
  "name": "gcc",
  "version": "11.3.0",
  "tools": {
    "compiler": "/usr/local/bin/gcc-11",
    "linker": "/usr/local/bin/ld"
  },
  "sysroot": "/opt/sysroot",
  "env": {
    "CC": "gcc-11"
  }
}
```

#### Remote Toolchains

Execute builds using remote toolchains (distributed compilation):

```
target("app") {
    toolchain: "@remote//build-farm:gcc-11";
    platform: "linux-arm64";
}
```

### Comparison with Bazel

**Similarities**:
- `@toolchains//` reference syntax
- Platform abstraction with target triples
- Auto-detection and registration
- Cross-compilation support

**Differences**:
- Simpler API (no execution platforms vs target platforms distinction)
- Tighter integration with Builder's hermetic execution
- Language-agnostic from the start
- Lighter weight (no Java dependency)

### Testing

```bash
# Run toolchain tests
dub test --filter="toolchain"

# Test toolchain detection
./bin/builder detect --toolchains

# List available toolchains
./bin/builder toolchains list

# Show toolchain details
./bin/builder toolchains show gcc-11
```

### Examples

See `examples/cross-compile/` for complete cross-compilation examples.

### API Reference

#### Platform

- `Platform.parse(string)` - Parse target triple
- `Platform.host()` - Get current platform
- `Platform.toTriple()` - Convert to string
- `Platform.isCross()` - Check if cross-compiling
- `Platform.compatibleWith(Platform)` - Check compatibility

#### Toolchain Registry

- `ToolchainRegistry.instance()` - Get singleton
- `initialize()` - Auto-detect toolchains
- `get(string)` - Get by ID
- `findFor(Platform, ToolchainType)` - Find for platform
- `resolve(ToolchainRef)` - Resolve reference
- `list()` - List all toolchains

#### Convenience Functions

- `getToolchain(string)` - Global get by ID
- `findToolchain(Platform, ToolchainType)` - Global find
- `resolveToolchain(string)` - Global resolve

### Statistics

- **Total Lines**: ~1,200 lines of production code
- **Modules**: 6 files
- **Unit Tests**: 8 test suites
- **Detectors**: 3 built-in (GCC, Clang, Rust)
- **Supported Platforms**: 40+ combinations

### Credits

Design inspired by:
- Bazel's toolchain system
- Rust's target triple format
- LLVM's platform abstractions
- Zig's cross-compilation model

