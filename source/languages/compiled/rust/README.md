# Rust Language Support

Comprehensive Rust build support with advanced cargo, rustup, and toolchain integration.

## Architecture

```
source/languages/compiled/rust/
├── package.d          # Public exports
├── handler.d          # Main build handler
├── config.d           # Configuration types and enums
├── manifest.d         # Cargo.toml parser
├── toolchain.d        # Rustup and toolchain management
└── builders/          # Build strategies
    ├── package.d      # Builder exports
    ├── base.d         # Builder interface and factory
    ├── cargo.d        # Cargo-based builder
    └── rustc.d        # Direct rustc builder
```

## Features

### Core Capabilities

- **Dual Build Modes**: Support for both cargo (full project) and rustc (single file)
- **Cargo Workspace Support**: Multi-crate workspace detection and building
- **Profile Management**: dev, release, test, bench, and custom profiles
- **Cross-Compilation**: Target triple support with automatic installation
- **Toolchain Management**: rustup integration with automatic toolchain installation
- **Feature Flags**: Full cargo features support with optional and default features
- **Crate Types**: All Rust crate types (bin, lib, rlib, dylib, cdylib, staticlib, proc-macro)

### Advanced Features

- **Clippy Integration**: Automatic linter integration with configurable flags
- **Rustfmt Support**: Code formatting with cargo fmt
- **Documentation Generation**: cargo doc support with --open
- **Test Harness**: Comprehensive test runner with filtering
- **Benchmarks**: cargo bench integration
- **Examples**: Build and run examples
- **Incremental Compilation**: Leverages cargo's incremental build cache
- **LTO Support**: Link-time optimization (thin, fat)
- **Codegen Control**: Configurable codegen units for compilation speed vs. optimization

### Build Optimization

- **Optimization Levels**: O0, O1, O2, O3, Os, Oz
- **Debug Info Control**: Configurable debug information generation
- **Parallel Jobs**: Configurable parallelism
- **Offline Mode**: Build without network access
- **Frozen/Locked**: Dependency version locking

## Configuration

### Basic Usage (Builderfile)

```d
target("my-rust-app") {
    type: executable;
    language: rust;
    sources: ["src/main.rs"];
}
```

### With Cargo (Builderfile)

```d
target("rust-project") {
    type: executable;
    language: rust;
    sources: ["src/main.rs"];
    langConfig: {
        "rust": "{
            \"compiler\": \"cargo\",
            \"profile\": \"release\",
            \"features\": [\"feature1\", \"feature2\"]
        }"
    };
}
```

### Configuration Options

#### Build Mode
```json
{
    "mode": "compile"  // compile, check, test, doc, bench, example, custom
}
```

#### Compiler Selection
```json
{
    "compiler": "auto"  // auto, cargo, rustc
}
```

#### Build Profile
```json
{
    "profile": "release",  // dev, release, test, bench, custom
    "customProfile": "my-profile"  // When profile=custom
}
```

#### Rust Edition
```json
{
    "edition": "2021"  // 2015, 2018, 2021, 2024
}
```

#### Crate Type
```json
{
    "crateType": "bin"  // bin, lib, rlib, dylib, cdylib, staticlib, proc-macro
}
```

#### Optimization
```json
{
    "optLevel": "3",     // 0, 1, 2, 3, s, z
    "lto": "thin",       // off, thin, fat
    "codegen": 1,        // single, default, or number
    "debugInfo": false
}
```

#### Cross-Compilation
```json
{
    "target": "x86_64-unknown-linux-musl",
    "toolchain": "stable",
    "installToolchain": true
}
```

#### Features
```json
{
    "features": ["serde", "tokio"],
    "allFeatures": false,
    "noDefaultFeatures": false
}
```

#### Workspace
```json
{
    "workspace": true,
    "package": "my-package",
    "exclude": ["internal-tools"]
}
```

#### Advanced Build Options
```json
{
    "targetDir": "custom-target",
    "manifest": "path/to/Cargo.toml",
    "jobs": 4,
    "incremental": true,
    "keepGoing": false,
    "verbose": 2,
    "color": "always",  // auto, always, never
    "frozen": true,
    "locked": false,
    "offline": true
}
```

#### Tooling Integration
```json
{
    "clippy": true,
    "clippyFlags": ["-W", "clippy::pedantic"],
    "fmt": true,
    "doc": true,
    "docOpen": false
}
```

#### Custom Flags
```json
{
    "rustcFlags": ["-C", "link-arg=-fuse-ld=lld"],
    "cargoFlags": ["--timings"]
}
```

#### Environment Variables
```json
{
    "env": {
        "CARGO_BUILD_RUSTFLAGS": "-C target-cpu=native",
        "RUSTC_WRAPPER": "sccache"
    }
}
```

## Complete Example

```d
target("production-server") {
    type: executable;
    language: rust;
    sources: ["src/main.rs"];
    langConfig: {
        "rust": "{
            \"mode\": \"compile\",
            \"compiler\": \"cargo\",
            \"profile\": \"release\",
            \"edition\": \"2021\",
            \"crateType\": \"bin\",
            \"optLevel\": \"3\",
            \"lto\": \"thin\",
            \"codegen\": 1,
            \"debugInfo\": false,
            \"incremental\": false,
            \"features\": [\"production\", \"metrics\"],
            \"noDefaultFeatures\": true,
            \"clippy\": true,
            \"clippyFlags\": [\"-D\", \"warnings\"],
            \"rustcFlags\": [
                \"-C\", \"target-cpu=native\",
                \"-C\", \"link-arg=-fuse-ld=lld\"
            ],
            \"env\": {
                \"RUSTFLAGS\": \"-C target-feature=+crt-static\"
            }
        }"
    };
}
```

