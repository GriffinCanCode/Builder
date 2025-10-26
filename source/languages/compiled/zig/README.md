# Zig Language Support

Comprehensive Zig build support with build.zig integration, cross-compilation, and advanced tooling.

## Architecture

```
source/languages/compiled/zig/
├── package.d          # Public exports and convenience aliases
├── core/              # Core build logic
│   ├── package.d      # Core exports
│   ├── handler.d      # Main build handler
│   └── config.d       # Configuration types and enums
├── builders/          # Build strategies
│   ├── package.d      # Builder exports
│   ├── base.d         # Builder interface and factory
│   ├── build.d        # build.zig builder
│   └── compile.d      # Direct zig compile builder
├── analysis/          # Project analysis
│   ├── package.d      # Analysis exports
│   ├── builder.d      # build.zig parser and integration
│   └── targets.d      # Cross-compilation target management
├── tooling/           # Zig tooling integration
│   ├── package.d      # Tooling exports
│   └── tools.d        # Zig tooling (fmt, check, zen, etc.)
└── README.md          # This file
```

## Features

### Core Capabilities

- **Dual Build Modes**: Support for both build.zig (full project) and direct compile (single file)
- **build.zig Integration**: Automatic detection and parsing of build.zig projects
- **Cross-Compilation**: Comprehensive target triple support with automatic detection
- **Optimization Modes**: Debug, ReleaseSafe, ReleaseFast, ReleaseSmall
- **Output Types**: Executable, static library, dynamic library, object files
- **Package Management**: build.zig.zon support with dependency tracking

### Advanced Features

- **Zig Formatter Integration**: Automatic code formatting with zig fmt
- **AST Checking**: Syntax validation without code generation
- **CPU Feature Detection**: Native and custom CPU feature support
- **Link Modes**: Static and dynamic linking
- **Strip Modes**: Control debug symbol stripping
- **Code Models**: Support for various code models (tiny, small, kernel, medium, large)
- **LTO Support**: Link-time optimization
- **C Interop**: Full C library and header integration
- **Single-threaded Mode**: Disable threading for embedded/WASM targets
- **Cache Management**: Global and local cache control

### Build Optimization

- **Optimization Levels**: Debug, ReleaseSafe, ReleaseFast, ReleaseSmall
- **CPU Features**: Baseline, native, or custom CPU feature sets
- **Code Generation**: PIC, PIE support
- **Debug Info Control**: Configurable debug information
- **Memory Management**: Custom stack check and red zone settings
- **LLVM Control**: Module and IR verification options

## Configuration

### Basic Usage (Builderfile)

```d
target("zig-app") {
    type: executable;
    language: zig;
    sources: ["main.zig"];
}
```

### With build.zig (Builderfile)

```d
target("zig-project") {
    type: executable;
    language: zig;
    sources: ["src/main.zig"];
    langConfig: {
        "zig": "{
            \"builder\": \"build-zig\",
            \"optimize\": \"ReleaseFast\",
            \"buildZig\": {
                \"steps\": [\"install\"],
                \"options\": {
                    \"enable_llvm\": \"true\"
                }
            }
        }"
    };
}
```

### Configuration Options

#### Build Mode
```json
{
    "mode": "compile"  // compile, test, run, build-script, check, translate-c, custom
}
```

#### Builder Selection
```json
{
    "builder": "auto"  // auto, build-zig, compile
}
```

#### Optimization Mode
```json
{
    "optimize": "ReleaseFast"  // Debug, ReleaseSafe, ReleaseFast, ReleaseSmall
}
```

#### Output Type
```json
{
    "outputType": "exe"  // exe, lib, dylib, obj
}
```

#### Cross-Compilation
```json
{
    "target": {
        "triple": "x86_64-linux-gnu",
        "cpu": "x86_64",
        "os": "linux",
        "abi": "gnu",
        "cpuFeatures": "native"  // baseline, native, custom
    }
}
```

Or simplified:
```json
{
    "target": "x86_64-linux-gnu"
}
```

#### Link and Strip Options
```json
{
    "linkMode": "static",  // static, dynamic
    "strip": "all",        // none, debug, all
    "pic": false,
    "pie": false
}
```

#### C Interoperability
```json
{
    "cppInterop": false,
    "cIncludeDirs": ["/usr/include"],
    "cLibDirs": ["/usr/lib"],
    "cLibs": ["c", "m"],
    "sysLibs": ["pthread"],
    "cflags": ["-O2"],
    "ldflags": ["-static"]
}
```

