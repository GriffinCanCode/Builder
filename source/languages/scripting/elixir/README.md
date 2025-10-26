# Elixir Language Support

Comprehensive, modular Elixir language support for the Builder build system with first-class support for the entire BEAM VM ecosystem.

## Architecture

This module follows a clean, modular architecture inspired by established patterns in the codebase:

```
elixir/
├── core/               # Core handler and configuration
│   ├── handler.d       # Main orchestrator - delegates to specialized components
│   ├── config.d        # Comprehensive configuration types and enums
│   └── package.d       # Public exports
├── managers/           # Package and version management
│   ├── mix.d           # Mix project parser and runner
│   ├── hex.d           # Hex package management
│   ├── releases.d      # Release builders (Mix, Distillery, Burrito, Bakeware)
│   ├── versions.d      # Version management (asdf, kiex)
│   └── package.d       # Public exports
├── tooling/            # Development tools
│   ├── builders/       # Project type builders
│   │   ├── base.d      # Builder interface and factory
│   │   ├── script.d    # Simple .ex/.exs scripts
│   │   ├── mix.d       # Standard OTP applications
│   │   ├── phoenix.d   # Phoenix web applications
│   │   ├── umbrella.d  # Multi-app umbrella projects
│   │   ├── escript.d   # Standalone executables
│   │   ├── nerves.d    # Embedded systems firmware
│   │   └── package.d   # Public exports
│   ├── formatters/     # Code formatting
│   │   ├── base.d      # Mix format wrapper
│   │   └── package.d   # Public exports
│   ├── checkers/       # Static analysis
│   │   ├── dialyzer.d  # Type analysis and PLT management
│   │   ├── credo.d     # Static code analysis
│   │   └── package.d   # Public exports
│   ├── docs/           # Documentation
│   │   ├── generator.d # ExDoc wrapper
│   │   └── package.d   # Public exports
│   ├── detection.d     # Project type detection
│   ├── tools.d         # Tool availability checking
│   └── package.d       # Public exports
├── analysis/           # Code and dependency analysis
│   ├── dependencies.d  # Dependency graph parsing
│   └── package.d       # Public exports
├── package.d           # Main module exports
└── README.md           # This file
```

## Features

### 🎯 Core Capabilities

- **Project Types**: Full support for all Elixir project types
  - Simple scripts (.ex/.exs files)
  - Mix projects (OTP applications)
  - Phoenix web applications
  - Phoenix LiveView applications
  - Umbrella projects (multi-app architecture)
  - Libraries (for Hex publishing)
  - Escript (standalone executables)
  - Nerves (embedded systems firmware)

- **Build Systems**: Complete build pipeline support
  - Mix compilation with all environments (dev, test, prod, custom)
  - Protocol consolidation
  - Compiler options and flags
  - Debug info control
  - Warnings as errors

- **Release Management**: Multiple release strategies
  - Mix Release (Elixir 1.9+, recommended)
  - Distillery (legacy)
  - Burrito (cross-platform wrapped executables)
  - Bakeware (self-extracting executables)
  - ERTS inclusion/exclusion
  - Runtime configuration
  - Cookie management for distributed Erlang

### 🛠️ Tooling Integration

- **Code Quality**:
  - **mix format**: Code formatting with check mode
  - **Dialyzer**: Type analysis and discrepancy detection
  - **Dialyxir**: Enhanced Dialyzer with better output
  - **Credo**: Static code analysis with configurable checks
  - PLT management and incremental analysis

- **Package Management**:
  - **Hex**: Package publishing and management
  - Private Hex organizations
  - Package validation and building
  - Version resolution

- **Documentation**:
  - **ExDoc**: Generate beautiful HTML/EPUB documentation
  - API reference generation
  - Custom pages and guides
  - Logo and theming support

- **Testing**:
  - **ExUnit**: Native test runner
  - Coverage analysis with ExCoveralls
  - Test tagging and filtering
  - Trace mode for debugging
  - Configurable timeouts and parallelism

### 🚀 Advanced Features

- **Phoenix Support**:
  - Asset compilation (esbuild, webpack, vite)
  - Asset digesting for production
  - Database migrations (Ecto)
  - LiveView detection
  - PubSub configuration
  - Endpoint management

- **Umbrella Projects**:
  - Multi-app builds
  - Shared dependencies
  - Selective app compilation
  - App exclusion

- **Nerves (Embedded)**:
  - Target system configuration
  - Firmware building
  - Artifact management
  - Provisioning support

- **Version Management**:
  - asdf integration (.tool-versions)
  - kiex support (legacy)
  - Elixir/OTP version detection
  - Custom interpreter paths

- **Environment Variables**:
  - MIX_ENV control
  - Custom environment variables
  - ERL_FLAGS and ELIXIR_FLAGS
  - CGO-style configuration

## Configuration

Elixir configuration can be specified in the target's `langConfig` under the `elixir` or `elixirConfig` key:

```d
// Example Builderfile DSL
target("my_app:executable") {
    language: elixir,
    sources: ["lib/**/*.ex"],
    elixir: {
        projectType: "phoenix",
        env: "prod",
        phoenix: {
            enabled: true,
            liveView: true,
            compileAssets: true,
            digestAssets: true
        },
        format: {
            enabled: true,
            checkFormatted: true
        },
        dialyzer: {
            enabled: true,
            format: "dialyxir"
        },
        credo: {
            enabled: true,
            strict: true
        },
        release: {
            type: "mixrelease",
            name: "my_app",
            includeErts: true
        }
    }
}
```

### Configuration Types

