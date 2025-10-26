# Nim Language Support

Comprehensive, modular Nim language support for Builder with multi-backend compilation, nimble integration, and advanced tooling support.

## Architecture

Clean, extensible architecture following Builder's established patterns:

```
nim/
├── core/              # Core orchestration and configuration
│   ├── config.d       # Configuration types, enums, and JSON parsing
│   ├── handler.d      # NimHandler - main build orchestrator
│   └── package.d      # Module exports
├── builders/          # Build strategy implementations
│   ├── base.d         # NimBuilder interface and factory
│   ├── compile.d      # Direct nim compiler invocation
│   ├── nimble.d       # Nimble package manager builder
│   ├── check.d        # Syntax/semantic checking (no codegen)
│   ├── doc.d          # Documentation generation
│   ├── js.d           # JavaScript backend builder
│   └── package.d      # Builder exports
├── tooling/           # Development tools integration
│   ├── tools.d        # Tool detection (nimpretty, nimsuggest, nimgrep)
│   └── package.d      # Tooling exports
├── managers/          # Package management
│   ├── nimble.d       # Nimble package manager operations
│   └── package.d      # Manager exports
├── analysis/          # Project analysis
│   ├── nimble.d       # .nimble file parser and lock file support
│   └── package.d      # Analysis exports
├── package.d          # Main module exports
└── README.md          # This file
```

## Features

### 🎨 Multiple Compilation Backends

Nim's powerful multi-backend support:

- **C Backend** (default) - Compiles to C for maximum compatibility and performance
- **C++ Backend** - Enables C++ interop and templates
- **JavaScript Backend** - Target Node.js or browser environments
- **Objective-C Backend** - Native macOS/iOS development

### 📦 Nimble Integration

Full support for Nim's package manager:

- **Dependency Management** - Automatic dependency installation
- **Lock File Support** - Parse nimble.lock for reproducible builds
- **.nimble File Parsing** - Extract package metadata and requirements
- **Package Operations** - Install, update, search, and uninstall packages
- **Custom Tasks** - Execute nimble tasks

### 🔨 Build Strategies

Multiple builders with intelligent auto-detection:

- **Compile Builder** - Direct nim compiler invocation with full control
- **Nimble Builder** - Package-based builds using nimble
- **Check Builder** - Syntax and type checking without code generation
- **Doc Builder** - Generate beautiful HTML documentation
- **JS Builder** - Specialized JavaScript backend compilation

### ⚡ Optimization & Runtime

Comprehensive optimization and runtime configuration:

- **Optimization Levels** - None (debug), Speed, Size
- **GC Strategies** - Refc, Arc, Orc (default), Mark&Sweep, Boehm, Go, None
- **Release/Danger Modes** - Optimize for production or maximum performance
- **Debug Support** - Debug info, line tracing, stack traces, profiler
- **Runtime Checks** - Bounds checking, assertions, overflow detection

### 🌐 Cross-Compilation

Target multiple platforms from a single machine:

- **OS Targets** - Linux, Windows, macOS, FreeBSD, Android, iOS, standalone
- **CPU Architectures** - x86, x86-64, ARM, ARM64, MIPS, RISC-V, WebAssembly
- **Custom Targets** - Full control over target triple

### 🛠️ Development Tools

Integrated tooling for professional development:

- **nimpretty** - Code formatting with customizable style
- **nim check** - Fast syntax and type checking
- **nimsuggest** - IDE-like code intelligence
- **nimgrep** - Pattern matching in Nim code
- **testament** - Test framework integration (planned)

### 📖 Documentation Generation

Professional documentation with:

- **HTML Generation** - Beautiful, navigable documentation
- **Index Creation** - Searchable documentation index
- **Source Embedding** - Include source code in docs
- **Git Integration** - Link to repository and commits
- **Custom Branding** - Project name and title customization

### 🧪 Library Types

All Nim application types:

- **Console** - Command-line applications
- **GUI** - Graphical applications
- **Static Library** - `.a` / `.lib` files
- **Dynamic Library** - `.so` / `.dll` / `.dylib` files

### 🔗 C/C++ Interoperability

Seamless integration with C/C++:

- **Include Directories** - Custom C header paths
- **Library Directories** - Link against C libraries
- **Pass-through Flags** - Direct C compiler and linker flags
- **C Compiler Selection** - Choose GCC, Clang, MSVC, etc.

## Usage Examples

### Basic Executable

```d
target("nim-app") {
    type: executable;
    language: nim;
    sources: ["main.nim"];
}
```

### Optimized Release Build

```d
target("fast-app") {
    type: executable;
    language: nim;
    sources: ["main.nim"];
    nim: {
        release: true,
        optimize: "speed",
        gc: "orc"
    }
}
```

### Cross-Compilation

```d
target("windows-app") {
    type: executable;
    language: nim;
    sources: ["main.nim"];
    nim: {
        target: {
            os: "windows",
            cpu: "amd64"
        },
        release: true
    }
}
```

### JavaScript Backend

```d
target("web-app") {
    type: executable;
    language: nim;
    sources: ["app.nim"];
    nim: {
        backend: "js",
        output: "app.js"
    }
}
```

### Static Library

```d
target("mylib") {
    type: library;
    language: nim;
    sources: ["lib.nim"];
    nim: {
        appType: "staticlib",
        release: true,
        optimize: "size"
    }
}
```

### Dynamic Library with C Interop

```d
target("shared-lib") {
    type: library;
    language: nim;
    sources: ["interop.nim"];
    nim: {
        appType: "dynamiclib",
        backend: "cpp",
        includeDirs: ["/usr/include/mylib"],
        libs: ["mylib"],
        release: true
    }
}
```

### Nimble Package Build

```d
target("nim-package") {
    type: executable;
    language: nim;
    sources: ["src/main.nim"];
    nim: {
        builder: "nimble",
        nimble: {
            enabled: true,
            installDeps: true
        }
    }
}
```

### Documentation Generation

```d
target("docs") {
    type: custom;
    language: nim;
    sources: ["src/**/*.nim"];
    nim: {
        mode: "doc",
        doc: {
            outputDir: "docs",
            project: "MyProject",
            title: "MyProject API Documentation",
            genIndex: true,
            includeSource: true
        }
    }
}
```

### Check Only (No Compilation)

```d
target("nim-check") {
    type: custom;
    language: nim;
    sources: ["src/**/*.nim"];
    nim: {
        mode: "check"
    }
}
```

### With Code Formatting

```d
target("formatted-app") {
    type: executable;
    language: nim;
    sources: ["main.nim"];
    nim: {
        runFormat: true,
        formatIndent: 2,
        formatMaxLineLen: 100
    }
}
```

## Configuration Reference

### Core Options

```json
{
    // Build mode
    "mode": "compile" | "check" | "doc" | "run" | "nimble" | "test" | "custom",
    
    // Builder selection
    "builder": "auto" | "nimble" | "compile" | "check" | "doc" | "js",
    
    // Compilation backend
    "backend": "c" | "cpp" | "js" | "objc",
    
    // Entry point
    "entry": "main.nim",
    
    // Output configuration
    "output": "myapp",
    "outputDir": "bin"
}
```

### Optimization

```json
{
    // Optimization level
    "optimize": "none" | "speed" | "size",
    
    // Release build (enables optimizations)
    "release": true,
    
    // Danger mode (disables all runtime checks)
    "danger": false,
    
    // Garbage collector
    "gc": "orc" | "arc" | "refc" | "markandsweep" | "boehm" | "go" | "none"
}
```

### Application Type

```json
{
    "appType": "console" | "gui" | "staticlib" | "dynamiclib"
}
```

### Cross-Compilation

```json
{
    "target": {
        "os": "linux" | "windows" | "macosx" | "freebsd" | ...,
        "cpu": "amd64" | "i386" | "arm" | "arm64" | "wasm" | ...
    }
}
```

### Debug & Runtime Checks

```json
{
    "debugInfo": false,
    "checks": true,              // Bounds checking
    "assertions": true,
    "lineTrace": false,
    "stackTrace": true,
    "profiler": false
}
```

### Defines & Flags

```json
{
    "defines": ["ssl", "production"],
    "undefines": ["testing"],
    "compilerFlags": ["--threads:on"],
    "linkerFlags": ["-static"]
}
```