#### build.zig Configuration
```json
{
    "buildZig": {
        "path": "build.zig",
        "steps": ["install", "test"],
        "options": {
            "enable_llvm": "true",
            "enable_lld": "true"
        },
        "prefix": "zig-out",
        "sysroot": "/usr",
        "useSystemLinker": false
    }
}
```

#### Test Configuration
```json
{
    "test": {
        "filter": "test_name",
        "skipFilter": "slow",
        "verbose": true,
        "coverage": true,
        "coverageDir": "zig-out/coverage"
    }
}
```

#### Cache Configuration
```json
{
    "cache": {
        "globalCache": true,
        "cacheDir": ".zig-cache",
        "incremental": true
    }
}
```

#### Tooling Options
```json
{
    "runFmt": true,
    "runCheck": true,
    "fmtCheck": false,  // Check only, don't modify
    "fmtExclude": "vendor/"
}
```

#### Advanced Options
```json
{
    "singleThreaded": false,
    "stackCheck": true,
    "redZone": true,
    "lto": false,
    "llvmVerifyModule": true,
    "llvmIrVerify": true,
    "codeModel": "default",  // default, tiny, small, kernel, medium, large
    "maxMemory": 0,  // 0 = unlimited
    "threads": 0,    // 0 = auto
    "verbose": false,
    "timeReport": false,
    "color": true
}
```

#### Packages (Dependencies)
```json
{
    "packages": [
        {
            "name": "my-lib",
            "path": "libs/my-lib/lib.zig"
        },
        {
            "name": "external",
            "url": "https://github.com/user/repo.git",
            "hash": "abc123..."
        }
    ]
}
```

#### Environment Variables
```json
{
    "env": {
        "ZIG_GLOBAL_CACHE_DIR": "/tmp/zig-cache",
        "ZIG_LOCAL_CACHE_DIR": ".zig-cache"
    }
}
```

## Complete Examples

### Basic Executable

```d
target("hello") {
    type: executable;
    language: zig;
    sources: ["main.zig"];
    langConfig: {
        "zig": "{
            \"optimize\": \"ReleaseFast\"
        }"
    };
}
```

### Library with C Interop

```d
target("mylib") {
    type: library;
    language: zig;
    sources: ["lib.zig"];
    langConfig: {
        "zig": "{
            \"outputType\": \"dylib\",
            \"cppInterop\": true,
            \"cIncludeDirs\": [\"/usr/include\"],
            \"cLibs\": [\"c\", \"m\"]
        }"
    };
}
```

### Cross-Compilation

```d
target("embedded") {
    type: executable;
    language: zig;
    sources: ["main.zig"];
    langConfig: {
        "zig": "{
            \"target\": \"arm-linux-musleabihf\",
            \"optimize\": \"ReleaseSmall\",
            \"singleThreaded\": true,
            \"strip\": \"all\"
        }"
    };
}
```

### WASM Target

```d
target("web-app") {
    type: executable;
    language: zig;
    sources: ["main.zig"];
    langConfig: {
        "zig": "{
            \"target\": \"wasm32-wasi-musl\",
            \"optimize\": \"ReleaseSmall\",
            \"singleThreaded\": true
        }"
    };
}
```

### build.zig Project

```d
target("complex-project") {
    type: executable;
    language: zig;
    sources: ["src/main.zig"];
    langConfig: {
        "zig": "{
            \"builder\": \"build-zig\",
            \"optimize\": \"ReleaseFast\",
            \"buildZig\": {
                \"steps\": [\"install\"],
                \"options\": {
                    \"enable_llvm\": \"true\",
                    \"target_os\": \"linux\"
                },
                \"prefix\": \"dist\"
            }
        }"
    };
}
```

### Testing

```d
target("tests") {
    type: test;
    language: zig;
    sources: ["src/**/*.zig"];
    langConfig: {
        "zig": "{
            \"mode\": \"test\",
            \"test\": {
                \"filter\": \"integration\",
                \"verbose\": true,
                \"coverage\": true
            }
        }"
    };
}
```

### Production Build with All Optimizations

```d
target("production-server") {
    type: executable;
    language: zig;
    sources: ["src/main.zig"];
    langConfig: {
        "zig": "{
            \"optimize\": \"ReleaseFast\",
            \"target\": {
                \"triple\": \"x86_64-linux-musl\",
                \"cpuFeatures\": \"native\"
            },
            \"linkMode\": \"static\",
            \"strip\": \"all\",
            \"lto\": true,
            \"singleThreaded\": false,
            \"pie\": true,
            \"runFmt\": true,
            \"runCheck\": true
        }"
    };
}
```

## build.zig Detection

The system automatically detects `build.zig` in the project directory and parent directories. If found:

1. Uses zig build for building
2. Parses build.zig metadata (name, version, steps)
3. Parses build.zig.zon for dependencies
4. Identifies available build steps
5. Extracts module information
6. Auto-configures build options

## Cross-Compilation

Zig has first-class cross-compilation support. Common targets:

### Linux Targets
- `x86_64-linux-gnu` - Standard Linux x64
- `x86_64-linux-musl` - Static Linux x64
- `aarch64-linux-gnu` - ARM64 Linux
- `arm-linux-gnueabihf` - ARM Linux (hard float)
- `riscv64-linux-gnu` - RISC-V 64-bit

### Windows Targets
- `x86_64-windows-gnu` - Windows x64 (MinGW)
- `x86_64-windows-msvc` - Windows x64 (MSVC ABI)
- `aarch64-windows-gnu` - Windows ARM64

### macOS Targets
- `x86_64-macos-none` - macOS Intel
- `aarch64-macos-none` - macOS Apple Silicon

### WebAssembly
- `wasm32-wasi-musl` - WASI WebAssembly
- `wasm32-freestanding-musl` - Freestanding WASM

### Embedded
- `thumbv7m-freestanding-eabihf` - ARM Cortex-M
- `riscv32-freestanding-none` - RISC-V 32-bit bare metal

## Tooling Integration

### Format Code

```json
{
    "runFmt": true,
    "fmtCheck": false  // Check only mode
}
```

### Check Syntax

```json
{
    "runCheck": true
}
```

### Show Zen

The Zig philosophy can be displayed:
```bash
zig zen
```

## Implementation Details

### build.zig Builder (`build.d`)

- Parses build.zig for metadata
- Supports all zig build commands
- Handles build steps and options
- Integrates with build.zig.zon
- Manages custom configurations

### Direct Compile Builder (`compile.d`)

- Direct zig compile invocation
- Single-file and multi-file compilation
- Full control over compiler flags
- Useful for simple projects
- No build.zig required

### build.zig Parser (`builder.d`)

- TOML-like parsing for build.zig.zon
- Project metadata extraction
- Dependency resolution
- Module detection
- Build step discovery

### Target Manager (`targets.d`)

- Comprehensive target triple support
- CPU feature detection
- Cross-compilation validation
- Target triple normalization
- Platform-specific optimizations

### Tooling (`tools.d`)

- zig fmt integration
- zig ast-check support
- zig zen display
- zig translate-c support
- Environment introspection

## Best Practices

1. **Use build.zig for Projects**: Prefer build.zig for any non-trivial project
2. **Format Code**: Use `runFmt: true` for consistent style
3. **Check Before Build**: Enable `runCheck` to catch errors early
4. **Optimize for Target**: Choose appropriate optimization mode
5. **Cross-Compile**: Test on multiple platforms
6. **Static Linking**: Use musl for portable Linux binaries
7. **Strip Symbols**: Use `strip: "all"` for production builds
8. **LTO for Production**: Enable LTO for final binaries
9. **Cache Management**: Use global cache for faster builds
10. **Single-threaded for Embedded**: Disable threading for resource-constrained targets

## Performance Tips

### Fast Development Builds
```json
{
    "optimize": "Debug",
    "cache": {
        "incremental": true,
        "globalCache": true
    }
}
```

### Optimized Release Builds
```json
{
    "optimize": "ReleaseFast",
    "lto": true,
    "strip": "all",
    "target": {
        "cpuFeatures": "native"
    }
}
```

### Size-Optimized Builds
```json
{
    "optimize": "ReleaseSmall",
    "strip": "all",
    "linkMode": "static",
    "singleThreaded": true
}
```

## Troubleshooting

### Zig Not Found
Ensure Zig is installed and in PATH:
```bash
zig version
```

### build.zig Not Detected
Specify explicitly:
```json
{
    "buildZig": {
        "path": "path/to/build.zig"
    }
}
```

### Cross-Compilation Issues
Verify target is valid:
```bash
zig targets
```

### Cache Issues
Clear cache:
```json
{
    "cache": {
        "globalCache": false,
        "cacheDir": ".zig-cache-fresh"
    }
}
```

## Future Enhancements

- [ ] zon parser improvements for complex dependencies
- [ ] Automatic CPU feature detection per target
- [ ] Multi-target builds in single invocation
- [ ] Profile-guided optimization (PGO)
- [ ] Coverage report generation
- [ ] Documentation generation from source
- [ ] Package registry integration
- [ ] Build cache sharing across projects
- [ ] Incremental linking support
- [ ] Custom build step integration


