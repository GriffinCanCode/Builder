# Scala Language Support

Comprehensive, modular Scala language support for the Builder build system with first-class support for the entire Scala ecosystem.

## Architecture

This module follows a clean, modular architecture matching the patterns established in the codebase:

```
scala/
├── core/                # Core handler and configuration
│   ├── handler.d        # Main ScalaHandler orchestrator
│   ├── config.d         # Configuration types, enums, and parsing
│   └── package.d        # Public exports
├── managers/            # Build tool management
│   ├── sbt.d            # sbt build tool operations
│   ├── mill.d           # Mill build tool operations
│   └── package.d        # Public exports
├── tooling/             # Development tools and builders
│   ├── builders/        # Build strategy implementations
│   │   ├── base.d       # Builder interface and factory
│   │   ├── jar.d        # Standard JAR compilation
│   │   ├── assembly.d   # Fat JAR (uber-jar) with dependencies
│   │   ├── native_.d    # GraalVM native-image
│   │   ├── scalajs.d    # Scala.js JavaScript output
│   │   ├── scalanative.d # Scala Native LLVM compilation
│   │   └── package.d    # Public exports
│   ├── formatters/      # Code formatting
│   │   ├── base.d       # Formatter interface and factory
│   │   ├── scalafmt.d   # Scalafmt integration
│   │   └── package.d    # Public exports
│   ├── checkers/        # Static analysis and linting
│   │   ├── base.d       # Checker interface and factory
│   │   ├── scalafix.d   # Scalafix linter/refactoring
│   │   ├── wartremover.d # WartRemover functional purity
│   │   ├── scapegoat.d  # Scapegoat static analysis
│   │   └── package.d    # Public exports
│   ├── detection.d      # Tool and project detection
│   ├── info.d           # Version and capability detection
│   └── package.d        # Public exports
├── analysis/            # Dependency analysis
│   ├── dependencies.d   # Dependency extraction and analysis
│   └── package.d        # Public exports
├── package.d            # Main module exports
└── README.md            # This file
```

## Features

### 🎯 Core Capabilities

- **Scala Versions**: Full support for Scala 2.12, 2.13, and Scala 3 (Dotty)
- **Build Tools**: sbt, Mill, Scala CLI, Maven, Gradle, Bloop, Direct scalac
- **Build Modes**: JAR, Assembly (fat JAR), GraalVM Native Image, Scala.js, Scala Native
- **Auto-Detection**: Intelligent detection of build tools, Scala versions, and project structure

### 🛠️ Build Tools

#### sbt (Scala Build Tool)
- Primary build tool for Scala
- Multi-module project support
- Plugin integration (sbt-assembly, sbt-native-packager, etc.)
- Interactive and batch modes
- BSP (Build Server Protocol) support

#### Mill
- Modern alternative to sbt
- Fast incremental compilation
- Simple configuration with build.sc
- Assembly and module support

#### Scala CLI
- Lightweight scripting tool
- Quick prototyping and single-file builds
- Power mode for advanced features

#### Others
- Maven with scala-maven-plugin
- Gradle with Scala plugin
- Bloop build server
- Direct scalac compilation

### 📦 Build Modes

#### JAR (Standard)
- Compile Scala to JVM bytecode
- Package as standard JAR
- Library or executable output

#### Assembly (Fat JAR)
- Bundle all dependencies
- Single executable JAR
- Uses sbt-assembly or Mill assembly

#### GraalVM Native Image
- Compile to native binary
- No JVM required at runtime
- Fast startup, low memory footprint
- Ahead-of-time (AOT) compilation

#### Scala.js
- Compile Scala to JavaScript
- Browser or Node.js targets
- Fast/Full optimization modes
- Source maps support
- Module kinds: NoModule, CommonJS, ESModule

#### Scala Native
- Compile to native via LLVM
- No JVM required
- Direct system access
- Multiple GC options: immix, boehm, none
- Link-time optimization (LTO)