### C/C++ Interop

```json
{
    "cCompiler": "gcc",
    "cppCompiler": "g++",
    "includeDirs": ["/usr/local/include"],
    "libDirs": ["/usr/local/lib"],
    "libs": ["ssl", "crypto"],
    "passCFlags": ["-O3"],
    "passLFlags": ["-static-libstdc++"]
}
```

### Nimble Integration

```json
{
    "nimble": {
        "enabled": true,
        "nimbleFile": "myproject.nimble",
        "installDeps": true,
        "devMode": false,
        "tasks": ["build", "test"],
        "flags": ["--verbose"]
    }
}
```

### Documentation

```json
{
    "doc": {
        "outputDir": "htmldocs",
        "format": "html",
        "genIndex": true,
        "project": "MyProject",
        "title": "API Documentation",
        "includeSource": true
    }
}
```

### Testing

```json
{
    "test": {
        "testDir": "tests",
        "categories": ["unit", "integration"],
        "pattern": "test_*.nim",
        "coverage": false,
        "verbose": false,
        "parallel": true
    }
}
```

### Paths

```json
{
    "path": {
        "paths": ["lib", "vendor"],
        "clearPaths": false,
        "nimblePaths": ["~/.nimble/pkgs"]
    }
}
```

### Hints & Warnings

```json
{
    "hints": {
        "enable": ["Hint1"],
        "disable": ["XDeclaredButNotUsed"],
        "enableWarnings": ["Warning1"],
        "disableWarnings": ["Warning2"],
        "warningsAsErrors": false,
        "hintsAsErrors": false
    }
}
```

### Threading

```json
{
    "threads": {
        "enabled": false,
        "model": "on",
        "stackSize": 0
    }
}
```

### Tooling

```json
{
    "runFormat": false,
    "runCheck": false,
    "formatCheck": false,
    "formatIndent": 2,
    "formatMaxLineLen": 80
}
```

### Build Options

```json
{
    "verbose": false,
    "forceBuild": false,
    "parallel": false,
    "parallelJobs": 0,  // 0 = auto
    "listCmd": false,
    "colors": true,
    "nimCache": "nimcache",
    "nimStdlib": ""  // Override stdlib path
}
```

## Complete Example

```d
target("production-server") {
    type: executable;
    language: nim;
    sources: ["src/main.nim"];
    langConfig: {
        "nim": "{
            \"mode\": \"compile\",
            \"builder\": \"nimble\",
            \"backend\": \"c\",
            \"optimize\": \"speed\",
            \"gc\": \"orc\",
            \"appType\": \"console\",
            \"release\": true,
            \"debugInfo\": false,
            \"checks\": false,
            \"assertions\": false,
            \"stackTrace\": true,
            \"defines\": [\"ssl\", \"production\"],
            \"cCompiler\": \"gcc\",
            \"libs\": [\"ssl\", \"crypto\"],
            \"passLFlags\": [\"-static\"],
            \"target\": {
                \"os\": \"linux\",
                \"cpu\": \"amd64\"
            },
            \"nimble\": {
                \"enabled\": true,
                \"installDeps\": true
            },
            \"threads\": {
                \"enabled\": true
            },
            \"runFormat\": true,
            \"runCheck\": true
        }"
    };
}
```

## Design Philosophy

### 🎯 Elegance Through Modularity

- **Single Responsibility** - Each module has one clear purpose
- **Interface-Driven** - Abstract builders for extensibility
- **Factory Patterns** - Intelligent builder auto-selection
- **Composition** - Complex features from simple components

### ⚡ Performance Optimized

- **Lazy Initialization** - Tools checked only when needed
- **Cached Detection** - Version checks cached for speed
- **Parallel Builds** - Nim's parallel compilation support
- **Efficient Parsing** - Fast .nimble file analysis

### 🧪 Highly Testable

- **Pure Functions** - Testable without side effects
- **Mockable Interfaces** - Easy to test in isolation
- **Clear Contracts** - Explicit input/output types
- **Result Types** - Type-safe error handling

### 🔮 Future-Proof

- **Backend Agnostic** - Support for all current and future backends
- **Extensible Builders** - Easy to add new build strategies
- **Version Independent** - Works with Nim 1.x and 2.x
- **Cross-Platform** - Supports all Nim target platforms

