# C# Language Support

Comprehensive, modular C# language support for the Builder build system with first-class support for modern .NET features including Native AOT, single-file publishing, and cross-platform runtimes.

## Architecture

This module follows a clean, modular architecture inspired by the Kotlin, Java, and TypeScript patterns:

```
csharp/
├── core/                    # Core handler and configuration
│   ├── config.d            # Comprehensive configuration types
│   ├── handler.d           # Main CSharpHandler orchestrator
│   └── package.d           # Public exports
├── managers/               # Build tool integration
│   ├── dotnet.d            # dotnet CLI operations
│   ├── msbuild.d           # MSBuild operations
│   ├── nuget.d             # NuGet package management
│   ├── factory.d           # Build tool factory and detection
│   └── package.d           # Public exports
├── tooling/                # Development tools and utilities
│   ├── builders/           # Build strategy implementations
│   │   ├── base.d          # Builder interface and factory
│   │   ├── standard.d      # Standard build
│   │   ├── publish.d       # Single-file, R2R, trimmed
│   │   ├── aot.d           # Native AOT builder
│   │   └── package.d       # Public exports
│   ├── formatters/         # Code formatting
│   │   ├── base.d          # Formatter interface and factory
│   │   ├── dotnetformat.d  # dotnet-format integration
│   │   ├── csharpier.d     # CSharpier integration
│   │   └── package.d       # Public exports
│   ├── analyzers/          # Static analysis
│   │   ├── base.d          # Analyzer interface and factory
│   │   ├── roslyn.d        # Roslyn analyzer integration
│   │   └── package.d       # Public exports
│   ├── detection.d         # Tool detection and versioning
│   ├── info.d              # .NET SDK and runtime information
│   └── package.d           # Tooling exports
├── analysis/               # Project file parsing
│   ├── project.d           # .csproj parser
│   ├── solution.d          # .sln parser
│   └── package.d           # Analysis exports
├── package.d               # Main module exports
└── README.md               # This file
```

## Features

### 🎯 Core Capabilities

- **Multiple Build Modes**: Standard, Single-File, Native AOT, Ready-to-Run, Trimmed
- **Build Tools**: dotnet CLI (default), MSBuild, direct csc
- **Framework Targets**: .NET 6, 7, 8, 9, .NET Framework 4.x, .NET Standard 2.x
- **Language Versions**: Full support from C# 8 to C# 12+ with latest features
- **Runtime Targets**: Windows, Linux, macOS (x64, ARM64)

### 🚀 Advanced Features

- **Native AOT**: Full Native AOT compilation with size optimization (.NET 7+)
- **Single-File**: Self-contained single-file deployments
- **Ready-to-Run**: R2R ahead-of-time compilation for faster startup
- **IL Trimming**: Tree-shaking unused code for smaller binaries
- **Cross-Platform**: Build for any platform from any platform
- **Project Types**: Console, Library, Web API, Blazor, MAUI, WPF, WinForms

### 🛠️ Tooling Integration

- **Formatters**: dotnet-format (official), CSharpier (opinionated)
- **Analyzers**: Roslyn (built-in), StyleCop, SonarAnalyzer, Roslynator
- **Package Management**: NuGet with full restore, update, and pack support
- **Testing**: xUnit, NUnit, MSTest with code coverage

### 📦 Packaging Options

- **Standard**: Regular DLL or EXE
- **Self-Contained**: Include .NET runtime in output
- **Single-File**: Everything in one executable
- **Native**: Native code via AOT (no runtime needed)
- **NuGet**: Package as .nupkg for distribution

## Configuration

### Basic Console Application

```d
target("my-app") {
    type: executable;
    language: csharp;
    sources: ["src/**/*.cs"];
    
    config: {
        "csharp": "{
            \"framework\": \"net8.0\",
            \"configuration\": \"Release\"
        }"
    };
}
```

### Library with NuGet Packages

```d
target("my-library") {
    type: library;
    language: csharp;
    sources: ["src/**/*.cs"];
    
    config: {
        "csharp": "{
            \"framework\": \"net8.0\",
            \"projectType\": \"library\",
            \"nuget\": {
                \"autoRestore\": true
            }
        }"
    };
}
```

### Native AOT Application

```d
target("native-app") {
    type: executable;
    language: csharp;
    sources: ["src/**/*.cs"];
    
    config: {
        "csharp": "{
            \"mode\": \"nativeaot\",
            \"framework\": \"net8.0\",
            \"runtime\": \"linux-x64\",
            \"aot\": {
                \"enabled\": true,
                \"optimizeForSize\": true,
                \"invariantGlobalization\": true
            }
        }"
    };
}
```

### Single-File Self-Contained

```d
target("portable-app") {
    type: executable;
    language: csharp;
    sources: ["src/**/*.cs"];
    
    config: {
        "csharp": "{
            \"mode\": \"singlefile\",
            \"framework\": \"net8.0\",
            \"runtime\": \"win-x64\",
            \"publish\": {
                \"selfContained\": true,
                \"singleFile\": true,
                \"enableCompressionInSingleFile\": true
            }
        }"
    };
}
```

### Ready-to-Run with Trimming