### 🧪 Testing Frameworks

- **ScalaTest**: Most popular, flexible matchers and styles
- **Specs2**: BDD-style specifications
- **MUnit**: Lightweight, fast, great IDE support
- **uTest**: Minimal, simple assertions
- **ScalaCheck**: Property-based testing
- **ZIO Test**: Functional effect testing

### 🎨 Code Quality

#### Scalafmt (Formatting)
- Opinionated code formatter
- Customizable via `.scalafmt.conf`
- Auto-format before build option
- Check-only mode for CI

#### Scalafix (Linting/Refactoring)
- Automated refactoring tool
- Custom rules and migrations
- Scala 2 to Scala 3 migration support
- Code style enforcement

#### WartRemover
- Functional purity linter
- Compiler plugin integration
- Prevent dangerous patterns

#### Scapegoat
- Static code analysis
- Bug detection
- Code smell identification

### ⚙️ Compiler Features

#### Optimization Levels
- **None**: Fast compilation, no optimization
- **Basic**: Inlining and basic optimizations
- **Aggressive**: Maximum optimization (slower compilation)

#### Scala 2 Features
- Implicits, higher-kinded types
- Type classes
- Macros (Scala 2.13+)
- All language features

#### Scala 3 Features
- Given/using (replaces implicits)
- Extension methods
- Opaque types
- Union and intersection types
- Match types
- Context functions
- Polymorphic function types
- Safe initialization

### 📊 Configuration

Comprehensive configuration via `langConfig` in Builderfile:

```scala
target "myapp" {
  type: executable
  sources: ["src/**/*.scala"]
  
  langConfig: {
    scala: {
      version: "3.3.0"
      buildTool: "sbt"
      mode: "assembly"
      
      compiler: {
        optimization: "basic"
        warnings: true
        warningsAsErrors: true
        deprecation: true
        feature: true
        unchecked: true
        experimental: true  // Scala 3 only
        target: "1.8"
        languageFeatures: ["higherKinds", "implicitConversions"]
        options: ["-Xlint", "-Ywarn-unused"]
      }
      
      test: {
        framework: "scalatest"
        enabled: true
        coverage: true
        parallel: true
      }
      
      formatter: {
        enabled: true
        formatter: "scalafmt"
        autoFormat: true
        configFile: ".scalafmt.conf"
      }
      
      linter: {
        enabled: true
        linter: "scalafix"
        failOnWarnings: false
        rules: ["OrganizeImports", "RemoveUnused"]
      }
      
      nativeImage: {
        enabled: false
        staticImage: false
        noFallback: true
        quickBuild: false
      }
      
      scalaJs: {
        enabled: false
        mode: "fastOpt"  // or "fullOpt"
        moduleKind: "ESModule"
        sourceMaps: true
        esVersion: "es2015"
      }
      
      scalaNative: {
        enabled: false
        mode: "release"
        lto: true
        gc: "immix"
        multithreading: false
      }
    }
  }
}
```

## Design Philosophy

### Modularity
- Each component has a single, well-defined responsibility
- Clear interfaces between components
- Easy to extend with new builders, formatters, or checkers

### Auto-Detection
- Intelligent detection of build tools from project structure
- Scala version detection from build files
- Test framework detection from dependencies
- Minimize configuration needed

### Delegation Pattern
- Handler delegates to specialized components
- Builders handle different output modes
- Formatters and checkers are pluggable
- Build tool managers encapsulate tool-specific operations

### Extensibility
- Factory pattern for creating components
- Interface-based design
- Easy to add new:
  - Build tools (implement manager operations)
  - Build modes (implement ScalaBuilder interface)
  - Formatters (implement Formatter interface)
  - Checkers (implement Checker interface)

### Strong Typing
- Comprehensive enums for all options
- Type-safe configuration
- Version-aware feature detection
- Reduces runtime errors

## Advanced Features

### Multi-Module Projects
- Automatic detection of multi-module sbt projects
- Dependency graph resolution
- Incremental compilation across modules