## Advanced Features

### Intelligent Auto-Detection

The handler automatically detects:

- **Project Type** - Nimble package vs. standalone
- **Entry Points** - main.nim, lib.nim, or package name
- **Package Metadata** - From .nimble files
- **Dependencies** - From requires sections
- **Backend Preference** - From nimble file

### Multi-Backend Support

Seamlessly switch between backends:

- **C Backend** - Maximum portability and performance
- **C++ Backend** - C++ templates and stdlib access
- **JavaScript** - Browser or Node.js targets
- **Objective-C** - Native Apple platform integration

### Nimble Package Management

Full nimble ecosystem integration:

- **Dependency Installation** - Automatic or manual
- **Lock Files** - Parse nimble.lock for versions
- **Package Search** - Find packages in nimble registry
- **Custom Tasks** - Execute nimble tasks
- **Development Mode** - Install only dependencies

### Documentation Generation

Professional documentation:

- **Multi-File** - Document entire projects
- **Index Generation** - Searchable documentation
- **Source Embedding** - View source in docs
- **Git Integration** - Link to repository
- **Custom Themes** - (Future: custom CSS)

## Best Practices

1. **Use Nimble for Projects** - Leverage nimble for any multi-file project
2. **Enable Orc GC** - Modern, deterministic memory management (default)
3. **Release Builds** - Always use `release: true` for production
4. **Cross-Compile** - Test on multiple platforms
5. **Format Code** - Use `runFormat: true` for consistency
6. **Check Before Build** - Use `runCheck: true` to catch errors early
7. **Lock Dependencies** - Use nimble.lock for reproducibility
8. **Document APIs** - Generate docs for libraries
9. **Optimize Appropriately** - Speed for servers, Size for embedded

## Performance Tips

### Fast Development Builds

```json
{
    "optimize": "none",
    "checks": true,
    "assertions": true,
    "debugInfo": true
}
```

### Optimized Release Builds

```json
{
    "release": true,
    "optimize": "speed",
    "checks": false,
    "assertions": false,
    "gc": "orc"
}
```

### Size-Optimized Builds

```json
{
    "release": true,
    "optimize": "size",
    "checks": false,
    "gc": "arc"
}
```

### Maximum Performance

```json
{
    "danger": true,
    "optimize": "speed",
    "gc": "none",
    "passLFlags": ["-static", "-s"]
}
```

## Troubleshooting

### Nim Compiler Not Found

```json
{
    // Install Nim: https://nim-lang.org/install.html
    // Or specify custom path via environment
}
```

### Nimble Not Available

```json
{
    // Install nimble (usually comes with Nim)
    // Or use direct compilation:
    "builder": "compile"
}
```

### Dependency Issues

```json
{
    "nimble": {
        "installDeps": true,
        "devMode": false
    }
}
```

### Cross-Compilation Failures

```json
{
    // Ensure target toolchain is installed
    "target": {
        "os": "linux",
        "cpu": "amd64"
    },
    // May need cross-compiler
    "cCompiler": "x86_64-linux-gnu-gcc"
}
```

## Future Enhancements

- [ ] Testament testing framework integration
- [ ] Nimscript build file support
- [ ] Custom nimble task definitions
- [ ] Code coverage integration
- [ ] Benchmark support
- [ ] Package publishing workflows
- [ ] IDE integration helpers
- [ ] Compiler plugin support

## Contributing

When extending Nim support:

1. **Follow Patterns** - Maintain the modular structure
2. **Use Interfaces** - Define contracts before implementations
3. **Factory Pattern** - Use factories for builder creation
4. **Result Types** - Return structured results
5. **Logging** - Use Logger for all output
6. **Error Handling** - Graceful degradation, never crash
7. **Documentation** - Update this README

## See Also

- [Builder Architecture](../../ARCHITECTURE.md)
- [Rust Module](../rust/README.md) - Similar compiled language
- [Zig Module](../zig/README.md) - Modern compiled language
- [C++ Module](../cpp/README.md) - Complex build system patterns
- [Nim Official Docs](https://nim-lang.org/docs/)

