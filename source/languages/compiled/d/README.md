# D Language Support

Comprehensive D build support with DUB integration, multiple compiler support, and advanced tooling.

## Architecture

```
source/languages/compiled/d/
├── package.d          # Public exports and convenience aliases
├── core/              # Core build logic
│   ├── package.d      # Core exports
│   ├── handler.d      # Main build handler
│   └── config.d       # Configuration types and enums
├── builders/          # Build strategies
│   ├── package.d      # Builder exports
│   ├── base.d         # Builder interface and factory
│   ├── dub.d          # DUB builder
│   └── direct.d       # Direct compiler invocation (dmd/ldc/gdc)
├── analysis/          # Project analysis
│   ├── package.d      # Analysis exports
│   ├── manifest.d     # dub.json/dub.sdl parser
│   └── modules.d      # Module dependency analysis
├── managers/          # Toolchain management
│   ├── package.d      # Manager exports
│   └── toolchain.d    # Compiler detection and version management
├── tooling/           # D tooling integration
│   ├── package.d      # Tooling exports
│   └── tools.d        # dfmt, dscanner, dub test, ddoc
└── README.md          # This file
```

## Features

### Core Capabilities

- **Multi-Compiler Support**: DMD, LDC (LLVM), GDC, custom compilers
- **DUB Integration**: Full dub.json and dub.sdl support with auto-detection
- **Build Configurations**: Debug, Release, ReleaseNoBounds, Unittest, Profile, Coverage
- **Output Types**: Executables, static libraries, shared libraries, object files
- **Module Analysis**: Automatic import detection and dependency resolution
- **BetterC Mode**: C-compatible code generation without D runtime

### Advanced Features

#### Build Optimization
- **Optimization Levels**: Control inlining, bounds checking, and optimization flags
- **LTO Support**: Link-time optimization (LDC only)
- **Cross-Compilation**: Target triple support with sysroot configuration
- **Profile-Guided Optimization**: Profile instrumentation and analysis
- **Code Coverage**: Built-in coverage analysis with .lst file generation

#### Code Quality
- **dfmt Integration**: Automatic code formatting with customizable styles
- **dscanner Support**: Comprehensive static analysis and linting
- **Syntax Checking**: Fast syntax validation without code generation
- **Deprecation Control**: Configurable deprecation warnings and errors

#### Testing
- **Unit Test Support**: Built-in unittest compilation and execution
- **DUB Test Runner**: Integrated test running with coverage
- **Test Filtering**: Run specific tests by name or pattern
- **Coverage Reporting**: Automatic coverage calculation from .lst files

#### Documentation
- **DDoc Generation**: Built-in documentation generator
- **JSON Export**: Machine-readable code description
- **Symbol Analysis**: Find symbol definitions and usages

### Language Features Support
- **DIP1000**: Memory safety
- **DIP1008**: Throw without exception objects
- **DIP25**: Sealed references
- **Preview Features**: Access to experimental language features
- **Version Identifiers**: Conditional compilation support
- **Debug Identifiers**: Debug-specific code compilation

## Configuration

### Basic Usage (Builderfile)

```d
target("d-app") {
    type: executable;
    language: d;
    sources: ["main.d", "utils.d"];
}
```

### With DUB (Builderfile)

```d
target("d-project") {
    type: executable;
    language: d;
    sources: ["source/app.d"];
    langConfig: {
        "d": "{
            \"mode\": \"dub\",
            \"compiler\": \"ldc\",
            \"buildConfig\": \"release\"
        }"
    };
}
```

### Configuration Options

#### Build Mode
```json
{
    "mode": "compile"  // compile, test, run, dub, doc, lint, custom
}
```

#### Compiler Selection
```json
{
    "compiler": "auto"  // auto, ldc, dmd, gdc, custom
}
```

For custom compiler:
```json
{
    "compiler": "custom",
    "customCompiler": "/path/to/compiler"
}
```

#### Build Configuration
```json
{
    "buildConfig": "release"  // debug, plain, release, release-nobounds, 
                               // unittest, profile, cov, unittest-cov, syntax
}
```

#### Output Type
```json
{
    "outputType": "executable"  // executable, staticlib, sharedlib, object
}
```

#### DUB Configuration
```json
{
    "dub": {
        "packagePath": "dub.json",
        "configuration": "default",
        "command": "build",        // build, test, run
        "compiler": "ldc2",
        "arch": "x86_64",
        "force": false,
        "combined": false,
        "deep": false,
        "verbose": false,
        "jobs": 0,                 // 0 = auto
        "dubFlags": ["--parallel"],
        "overrides": {
            "package": "path/to/override"
        }
    }
}
```