### Cross-Compilation
- Build for multiple Scala versions
- Binary compatibility checks
- Version-specific optimizations

### Performance
- Incremental compilation via Zinc
- Parallel compilation when supported
- Build caching and artifact reuse
- Memory-tuned JVM options based on project size

### IDE Integration
- Metals language server compatibility
- BSP (Build Server Protocol) support
- Source maps for debugging
- Scaladoc generation

## Usage Examples

### Simple Executable
```d
target "hello" {
  type: executable
  sources: ["Hello.scala"]
  langConfig: {
    scala: {
      version: "2.13.10"
    }
  }
}
```

### Multi-Module Library
```d
target "core" {
  type: library
  sources: ["core/src/**/*.scala"]
}

target "app" {
  type: executable
  sources: ["app/src/**/*.scala"]
  deps: ["core"]
}
```

### Scala.js Application
```d
target "webapp" {
  type: executable
  sources: ["src/**/*.scala"]
  langConfig: {
    scala: {
      version: "3.3.0"
      mode: "scalajs"
      scalaJs: {
        enabled: true
        mode: "fullOpt"
        moduleKind: "ESModule"
      }
    }
  }
}
```

### GraalVM Native Image
```d
target "native-app" {
  type: executable
  sources: ["src/**/*.scala"]
  langConfig: {
    scala: {
      mode: "nativeImage"
      nativeImage: {
        enabled: true
        mainClass: "com.example.Main"
        staticImage: true
        noFallback: true
      }
    }
  }
}
```

## Best Practices

1. **Use sbt for complex projects**: Best ecosystem support and plugins
2. **Use Mill for simple projects**: Faster, simpler configuration
3. **Use Scala CLI for scripts**: Quick prototyping and single files
4. **Enable formatters**: Consistent code style across team
5. **Enable linters in CI**: Catch issues early
6. **Use assembly for deployment**: Single JAR simplifies distribution
7. **Consider native images**: For CLI tools and microservices
8. **Use property-based testing**: ScalaCheck for robust tests
9. **Leverage Scala 3 features**: When possible, for better safety
10. **Profile before optimizing**: Use appropriate optimization level

## Troubleshooting

### Common Issues

**Issue**: Compilation fails with "scalac not found"
- **Solution**: Install Scala or use sbt/Mill which bundle Scala

**Issue**: Assembly conflicts with dependencies
- **Solution**: Use shade/relocation in sbt-assembly configuration

**Issue**: Native image fails with reflection errors
- **Solution**: Add reflection configuration in `reflect-config.json`

**Issue**: Scala.js module not found
- **Solution**: Ensure sbt-scalajs plugin is installed

**Issue**: Tests not detected
- **Solution**: Check test framework is in dependencies

## Novel Features

1. **Unified Builder Pattern**: All build modes use same interface
2. **Smart Auto-Detection**: Minimizes configuration needed
3. **Pluggable Components**: Easy to extend and customize
4. **Version-Aware**: Feature detection based on Scala version
5. **Multi-Target Support**: JVM, JS, Native from same source
6. **Integrated Quality Tools**: Format, lint, test in one system
7. **Performance Tuning**: Automatic JVM memory configuration
8. **Comprehensive Error Handling**: Clear, actionable error messages

## Future Enhancements

- [ ] Scala Metals LSP integration
- [ ] Coursier direct integration for dependency resolution
- [ ] sbt server protocol for faster builds
- [ ] Automatic migration helpers (Scala 2 → 3)
- [ ] Build cache sharing
- [ ] Distributed compilation support
- [ ] Advanced profiling integration
- [ ] Custom rule sets for Scalafix
- [ ] Automated benchmarking

## Contributing

When extending Scala support:

1. Follow the modular architecture
2. Add appropriate tests
3. Update documentation
4. Use factory patterns for new components
5. Maintain backward compatibility
6. Add configuration options to config.d
7. Update this README

## License

Part of the Builder build system.