```d
target("optimized-app") {
    type: executable;
    language: csharp;
    sources: ["src/**/*.cs"];
    
    config: {
        "csharp": "{
            \"mode\": \"readytorun\",
            \"framework\": \"net8.0\",
            \"publish\": {
                \"selfContained\": true,
                \"readyToRun\": true,
                \"trimmed\": true,
                \"trimMode\": \"link\"
            }
        }"
    };
}
```

### With Code Formatting

```d
target("formatted-app") {
    type: executable;
    language: csharp;
    sources: ["src/**/*.cs"];
    
    config: {
        "csharp": "{
            \"framework\": \"net8.0\",
            \"formatter\": {
                \"enabled\": true,
                \"formatter\": \"dotnet-format\",
                \"autoFormat\": true,
                \"verifyNoChanges\": false
            }
        }"
    };
}
```

### With Static Analysis

```d
target("analyzed-app") {
    type: executable;
    language: csharp;
    sources: ["src/**/*.cs"];
    
    config: {
        "csharp": "{
            \"framework\": \"net8.0\",
            \"analysis\": {
                \"enabled\": true,
                \"analyzer\": \"roslyn\",
                \"failOnWarnings\": false,
                \"failOnErrors\": true,
                \"nullable\": true,
                \"warningLevel\": 4
            }
        }"
    };
}
```

### Web API Application

```d
target("api") {
    type: executable;
    language: csharp;
    sources: ["src/**/*.cs"];
    
    config: {
        "csharp": "{
            \"projectType\": \"webapi\",
            \"framework\": \"net8.0\",
            \"configuration\": \"Release\"
        }"
    };
}
```

### With Testing

```d
target("test-suite") {
    type: test;
    language: csharp;
    sources: ["tests/**/*.cs"];
    
    config: {
        "csharp": "{
            \"framework\": \"net8.0\",
            \"test\": {
                \"framework\": \"xunit\",
                \"enabled\": true,
                \"parallel\": true,
                \"coverage\": true,
                \"coverageTool\": \"coverlet\",
                \"minCoverage\": 80.0
            }
        }"
    };
}
```

### NuGet Package

```d
target("my-package") {
    type: library;
    language: csharp;
    sources: ["src/**/*.cs"];
    
    config: {
        "csharp": "{
            \"mode\": \"nuget\",
            \"framework\": \"netstandard2.0\",
            \"nuget\": {
                \"packageId\": \"MyCompany.MyLibrary\",
                \"packageVersion\": \"1.0.0\",
                \"packageLicense\": \"MIT\",
                \"packageAuthors\": [\"Griffin\"],
                \"symbols\": true
            }
        }"
    };
}
```

## Configuration Options

### Build Modes

- **Standard**: Regular build with dotnet build
- **SingleFile**: Self-contained single-file executable
- **ReadyToRun**: R2R with ahead-of-time compilation
- **NativeAOT**: Full native compilation (no runtime)
- **Trimmed**: IL-trimmed build
- **NuGet**: Package as .nupkg
- **Compile**: Compilation only, no packaging

### Build Tools

- **Auto**: Auto-detect (default)
- **DotNet**: dotnet CLI (recommended)
- **MSBuild**: MSBuild directly
- **CSC**: Direct csc compiler
- **None**: Manual control

### Target Frameworks

- **Net8**: .NET 8 LTS (default)
- **Net9**: .NET 9
- **Net7**: .NET 7
- **Net6**: .NET 6 LTS
- **Net48**: .NET Framework 4.8
- **NetStandard20/21**: .NET Standard
- **Custom**: Custom TFM string

### Runtime Identifiers

- **WinX64**: Windows x64
- **WinX86**: Windows x86
- **WinArm64**: Windows ARM64
- **LinuxX64**: Linux x64
- **LinuxArm64**: Linux ARM64
- **OsxX64**: macOS Intel
- **OsxArm64**: macOS Apple Silicon
- **Portable**: No runtime included
- **Custom**: Custom RID string

### Project Types

- **Console**: Console application
- **Library**: Class library
- **WebAPI**: ASP.NET Core Web API
- **WebMVC**: ASP.NET Core MVC
- **BlazorWasm**: Blazor WebAssembly
- **BlazorServer**: Blazor Server
- **MAUI**: .NET MAUI
- **WinForms**: Windows Forms
- **WPF**: WPF application
- **Worker**: Worker service
- **Test**: Test project

### Formatters

- **Auto**: Auto-detect best available
- **DotNetFormat**: Official dotnet-format
- **CSharpier**: Opinionated formatter
- **None**: Skip formatting

### Analyzers

- **Auto**: Auto-detect best available
- **Roslyn**: Built-in Roslyn analyzers
- **StyleCop**: StyleCop analyzers
- **SonarAnalyzer**: SonarAnalyzer for C#
- **Roslynator**: Roslynator analyzers
- **FxCop**: FxCop analyzers
- **None**: Skip analysis

## Language Version Features

The configuration system tracks C# version capabilities:

### C# 8+
- Nullable reference types
- Async streams
- Ranges and indices
- Switch expressions

### C# 9+
- Records
- Top-level statements
- Init-only properties

