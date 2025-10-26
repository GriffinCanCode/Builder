# F# Language Support

Comprehensive, modular F# language support for the Builder build system with first-class support for functional programming, modern .NET features, F# Interactive, and cross-platform compilation.

## Architecture

This module follows a clean, modular architecture inspired by the Kotlin and other JVM language patterns in the codebase:

```
fsharp/
├── core/                   # Core handler and configuration
│   ├── config.d            # Comprehensive configuration types
│   ├── handler.d           # Main FSharpHandler orchestrator
│   └── package.d           # Public exports
├── managers/               # Build tool and package manager integration
│   ├── dotnet.d            # .NET CLI operations
│   ├── fake.d              # FAKE build system
│   ├── paket.d             # Paket package manager
│   ├── nuget.d             # NuGet package manager
│   └── package.d           # Public exports
├── tooling/                # Development tools and utilities
│   ├── builders/           # Build strategy implementations
│   │   ├── base.d          # Builder interface and factory
│   │   ├── library.d       # DLL library builder
│   │   ├── executable.d    # Executable builder
│   │   ├── script.d        # F# Interactive script runner
│   │   ├── fable.d         # Fable (F# to JS/TS) compiler
│   │   ├── native.d        # Native AOT compiler
│   │   └── package.d       # Public exports
│   ├── formatters/         # Code formatting
│   │   ├── base.d          # Formatter interface and factory
│   │   ├── fantomas.d      # Fantomas formatter integration
│   │   └── package.d       # Public exports
│   ├── analyzers/          # Static analysis
│   │   ├── base.d          # Analyzer interface and factory
│   │   ├── lint.d          # FSharpLint integration
│   │   ├── compiler.d      # Compiler warnings analyzer
│   │   └── package.d       # Public exports
│   ├── testers/            # Test framework integration
│   │   ├── base.d          # Tester interface and factory
│   │   ├── expecto.d       # Expecto (functional testing)
│   │   ├── xunit.d         # xUnit integration
│   │   ├── nunit.d         # NUnit integration
│   │   └── package.d       # Public exports
│   ├── packagers/          # Package creation
│   │   ├── base.d          # Packager interface
│   │   ├── nuget.d         # NuGet packager
│   │   └── package.d       # Public exports
│   ├── detection.d         # Tool detection and versioning
│   └── package.d           # Tooling exports
├── analysis/               # Static analysis integration
│   └── package.d           # Analysis exports
├── platforms/              # Cross-platform support
│   └── package.d           # Platform exports
├── interactive/            # F# Interactive support
│   └── package.d           # FSI exports
├── package.d               # Main module exports
└── README.md               # This file
```

## Features

### 🎯 Core Capabilities

- **Multiple Build Modes**: Library, Executable, Script, Fable (JS/TS), Native AOT, WASM
- **Build Tools**: dotnet CLI, FAKE, direct fsc compiler
- **Package Managers**: NuGet, Paket
- **Language Versions**: Full support for F# 4.x, 5.x, 6.x, 7.x, 8.x
- **.NET Targets**: .NET 6+, .NET Framework, .NET Standard

### 🚀 Advanced Features

- **F# Interactive (FSI)**: Script execution, REPL capabilities
- **Fable**: F# to JavaScript/TypeScript compilation with module systems
- **Native AOT**: .NET 7+ native ahead-of-time compilation
- **FAKE Build**: F# Make build system integration
- **Paket**: Deterministic package management
- **Functional Testing**: Expecto framework support

### 🛠️ Tooling Integration

