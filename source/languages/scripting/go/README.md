# Go Language Support

Comprehensive, modular Go language support for the Builder build system with first-class support for Go's unique features.

## Architecture

This module follows a clean, modular architecture inspired by the TypeScript/JavaScript patterns in the codebase:

```
go/
├── handler.d        # Main orchestrator - delegates to specialized components
├── config.d         # Configuration types, enums, and JSON parsing
├── modules.d        # go.mod/go.sum parsing and Go workspace support
├── tools.d          # Go tooling integration (fmt, vet, lint, generate)
├── builders/        # Build strategy implementations
│   ├── base.d       # Builder interface and factory
│   ├── standard.d   # Standard go build (executable, library)
│   ├── plugin.d     # Go plugin compilation
│   ├── cgo.d        # CGO (C interop) builds
│   └── cross.d      # Cross-compilation (GOOS/GOARCH)
├── package.d        # Public exports
└── README.md        # This file
```

## Features

### 🎯 Core Capabilities

- **Module System**: Full support for `go.mod`/`go.sum` and Go workspaces (`go.work`)
- **Build Modes**: Executable, library, plugin, c-archive, c-shared, PIE
- **Cross-Compilation**: GOOS/GOARCH matrix with validation
- **CGO Support**: C/C++ interop with custom compiler flags
- **Build Constraints**: Modern build tags and constraint expressions
- **Testing**: Unit tests, benchmarks, coverage, race detection, fuzzing

### 🛠️ Tooling Integration

- **gofmt**: Automatic code formatting
- **go vet**: Static analysis for suspicious code
- **golangci-lint**: Comprehensive linter suite (recommended)
- **staticcheck**: Focused static analyzer
- **go generate**: Code generation support
- **go mod tidy**: Dependency management

### 🚀 Advanced Features

- **Module Detection**: Auto-detect and parse go.mod
- **Workspace Support**: Multi-module development with go.work
- **CGO Detection**: Auto-enable CGO when C imports detected
- **Vendor Mode**: Support for vendored dependencies
- **Trimpath**: Remove file system paths from binaries
- **Custom Flags**: Full control over gcflags, ldflags, asmflags

## Configuration

### DSL Format

```dsl
target("my-app") {
    type: executable;
    language: go;
    sources: ["main.go", "utils.go"];
    
    go: {
        mode: "executable",
        trimpath: true,
        ldflags: ["-s", "-w"],
        constraints: {
            os: ["linux", "darwin"],
            arch: ["amd64", "arm64"],
            tags: ["release"]
        },
        runVet: true,
        runLint: true,
        linter: "golangci-lint"
    };
}
```

### JSON Format

```json
{
    "name": "my-app",
    "type": "executable",
    "language": "go",
    "sources": ["main.go"],
    "go": {
        "mode": "executable",
        "modMode": "on",
        "trimpath": true,
        "ldflags": ["-s", "-w"],
        "cgo": {
            "enabled": true,
            "cflags": ["-O2"],
            "ldflags": ["-lm"]
        },
        "cross": {
            "goos": "linux",
            "goarch": "amd64"
        },
        "test": {
            "verbose": true,
            "coverage": true,
            "race": true
        }
    }
}
```

## Configuration Options

### Build Modes

- `executable` - Standard binary (default)
- `library` - Go package/library
- `plugin` - Go plugin (deprecated, limited platform support)
- `c-archive` - C archive for use in C projects
- `c-shared` - Shared library for C
- `pie` - Position Independent Executable
- `shared` - Shared Go library

### Module Modes

- `auto` - Auto-detect from go.mod (default)
- `on` - Enable module mode
- `off` - Disable modules (GOPATH)
- `readonly` - Read-only module cache
- `vendor` - Use vendor directory

### Build Constraints

```json
{
    "constraints": {
        "os": ["linux", "darwin"],
        "arch": ["amd64", "arm64"],
        "tags": ["prod", "feature_x"],
        "cgoEnabled": true,
        "expression": "linux && (amd64 || arm64)"
    }
}
```

### Cross-Compilation

```json
{
    "cross": {
        "goos": "linux",
        "goarch": "arm64",
        "goarm": "7"
    }
}
```

Supported targets include:
- Linux: amd64, 386, arm, arm64
- macOS: amd64, arm64
- Windows: amd64, 386, arm, arm64
- FreeBSD, NetBSD, OpenBSD, Dragonfly
- WebAssembly (js/wasm)
- And many more...

### CGO Configuration

```json
{
    "cgo": {
        "enabled": true,
        "cflags": ["-O2", "-I/usr/local/include"],
        "cxxflags": ["-std=c++17"],
        "ldflags": ["-L/usr/local/lib", "-lmylib"],
        "pkgConfig": ["/usr/local/lib/pkgconfig"],
        "cc": "gcc",
        "cxx": "g++"
    }
}
```

### Testing Configuration

```json
{
    "test": {
        "verbose": true,
        "coverage": true,
        "coverProfile": "coverage.out",
        "coverMode": "atomic",
        "race": true,
        "bench": true,
        "benchPattern": ".",
        "benchTime": "10s",
        "fuzz": false,
        "timeout": "10m",
        "parallel": 4,
        "short": false
    }
}
```

## Usage Examples

### Simple Executable

```dsl
target("hello") {
    type: executable;
    language: go;
    sources: ["main.go"];
}
```

### Cross-Compilation

```dsl
target("app-linux-arm64") {
    type: executable;
    language: go;
    sources: ["main.go"];
    
    go: {
        cross: {
            goos: "linux",
            goarch: "arm64"
        },
        trimpath: true,
        ldflags: ["-s", "-w"]  // Strip debug info
    };
}
```