### C# 10+
- Global usings
- File-scoped namespaces
- Record structs

### C# 11+
- Required members
- Raw string literals
- Generic attributes

### C# 12+
- Primary constructors
- Collection expressions
- Inline arrays

## Design Patterns

### Factory Pattern
All builders, formatters, and analyzers use factories:

```d
auto builder = CSharpBuilderFactory.create(mode, config);
auto formatter = CSharpFormatterFactory.create(formatterType, projectRoot);
auto analyzer = CSharpAnalyzerFactory.create(analyzerType, projectRoot);
```

### Strategy Pattern
Different build strategies for different output types (Standard, AOT, Publish).

### Interface-Based
Clean separation of concerns with interfaces for extensibility:
- `CSharpBuilder` for build strategies
- `CSharpFormatter_` for formatters
- `CSharpAnalyzer_` for analyzers

### Configuration-Driven
All behavior configurable through `CSharpConfig` struct.

## Best Practices

1. **Use dotnet CLI**: Recommended for modern .NET projects
2. **Enable Native AOT**: For high-performance, small-footprint apps (.NET 7+)
3. **Use Single-File**: For easy distribution
4. **Enable Analysis**: Use Roslyn analyzers and nullable reference types
5. **Format Consistently**: Use dotnet-format or CSharpier
6. **Target LTS**: Use .NET 8 (or 6) for long-term support
7. **Test Thoroughly**: xUnit, NUnit, or MSTest with code coverage
8. **Trim Wisely**: Be careful with trimming - test thoroughly
9. **Cross-Compile**: Build for target platforms explicitly
10. **Use .editorconfig**: Consistent style across team

## Performance Characteristics

| Build Mode | Binary Size | Startup Time | Runtime Perf | Disk Usage |
|------------|-------------|--------------|--------------|------------|
| Standard   | Small       | Medium       | Good         | + Runtime  |
| Self-Cont  | Large       | Medium       | Good         | Complete   |
| SingleFile | Large       | Slow         | Good         | Single     |
| R2R        | Very Large  | Fast         | Good         | Complete   |
| Trimmed    | Small       | Medium       | Good         | Reduced    |
| Native AOT | Tiny        | Very Fast    | Excellent    | Minimal    |

| Build Tool | Speed | Features | Recommendation |
|------------|-------|----------|----------------|
| dotnet CLI | Fast  | Full     | Production     |
| MSBuild    | Medium| Good     | Legacy/complex |
| csc        | Fastest| Basic   | Simple projects|

## Integration Examples

### Project Detection

The system automatically detects .csproj files and configures build settings:

```csharp
// .csproj detected → use dotnet CLI
// .sln detected → can build entire solution
// Otherwise → try direct csc
```

### Framework Detection

```csharp
// <TargetFramework>net8.0</TargetFramework> in .csproj
// → Auto-configure for .NET 8
```

### NuGet Restore

```csharp
// PackageReference in .csproj
// → Auto-restore before build
```

## Troubleshooting

### dotnet CLI Not Found
```json
{
    "buildTool": "msbuild"
}
```
Use MSBuild instead.

### Missing SDK
Install .NET SDK from https://dot.net

### Native AOT Errors
```json
{
    "aot": {
        "enabled": true,
        "invariantGlobalization": true
    }
}
```
Enable invariant globalization to reduce dependencies.

### Trimming Issues
```json
{
    "publish": {
        "trimmed": false
    }
}
```
Disable trimming if encountering runtime errors.

### Single-File Extraction Issues
```json
{
    "publish": {
        "includeNativeLibrariesForSelfExtract": true
    }
}
```
Include native libraries if needed.

## Future Enhancements

- [ ] Blazor WebAssembly AOT support
- [ ] .NET Aspire integration
- [ ] Source generators support
- [ ] Code coverage visualization
- [ ] Performance profiling integration
- [ ] Multi-targeting builds
- [ ] Incremental compilation
- [ ] Build caching
- [ ] Custom MSBuild tasks
- [ ] EditorConfig auto-generation
- [ ] Solution-level operations
- [ ] Roslyn scripting support

## Related Documentation

- [Kotlin Language Support](../../jvm/kotlin/README.md) - Similar JVM patterns
- [Java Language Support](../../jvm/java/README.md) - JVM build tools
- [Swift Support](../../compiled/swift/README.md) - Native compilation patterns
- [Builder DSL](../../../../docs/DSL.md) - Configuration syntax
- [Architecture](../../../../docs/ARCHITECTURE.md) - Overall system design

## External Resources

- [.NET Documentation](https://docs.microsoft.com/en-us/dotnet/)
- [C# Language Reference](https://docs.microsoft.com/en-us/dotnet/csharp/)
- [Native AOT](https://docs.microsoft.com/en-us/dotnet/core/deploying/native-aot/)
- [dotnet-format](https://github.com/dotnet/format)
- [CSharpier](https://csharpier.com/)
- [Roslyn Analyzers](https://github.com/dotnet/roslyn-analyzers)

## Examples

See the [csharp-project example](../../../../examples/csharp-project/) for a complete working project demonstrating all features.