- **Formatters**: Fantomas (official F# formatter)
- **Analyzers**: FSharpLint, compiler warnings
- **Testing**: Expecto, xUnit, NUnit, FsUnit, Unquote
- **Package Creation**: NuGet packaging

### 📦 Build Modes

- **Library**: DLL libraries for reuse
- **Executable**: Console and GUI applications
- **Script**: F# Interactive scripts (.fsx)
- **Fable**: JavaScript or TypeScript output
- **Native**: Platform-specific native executables
- **WASM**: WebAssembly via Fable

## Configuration

### Basic Library Build

```d
target("fsharp-lib") {
    type: library;
    language: fsharp;
    sources: ["src/**/*.fs"];
    
    config: {
        "fsharp": "{
            \"mode\": \"library\",
            \"buildTool\": \"dotnet\",
            \"dotnet\": {
                \"framework\": \"net8.0\",
                \"configuration\": \"Release\"
            }
        }"
    };
}
```

### Executable with Optimization

```d
target("fsharp-app") {
    type: executable;
    language: fsharp;
    sources: ["src/**/*.fs"];
    
    config: {
        "fsharp": "{
            \"mode\": \"executable\",
            \"buildTool\": \"dotnet\",
            \"optimize\": true,
            \"tailcalls\": true,
            \"dotnet\": {
                \"framework\": \"net8.0\",
                \"configuration\": \"Release\"
            }
        }"
    };
}
```

### F# Interactive Script

```d
target("fsharp-script") {
    type: custom;
    language: fsharp;
    sources: ["scripts/build.fsx"];
    
    config: {
        "fsharp": "{
            \"mode\": \"script\",
            \"fsi\": {
                \"enabled\": true,
                \"loadScripts\": [\"scripts/lib.fsx\"],
                \"references\": [\"packages/FSharp.Core.dll\"]
            }
        }"
    };
}
```

### Fable (JavaScript/TypeScript)

```d
target("fsharp-fable") {
    type: library;
    language: fsharp;
    sources: ["src/**/*.fs"];
    
    config: {
        "fsharp": "{
            \"mode\": \"fable\",
            \"platform\": \"javascript\",
            \"fable\": {
                \"enabled\": true,
                \"outDir\": \"dist\",
                \"moduleSystem\": \"es6\",
                \"typescript\": false,
                \"sourceMaps\": true,
                \"optimize\": true
            }
        }"
    };
}
```

### Native AOT Executable

```d
target("fsharp-native") {
    type: executable;
    language: fsharp;
    sources: ["src/**/*.fs"];
    
    config: {
        "fsharp": "{
            \"mode\": \"native\",
            \"buildTool\": \"dotnet\",
            \"native\": {
                \"enabled\": true,
                \"optimization\": \"speed\",
                \"staticLink\": true
            },
            \"dotnet\": {
                \"framework\": \"net8.0\",
                \"runtime\": \"linux-x64\",
                \"selfContained\": true
            }
        }"
    };
}
```

### FAKE Build System

```d
target("fake-build") {
    type: custom;
    language: fsharp;
    sources: ["build.fsx"];
    
    config: {
        "fsharp": "{
            \"buildTool\": \"fake\",
            \"fake\": {
                \"scriptFile\": \"build.fsx\",
                \"target\": \"Build\",
                \"parallel\": true
            }
        }"
    };
}
```

### With Paket Package Manager

```d
target("paket-project") {
    type: library;
    language: fsharp;
    sources: ["src/**/*.fs"];
    
    config: {
        "fsharp": "{
            \"mode\": \"library\",
            \"packageManager\": \"paket\",
            \"paket\": {
                \"enabled\": true,
                \"autoRestore\": true,
                \"generateLoadScripts\": true
            }
        }"
    };
}
```

### With Fantomas Formatting

```d
target("formatted-lib") {
    type: library;
    language: fsharp;
    sources: ["src/**/*.fs"];
    
    config: {
        "fsharp": "{
            \"mode\": \"library\",
            \"formatter\": {
                \"enabled\": true,
                \"formatter\": \"fantomas\",
                \"autoFormat\": true,
                \"maxLineLength\": 120,
                \"indentSize\": 4
            }
        }"
    };
}
```

### With FSharpLint Analysis

```d
target("analyzed-lib") {
    type: library;
    language: fsharp;
    sources: ["src/**/*.fs"];
    
    config: {
        "fsharp": "{
            \"mode\": \"library\",
            \"analysis\": {
                \"enabled\": true,
                \"analyzer\": \"fsharplint\",
                \"failOnErrors\": true,
                \"warningLevel\": 4
            }
        }"
    };
}
```

### With Expecto Testing

```d
target("fsharp-tests") {
    type: test;
    language: fsharp;
    sources: ["tests/**/*.fs"];
    
    config: {
        "fsharp": "{
            \"test\": {
                \"framework\": \"expecto\",
                \"parallel\": true,
                \"coverage\": true,
                \"coverageTool\": \"coverlet\"
            }
        }"
    };
}
```

### Self-Contained Single-File Executable

```d
target("standalone-app") {
    type: executable;
    language: fsharp;
    sources: ["src/**/*.fs"];
    
    config: {
        "fsharp": "{
            \"mode\": \"executable\",
            \"dotnet\": {
                \"framework\": \"net8.0\",
                \"runtime\": \"linux-x64\",
                \"selfContained\": true,
                \"singleFile\": true,
                \"readyToRun\": true,
                \"trimmed\": true
            }
        }"
    };
}
```

## Configuration Options

### Build Modes

- **Library**: DLL library
- **Executable**: EXE application
- **Script**: F# Interactive script
- **Fable**: JavaScript/TypeScript via Fable
- **Wasm**: WebAssembly via Fable
- **Native**: Native AOT executable
- **Compile**: Compilation only, no packaging

### Build Tools

- **Auto**: Auto-detect from project structure
- **Dotnet**: dotnet CLI (recommended)
- **FAKE**: F# Make build system
- **Direct**: Direct fsc compiler invocation
- **None**: Manual control

### Package Managers

- **Auto**: Auto-detect from project
- **NuGet**: Standard .NET package manager
- **Paket**: Deterministic package manager
- **None**: No package manager

### Testing Frameworks

- **Auto**: Auto-detect from dependencies
- **Expecto**: Functional F# testing framework
- **XUnit**: Popular .NET testing framework
- **NUnit**: Traditional .NET testing framework
- **FsUnit**: F# wrappers for NUnit/xUnit
- **Unquote**: Assertions with F# quotations
- **None**: Skip testing

### Analyzers

- **Auto**: Auto-detect best available
- **FSharpLint**: Comprehensive F# linter
- **Compiler**: Compiler warnings only
- **Ionide**: Ionide LSP (IDE integration)
- **None**: Skip analysis

### Formatters

- **Auto**: Auto-detect best available
- **Fantomas**: Official F# code formatter
- **None**: Skip formatting

## Language Version Features

The configuration system tracks F# version capabilities:

### F# 4.6+
- Anonymous records
- Span support
- ValueOption

### F# 5.0+
- Nameof operator
- Open type declarations
- String interpolation
- Applicative computation expressions

### F# 6.0+
- Task computation expressions
- Implicit yields
- Index from end syntax

### F# 7.0+
- As patterns
- Extended fixed bindings
- Required properties

### F# 8.0+
- FromTheEnd slicing
- Extended string interpolation
- Improved type inference

## Design Patterns

### Factory Pattern
All builders, formatters, analyzers, and testers use factories:

```d
auto builder = FSharpBuilderFactory.create(mode, config);
auto formatter = FSharpFormatterFactory.create(formatterType);
auto analyzer = FSharpAnalyzerFactory.create(analyzerType);
auto tester = FSharpTesterFactory.create(testFramework);
```

### Strategy Pattern
Different build strategies for different output types.

### Interface-Based
Clean separation of concerns with interfaces for extensibility:
- `FSharpBuilder` for build strategies
- `FSharpFormatter_` for formatters
- `FSharpAnalyzer_` for analyzers
- `FSharpTester` for test runners

### Configuration-Driven
All behavior configurable through `FSharpConfig` struct.

## Best Practices

1. **Use dotnet CLI for Modern Projects**: dotnet build is the recommended approach
2. **Enable Tail Call Optimization**: Use `tailcalls: true` for recursive functions
3. **Use Paket for Deterministic Builds**: Consider Paket for enterprise projects
4. **Format with Fantomas**: Maintain consistent F# style
5. **Analyze with FSharpLint**: Catch issues early
6. **Test with Expecto**: Leverage functional testing
7. **Target Latest .NET**: Use .NET 8+ for best performance
8. **Use F# Interactive**: Leverage FSI for scripting and experimentation
9. **Enable Optimization**: Set `optimize: true` for production builds
10. **Consider Native AOT**: Use for performance-critical applications

## Performance Characteristics

| Build Tool | Speed | Features | Recommendation |
|------------|-------|----------|----------------|
| dotnet CLI | Fast  | Full     | Production     |
| FAKE       | Medium| Advanced | Complex builds |
| Direct fsc | Fastest| Basic   | Simple projects|

| Compiler Mode | Speed | Output Size | Use Case |
|---------------|-------|-------------|----------|
| Standard      | 1x    | Normal      | Development |
| Optimized     | 1x    | Smaller     | Production |
| Native AOT    | 2-3x  | Smallest    | Performance critical |

## Integration Examples

### Project Detection

The system automatically detects project types:

```fsharp
// .fsproj detected → use dotnet build
// build.fsx detected → use FAKE
// paket.dependencies detected → use Paket
// Otherwise → direct fsc
```

### Fable Integration

```fsharp
// Fable compiles F# to JavaScript/TypeScript
// Supports ES6, CommonJS, AMD module systems
// Source maps, optimization, watch mode
```

## Troubleshooting

### Compiler Not Found
```json
{
    "buildTool": "dotnet"
}
```
Use dotnet CLI instead of direct fsc.

### Package Restore Failed
```json
{
    "packageManager": "paket",
    "paket": {
        "autoRestore": true
    }
}
```
Enable automatic package restoration.

### Native AOT Not Available
Ensure .NET 7+ is installed:
```bash
dotnet --version  # Should be 7.0 or higher
```

### Fable Not Found
Install Fable as a tool:
```bash
dotnet tool install -g fable
```

## Future Enhancements

- [ ] F# compiler service integration
- [ ] Incremental compilation caching
- [ ] F# Analyzers framework support
- [ ] Ionide language server integration
- [ ] F# Data type providers
- [ ] Saturn/Giraffe web framework support
- [ ] Bolero WebAssembly framework
- [ ] FsCheck property-based testing
- [ ] Fake.dotnet.Cli integration improvements
- [ ] F# notebook (.dib) support

## Related Documentation

- [Kotlin Language Support](../../jvm/kotlin/README.md) - Similar modular pattern
- [C# Language Support](../csharp.d) - .NET ecosystem
- [Builder DSL](../../../../docs/DSL.md) - Configuration syntax
- [Architecture](../../../../docs/ARCHITECTURE.md) - Overall system design

## External Resources

- [F# Language Reference](https://learn.microsoft.com/en-us/dotnet/fsharp/)
- [F# for Fun and Profit](https://fsharpforfunandprofit.com/)
- [Fantomas](https://fsprojects.github.io/fantomas/)
- [FSharpLint](https://fsprojects.github.io/FSharpLint/)
- [Expecto](https://github.com/haf/expecto)
- [Fable](https://fable.io/)
- [FAKE](https://fake.build/)
- [Paket](https://fsprojects.github.io/Paket/)