#### Compiler Configuration
```json
{
    "compilerConfig": {
        "release": true,
        "inline": true,
        "boundsCheck": false,
        "debugSymbols": false,
        "profile": false,
        "coverage": false,
        "unittest": false,
        "betterC": false,
        "warnings": true,
        "warningsAsErrors": false,
        "deprecations": true,
        "deprecationErrors": false,
        "verbose": false,
        "color": true,
        
        "defines": ["VERSION=1.0"],
        "versions": ["Have_ssl"],
        "debugs": ["verbose"],
        "importPaths": ["source", "imports"],
        "stringImportPaths": ["resources"],
        "libPaths": ["/usr/local/lib"],
        "libs": ["ssl", "crypto"],
        "linkerFlags": ["-L--static"],
        
        "preview": ["dip1000", "dip1008"],
        "revert": [],
        "transition": [],
        
        "dip1000": true,
        "dip1008": false,
        "dip25": false,
        
        "targetTriple": "x86_64-linux-gnu",
        "sysroot": "/usr/x86_64-linux-gnu",
        "pic": false,
        "pie": false,
        "lto": false,
        "staticLink": false,
        
        "doc": false,
        "docDir": "docs",
        "docFormat": "html",
        "json": false,
        "jsonFile": "output.json"
    }
}
```

#### Test Configuration
```json
{
    "test": {
        "mainFile": "tests/main.d",
        "filter": "test_*",
        "testName": "specific_test",
        "verbose": true,
        "coverage": true,
        "coverageTool": "builtin",  // builtin, llvm-cov
        "coverageDir": "coverage",
        "minCoverage": 80.0
    }
}
```

#### Tooling Configuration
```json
{
    "tooling": {
        "runFmt": true,
        "fmtCheckOnly": false,
        "fmtConfig": ".dfmtrc",
        
        "runLint": true,
        "lintConfig": "dscanner.ini",
        "lintStyleCheck": true,
        "lintSyntaxCheck": true,
        "lintReport": "stylish",   // json, sonarqube, stylish
        
        "runDubTest": false
    }
}
```

## Complete Examples

### Basic Executable

```d
target("hello") {
    type: executable;
    language: d;
    sources: ["main.d"];
    langConfig: {
        "d": "{
            \"compiler\": \"ldc\",
            \"buildConfig\": \"release\"
        }"
    };
}
```

### Library with Optimization

```d
target("mylib") {
    type: library;
    language: d;
    sources: ["source/lib.d", "source/utils.d"];
    langConfig: {
        "d": "{
            \"compiler\": \"ldc\",
            \"buildConfig\": \"release\",
            \"outputType\": \"staticlib\",
            \"compilerConfig\": {
                \"release\": true,
                \"inline\": true,
                \"boundsCheck\": false,
                \"lto\": true
            }
        }"
    };
}
```

### DUB Project

```d
target("dub-project") {
    type: executable;
    language: d;
    sources: ["source/app.d"];
    langConfig: {
        "d": "{
            \"mode\": \"dub\",
            \"compiler\": \"ldc\",
            \"dub\": {
                \"command\": \"build\",
                \"configuration\": \"release\",
                \"force\": false,
                \"verbose\": true
            }
        }"
    };
}
```

### Testing with Coverage

```d
target("tests") {
    type: test;
    language: d;
    sources: ["source/**/*.d", "tests/**/*.d"];
    langConfig: {
        "d": "{
            \"mode\": \"test\",
            \"buildConfig\": \"unittest-cov\",
            \"test\": {
                \"coverage\": true,
                \"minCoverage\": 80.0,
                \"verbose\": true
            }
        }"
    };
}
```

### BetterC Mode

```d
target("betterc-lib") {
    type: library;
    language: d;
    sources: ["lib.d"];
    langConfig: {
        "d": "{
            \"compiler\": \"ldc\",
            \"buildConfig\": \"release\",
            \"compilerConfig\": {
                \"betterC\": true,
                \"release\": true,
                \"lto\": true,
                \"staticLink\": true
            }
        }"
    };
}
```

### Cross-Compilation

```d
target("arm-binary") {
    type: executable;
    language: d;
    sources: ["main.d"];
    langConfig: {
        "d": "{
            \"compiler\": \"ldc\",
            \"buildConfig\": \"release\",
            \"compilerConfig\": {
                \"targetTriple\": \"arm-linux-gnueabihf\",
                \"sysroot\": \"/usr/arm-linux-gnueabihf\",
                \"release\": true
            }
        }"
    };
}
```

### With Formatting and Linting

```d
target("clean-code") {
    type: executable;
    language: d;
    sources: ["source/**/*.d"];
    langConfig: {
        "d": "{
            \"compiler\": \"ldc\",
            \"buildConfig\": \"release\",
            \"tooling\": {
                \"runFmt\": true,
                \"fmtCheckOnly\": false,
                \"runLint\": true,
                \"lintStyleCheck\": true,
                \"lintSyntaxCheck\": true
            }
        }"
    };
}
```