### CGO with C Library

```dsl
target("native-app") {
    type: executable;
    language: go;
    sources: ["main.go", "wrapper.go"];
    
    go: {
        cgo: {
            enabled: true,
            cflags: ["-I./include"],
            ldflags: ["-L./lib", "-lnative"]
        }
    };
}
```

### Library with Testing

```dsl
target("mylib") {
    type: library;
    language: go;
    sources: ["lib.go", "util.go"];
    
    go: {
        mode: "library",
        runFmt: true,
        runVet: true,
        runLint: true
    };
}

target("mylib-test") {
    type: test;
    language: go;
    sources: ["lib_test.go"];
    deps: [":mylib"];
    
    go: {
        test: {
            verbose: true,
            coverage: true,
            race: true
        }
    };
}
```

### Production Build with All Optimizations

```dsl
target("prod-binary") {
    type: executable;
    language: go;
    sources: ["cmd/app/main.go"];
    
    go: {
        mode: "executable",
        trimpath: true,
        ldflags: [
            "-s",  // Strip symbol table
            "-w",  // Strip DWARF
            "-X main.version=1.0.0",
            "-X main.buildTime=\$(date +%Y-%m-%d)"
        ],
        runFmt: true,
        runVet: true,
        runLint: true,
        linter: "golangci-lint",
        modTidy: true
    };
}
```

## Builder Selection

The system automatically selects the appropriate builder based on configuration:

1. **StandardBuilder** - Default for executables and libraries
2. **CrossBuilder** - Activated when cross-compilation target specified
3. **CGoBuilder** - Activated when CGO is enabled
4. **PluginBuilder** - Activated for plugin build mode

Builders can be combined (e.g., cross-compilation with CGO).

## Module & Workspace Detection

The handler automatically:
- Searches for `go.mod` in directory tree
- Parses module path and dependencies
- Detects `go.work` for multi-module projects
- Auto-enables module mode when go.mod found
- Warns if go.mod missing with suggestions

## Tool Integration

### Automatic Code Quality

```json
{
    "runFmt": true,       // Auto-format with gofmt
    "runVet": true,       // Run go vet
    "runLint": true,      // Run linter
    "linter": "golangci-lint"  // Or "staticcheck", "golint"
}
```

### Pre-build Operations

```json
{
    "generate": true,     // Run go generate
    "modTidy": true,      // Run go mod tidy
    "installDeps": true,  // Run go mod download
    "vendor": true        // Create vendor directory
}
```

## Design Principles

### 1. **Modularity**
Each component has a single, well-defined responsibility:
- `config.d`: Configuration types
- `modules.d`: Module/workspace parsing
- `tools.d`: Tool execution
- `builders/`: Build strategies

### 2. **Extensibility**
New builders can be added easily by implementing the `GoBuilder` interface. New tooling can be added to `tools.d`.

### 3. **Type Safety**
Strong typing throughout with enums for build modes, module modes, and other options. Configuration is validated at parse time.

### 4. **Auto-Detection**
Smart defaults based on project structure:
- Module mode from go.mod
- CGO from import "C"
- Entry points from sources

### 5. **Composability**
Builders can be combined and configuration can be layered from multiple sources.

## Performance Considerations

- **Incremental Builds**: Leverages Go's build cache
- **Parallel Testing**: Configurable parallel test execution
- **Trimpath**: Reduces binary size and improves reproducibility
- **Linker Flags**: Support for all Go optimization flags

## Best Practices

1. **Use modules**: Always have a go.mod file
2. **Enable tooling**: Set runFmt, runVet, runLint for quality
3. **Strip binaries**: Use `-s -w` ldflags for production
4. **Cross-compile carefully**: Disable CGO or setup cross-compilers
5. **Test thoroughly**: Enable race detector during development
6. **Vendor for stability**: Use vendor mode for reproducible builds

## Advanced Topics

### Custom Compiler Flags

```json
{
    "gcflags": ["-m", "-l"],           // Compiler flags
    "ldflags": ["-s", "-w", "-X main.version=1.0"],
    "asmflags": ["-D", "FEATURE=1"],  // Assembler flags
    "gccgoflags": ["-O3"]              // GCC Go flags
}
```

### Module Replacements

Handled via go.mod:
```
replace github.com/old/module => github.com/new/module v1.2.3
replace github.com/local/module => ../local/path
```

### Build Tags (Legacy)

```json
{
    "buildTags": ["integration", "mysql"]
}
```

Or use modern constraints:
```json
{
    "constraints": {
        "expression": "linux && (mysql || postgres)"
    }
}
```

## Troubleshooting

**Problem**: Module not found
- **Solution**: Run with `installDeps: true` or `modTidy: true`

**Problem**: CGO errors
- **Solution**: Ensure C compiler available, check cflags/ldflags

**Problem**: Cross-compilation with CGO fails
- **Solution**: Either disable CGO or setup cross-compiler toolchain

**Problem**: Tests hang
- **Solution**: Add timeout: `"timeout": "10m"`

**Problem**: Race detector issues
- **Solution**: Only use race detector on amd64/arm64 platforms

## Integration with Builder

This module integrates seamlessly with Builder's:
- Dependency graph system
- Incremental builds
- Caching mechanism
- Parallel execution
- Error handling

## Future Enhancements

Potential additions:
- go:embed support detection
- Generic type analysis
- Module vulnerability scanning
- Automated version management
- Build reproducibility verification
- Container image generation

## Contributing

When extending this module:
1. Follow the established patterns (see JS/TS modules)
2. Keep files small and focused
3. Add comprehensive tests
4. Update this README
5. Maintain strong typing

