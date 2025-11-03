# Toolchain Integration Example

This example demonstrates the unified toolchain system with repository-based external toolchain fetching.

## Overview

The toolchain system provides:
- **Unified Detection**: Auto-detect GCC, Clang, Rust, Go, Python, Node, Java, Zig, D, and more
- **Version Constraints**: Specify toolchain requirements like `gcc@>=11.0.0` or `clang@15.x`
- **Remote Toolchains**: Fetch toolchains from HTTP archives or Git repositories
- **Cross-Compilation**: Platform-aware toolchain selection with sysroot support
- **Manifest-Based**: Declare custom toolchains via JSON manifests
- **Content-Addressable**: Cached fetching with cryptographic verification

## Example Manifest

See `example-manifest.json` for a custom toolchain definition. The manifest format supports:

```json
{
  "toolchains": [{
    "name": "custom-gcc",
    "version": "11.3.0",
    "host": "x86_64-unknown-linux-gnu",
    "target": "x86_64-unknown-linux-gnu",
    "tools": [{
      "name": "gcc",
      "path": "bin/gcc",
      "type": "compiler",
      "capabilities": ["lto", "optimization"]
    }],
    "env": {"CC": "gcc"},
    "sysroot": "sysroot"
  }]
}
```

## Usage

### Auto-Detection

```d
// In your Builderfile:
target("app") {
    type: executable;
    sources: ["main.cpp"];
    // Toolchain auto-detected from system
}
```

### Version Constraints

```d
target("app") {
    type: executable;
    toolchain: "gcc@>=11.0.0";
    sources: ["main.cpp"];
}
```

### Remote Toolchain

```d
repository("gcc-11") {
    url: "https://example.com/gcc-11.3.0.tar.xz";
    integrity: "blake3:abc123...";
}

target("app") {
    type: executable;
    toolchain: "@gcc-11//:gcc";
    sources: ["main.cpp"];
}
```

### Cross-Compilation

```d
target("arm-app") {
    type: executable;
    platform: "aarch64-unknown-linux-gnu";
    toolchain: "@toolchains//arm:gcc-aarch64";
    sources: ["main.cpp"];
}
```

## Architecture

### Components

1. **Platform** (`platform.d`): OS + Arch + ABI triples
2. **Spec** (`spec.d`): Toolchain/Tool specifications with capabilities
3. **Detector** (`detector.d`, `detectors.d`): Auto-detection of installed tools
4. **Registry** (`registry.d`): Central singleton registry
5. **Providers** (`providers.d`): Local and remote toolchain providers
6. **Constraints** (`constraints.d`): Version constraint solving

### Detection

The system auto-detects:
- **C/C++**: GCC, Clang, MSVC, Intel ICC
- **Rust**: rustc, cargo
- **Go**: go, gofmt
- **Python**: python3, pip
- **Node.js**: node, npm, npx
- **Java**: java, javac
- **Zig**: zig
- **D**: DMD, LDC, GDC, dub
- **Build Tools**: CMake, Ninja

### Capabilities

Tools can advertise capabilities:
- `CrossCompile`: Cross-compilation support
- `LTO`: Link-time optimization
- `PGO`: Profile-guided optimization
- `Incremental`: Incremental compilation
- `Sanitizers`: AddressSanitizer, ThreadSanitizer, etc.
- `StaticAnalysis`: Built-in static analysis
- `Hermetic`: Hermetic build support

## Integration

Language handlers use the unified system via:

```d
import toolchain;

// Get toolchain
auto registry = ToolchainRegistry.instance();
registry.initialize();

// Auto-detect for platform
auto result = registry.findFor(Platform.host(), ToolchainType.Compiler);
if (result.isOk) {
    auto tc = result.unwrap();
    auto compiler = tc.compiler();
    // Use compiler.path, compiler.version_, etc.
}

// With constraints
auto constraint = ToolchainConstraint.parse("gcc@>=11.0.0").unwrap();
auto matchResult = registry.findMatching(constraint);
```

## Benefits

1. **No Duplication**: Single detection logic for all languages
2. **Consistent API**: Same interface across C++, Rust, D, Go, etc.
3. **Extensible**: Easy to add new toolchain detectors
4. **Testable**: Mock toolchains for testing
5. **Remote Fetch**: Download toolchains on-demand with caching
6. **Type-Safe**: Strong typing with Result types
7. **Zero Tech Debt**: Clean, focused modules

## See Also

- `/source/toolchain/` - Implementation
- `/docs/architecture/` - Architecture documentation
- `/examples/cross-compile/` - Cross-compilation examples