### Production Build

```d
target("production-server") {
    type: executable;
    language: d;
    sources: ["source/app.d"];
    langConfig: {
        "d": "{
            \"mode\": \"dub\",
            \"compiler\": \"ldc\",
            \"dub\": {
                \"command\": \"build\",
                \"configuration\": \"release\"
            },
            \"compilerConfig\": {
                \"release\": true,
                \"inline\": true,
                \"boundsCheck\": false,
                \"lto\": true,
                \"debugSymbols\": false,
                \"staticLink\": true,
                \"warnings\": true,
                \"warningsAsErrors\": true
            },
            \"tooling\": {
                \"runFmt\": true,
                \"runLint\": true
            }
        }"
    };
}
```

## DUB Detection

The system automatically detects `dub.json` or `dub.sdl` in the project directory and parent directories. If found:

1. Uses DUB for building
2. Parses package metadata (name, version, dependencies)
3. Identifies configurations and build types
4. Extracts source and import paths
5. Resolves sub-packages
6. Auto-configures build options

## Compiler Comparison

### LDC (LLVM D Compiler)
**Best for**: Production builds, optimization, cross-compilation

**Features**:
- LLVM backend for excellent optimization
- Link-time optimization (LTO) support
- Cross-compilation support
- Best performance for release builds
- Slower compilation than DMD

### DMD (Digital Mars D)
**Best for**: Development, fast iteration

**Features**:
- Reference D compiler
- Fastest compilation speed
- Best for development and testing
- Good error messages
- Moderate optimization

### GDC (GCC D Compiler)
**Best for**: GCC ecosystem integration

**Features**:
- GCC backend
- Good optimization
- Integrates with GCC toolchain
- Cross-compilation support
- Generally slower than LDC

## Tooling Integration

### dfmt (Code Formatter)

Automatic code formatting with configurable style:
```json
{
    "tooling": {
        "runFmt": true,
        "fmtCheckOnly": false,
        "fmtConfig": ".dfmtrc"
    }
}
```

### dscanner (Static Analyzer)

Comprehensive static analysis:
```json
{
    "tooling": {
        "runLint": true,
        "lintConfig": "dscanner.ini",
        "lintStyleCheck": true,
        "lintSyntaxCheck": true,
        "lintReport": "stylish"
    }
}
```

### DUB Test

Integrated test runner:
```json
{
    "mode": "test",
    "dub": {
        "command": "test"
    }
}
```

## Best Practices

1. **Use LDC for Production**: LDC provides best optimization and performance
2. **Use DMD for Development**: Fast compilation speeds up iteration
3. **Enable Linting**: Catch issues early with dscanner
4. **Format Code**: Use dfmt for consistent style
5. **Test with Coverage**: Monitor test coverage with unittest-cov
6. **Use DUB for Projects**: Leverage DUB's dependency management
7. **Enable Warnings**: Catch potential issues with `-w`
8. **Static Linking**: Use for portable binaries
9. **LTO for Release**: Enable LTO for final production builds
10. **Version Control**: Use version identifiers for conditional compilation

## Performance Tips

### Fast Development Builds
```json
{
    "compiler": "dmd",
    "buildConfig": "debug"
}
```

### Optimized Release Builds
```json
{
    "compiler": "ldc",
    "buildConfig": "release",
    "compilerConfig": {
        "release": true,
        "inline": true,
        "boundsCheck": false,
        "lto": true
    }
}
```

### Size-Optimized Builds
```json
{
    "compiler": "ldc",
    "buildConfig": "release",
    "compilerConfig": {
        "release": true,
        "boundsCheck": false,
        "betterC": true,
        "staticLink": true
    }
}
```

## Troubleshooting

### Compiler Not Found
Ensure compiler is installed and in PATH:
```bash
# LDC
brew install ldc

# DMD
brew install dmd

# Or download from dlang.org
```

### DUB Not Detected
Specify explicitly:
```json
{
    "dub": {
        "packagePath": "path/to/dub.json"
    }
}
```

### Import Path Issues
Add import paths:
```json
{
    "compilerConfig": {
        "importPaths": ["source", "imports"]
    }
}
```

### Link Errors
Add library paths and libraries:
```json
{
    "compilerConfig": {
        "libPaths": ["/usr/local/lib"],
        "libs": ["ssl", "crypto"]
    }
}
```

## Future Enhancements

- [ ] LDC2 optimization profile templates
- [ ] Incremental compilation support
- [ ] Package registry integration
- [ ] Code coverage HTML reports
- [ ] Advanced dscanner configuration
- [ ] DUB workspace support
- [ ] Multi-architecture builds
- [ ] Profile-guided optimization (PGO)
- [ ] Memory profiling integration
- [ ] Continuous integration templates