- **ElixirProjectType**: Script, MixProject, Phoenix, PhoenixLiveView, Umbrella, Library, Nerves, Escript
- **MixEnv**: Dev, Test, Prod, Custom
- **ReleaseType**: None, MixRelease, Distillery, Burrito, Bakeware
- **OTPAppType**: Application, Library, Umbrella, Task

### Phoenix Configuration

```d
phoenix: {
    enabled: true,
    liveView: true,
    ecto: true,
    database: "postgres",
    compileAssets: true,
    assetTool: "esbuild",  // or "webpack", "vite"
    runMigrations: true,
    digestAssets: true,
    port: 4000
}
```

### Testing Configuration

```d
test: {
    testPaths: ["test"],
    testPattern: "*_test.exs",
    trace: false,
    maxCases: 4,
    timeout: 60000,
    captureLog: true,
    colors: true
}
```

### Quality Tools Configuration

```d
dialyzer: {
    enabled: true,
    pltFile: "_build/dialyzer.plt",
    pltApps: ["erts", "kernel", "stdlib"],
    format: "dialyxir"
},
credo: {
    enabled: true,
    strict: false,
    minPriority: "normal",
    configFile: ".credo.exs"
},
format: {
    enabled: true,
    checkFormatted: false,
    inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"]
}
```

## Usage Examples

### Simple Mix Project

```d
target("my_lib:library") {
    language: elixir,
    sources: ["lib/**/*.ex"],
    elixir: {
        projectType: "library",
        installDeps: true,
        depsGet: true
    }
}
```

### Phoenix Application with LiveView

```d
target("my_phoenix:executable") {
    language: elixir,
    sources: ["lib/**/*.ex"],
    elixir: {
        projectType: "phoenix",
        env: "prod",
        phoenix: {
            enabled: true,
            liveView: true,
            ecto: true,
            compileAssets: true,
            digestAssets: true
        },
        installDeps: true,
        release: {
            type: "mixrelease",
            includeErts: true
        }
    }
}
```

### Umbrella Project

```d
target("my_umbrella:executable") {
    language: elixir,
    sources: ["apps/**/*.ex"],
    elixir: {
        projectType: "umbrella",
        umbrella: {
            appsDir: "apps",
            buildAll: true,
            sharedDeps: true
        }
    }
}
```

### Nerves Embedded System

```d
target("my_nerves:executable") {
    language: elixir,
    sources: ["lib/**/*.ex"],
    elixir: {
        projectType: "nerves",
        nerves: {
            enabled: true,
            target: "rpi3",
            provisioning: true
        }
    }
}
```

## Auto-Detection

The Elixir handler automatically detects:

- **Project Type**: From mix.exs dependencies and structure
- **Phoenix Applications**: Presence of `:phoenix` dependency
- **LiveView**: Presence of `:phoenix_live_view` dependency
- **Umbrella Projects**: `apps/` directory or `apps_path:` in mix.exs
- **Nerves Projects**: `:nerves` dependency
- **Escript**: `escript:` configuration in mix.exs
- **Version Management**: .tool-versions file (asdf)

## Design Principles

This module embodies several key design principles:

### 1. **Modularity**
- Clear separation of concerns
- Each module has a single, well-defined responsibility
- Easy to extend and test

### 2. **Type Safety**
- Strong typing throughout
- Comprehensive enums for all options
- Compile-time validation

### 3. **Extensibility**
- Factory patterns for builders and managers
- Interface-based design for flexibility
- Easy to add new project types or tools

### 4. **Convention over Configuration**
- Sensible defaults for all options
- Auto-detection of project structure
- Minimal configuration required

### 5. **BEAM Ecosystem First**
- Deep integration with Mix
- Support for OTP principles
- Respect for Elixir idioms

## Dependencies

### Required
- Elixir 1.11+ (recommended 1.15+)
- Erlang/OTP 23+ (recommended 26+)
- Mix (bundled with Elixir)

### Optional
- Hex (for package management)
- Dialyxir (enhanced Dialyzer)
- Credo (static analysis)
- ExDoc (documentation)
- ExCoveralls (test coverage)
- Phoenix (for Phoenix projects)
- Nerves (for embedded projects)
- asdf or kiex (version management)

## Performance Considerations

- **Incremental Compilation**: Leverages Mix's incremental compilation
- **Protocol Consolidation**: Optimizes protocol dispatch
- **PLT Caching**: Dialyzer PLT is cached and reused
- **Parallel Testing**: ExUnit runs tests in parallel by default
- **Asset Compilation**: Modern tools (esbuild, vite) for fast builds

## Future Enhancements

Potential areas for expansion:

- **Livebook Integration**: Support for Livebook notebooks
- **Broadway**: Stream processing pipelines
- **Nx/Axon**: Numerical computing and ML
- **Scenic**: GUI applications
- **Membrane**: Multimedia processing
- **gRPC/Protobuf**: Code generation support
- **Property Testing**: StreamData integration
- **Benchmarking**: Benchee integration

## Contributing

When adding new features:

1. Follow the existing modular structure
2. Add comprehensive documentation
3. Include usage examples
4. Maintain type safety
5. Keep functions small and focused
6. Write clear error messages

## References

- [Elixir Language](https://elixir-lang.org/)
- [Mix Build Tool](https://hexdocs.pm/mix/)
- [Hex Package Manager](https://hex.pm/)
- [Phoenix Framework](https://www.phoenixframework.org/)
- [Nerves Project](https://nerves-project.org/)
- [Dialyzer](https://www.erlang.org/doc/man/dialyzer.html)
- [Credo](https://github.com/rrrene/credo)
- [ExDoc](https://hexdocs.pm/ex_doc/)