## Cargo.toml Detection

The system automatically detects `Cargo.toml` in the project directory and parent directories. If found:

1. Uses cargo for building
2. Parses package metadata (name, version, edition)
3. Detects workspace configuration
4. Identifies library vs binary crates
5. Extracts dependency information
6. Recognizes feature flags

## Workspace Support

For Cargo workspaces:

```d
target("workspace-build") {
    type: executable;
    language: rust;
    sources: ["crates/*/src/main.rs"];
    langConfig: {
        "rust": "{
            \"workspace\": true,
            \"exclude\": [\"crates/test-utils\"]
        }"
    };
}
```

## Cross-Compilation

Build for different platforms:

```d
target("linux-musl") {
    type: executable;
    language: rust;
    sources: ["src/main.rs"];
    langConfig: {
        "rust": "{
            \"target\": \"x86_64-unknown-linux-musl\",
            \"installToolchain\": true
        }"
    };
}

target("windows") {
    type: executable;
    language: rust;
    sources: ["src/main.rs"];
    langConfig: {
        "rust": "{
            \"target\": \"x86_64-pc-windows-gnu\"
        }"
    };
}
```

## Testing

```d
target("rust-tests") {
    type: test;
    language: rust;
    sources: ["src/**/*.rs"];
    langConfig: {
        "rust": "{
            \"mode\": \"test\",
            \"testFlags\": [\"--nocapture\", \"--test-threads=1\"]
        }"
    };
}
```

## Benchmarks

```d
target("benchmarks") {
    type: test;
    language: rust;
    sources: ["benches/**/*.rs"];
    langConfig: {
        "rust": "{
            \"mode\": \"bench\",
            \"benchFlags\": [\"--save-baseline\", \"current\"]
        }"
    };
}
```

## Documentation

```d
target("docs") {
    type: custom;
    language: rust;
    sources: ["src/**/*.rs"];
    langConfig: {
        "rust": "{
            \"mode\": \"doc\",
            \"doc\": true,
            \"docOpen\": true
        }"
    };
}
```

## Library Crates

```d
target("my-library") {
    type: library;
    language: rust;
    sources: ["src/lib.rs"];
    langConfig: {
        "rust": "{
            \"crateType\": \"rlib\",
            \"features\": [\"std\"],
            \"noDefaultFeatures\": false
        }"
    };
}
```

## C-Compatible Library

```d
target("ffi-library") {
    type: library;
    language: rust;
    sources: ["src/lib.rs"];
    langConfig: {
        "rust": "{
            \"crateType\": \"cdylib\",
            \"features\": [\"ffi\"]
        }"
    };
}
```

## Procedural Macros

```d
target("derive-macro") {
    type: library;
    language: rust;
    sources: ["src/lib.rs"];
    langConfig: {
        "rust": "{
            \"crateType\": \"proc-macro\",
            \"edition\": \"2021\"
        }"
    };
}
```

## Implementation Details

### Cargo Builder (`cargo.d`)

- Parses Cargo.toml for metadata
- Supports all cargo commands and flags
- Handles workspace builds
- Manages feature flags
- Integrates with cargo's incremental compilation

### Rustc Builder (`rustc.d`)

- Direct rustc invocation for simple projects
- Single-file compilation
- Full control over compiler flags
- Useful for quick prototypes
- No Cargo.toml required

### Manifest Parser (`manifest.d`)

- TOML parsing for Cargo.toml
- Package metadata extraction
- Dependency resolution
- Workspace detection
- Feature flag discovery

### Toolchain Manager (`toolchain.d`)

- Rustup integration
- Toolchain installation and selection
- Target triple management
- Component installation (clippy, rustfmt, etc.)
- Version detection

## Best Practices

1. **Use Cargo for Projects**: Prefer cargo builder for any non-trivial project
2. **Enable Clippy**: Catch common mistakes early
3. **Format Code**: Use rustfmt for consistent style
4. **Optimize for Release**: Use `profile: "release"` for production builds
5. **LTO for Binaries**: Enable LTO for final binaries
6. **Feature Flags**: Use features for conditional compilation
7. **Cross-Compile**: Test on multiple platforms
8. **Lock Dependencies**: Use `locked: true` for reproducible builds
9. **Incremental Builds**: Keep incremental compilation enabled during development
10. **Parallel Jobs**: Let cargo auto-detect optimal parallelism

## Performance Tips

### Fast Development Builds
```json
{
    "profile": "dev",
    "incremental": true,
    "debugInfo": false
}
```

### Optimized Release Builds
```json
{
    "profile": "release",
    "optLevel": "3",
    "lto": "thin",
    "codegen": 1,
    "incremental": false
}
```

### Size-Optimized Builds
```json
{
    "profile": "release",
    "optLevel": "z",
    "lto": "fat",
    "codegen": 1,
    "rustcFlags": ["-C", "strip=symbols"]
}
```

## Troubleshooting

### Toolchain Not Found
```json
{
    "toolchain": "stable",
    "installToolchain": true
}
```

### Target Not Installed
```json
{
    "target": "x86_64-unknown-linux-musl",
    "installToolchain": true
}
```

### Dependency Issues
```json
{
    "frozen": true,
    "locked": true
}
```

### Network Problems
```json
{
    "offline": true
}
```

## Future Enhancements

- [ ] Cargo-expand integration for macro debugging
- [ ] Cargo-tree visualization
- [ ] Custom build script (build.rs) support
- [ ] Multi-target builds in single invocation
- [ ] Cargo audit integration for security
- [ ] Cargo outdated for dependency management
- [ ] Profile-guided optimization (PGO)
- [ ] Cargo chef for Docker layer caching


