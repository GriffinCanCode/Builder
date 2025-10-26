# Swift Language Support

Comprehensive, modular Swift language support for Builder with modern tooling integration, cross-compilation, and full Swift Package Manager support.

## Architecture

### Core Modules

- **core/config.d** - Comprehensive configuration structs and enums for all Swift features
- **core/handler.d** - Main `SwiftHandler` class implementing build orchestration
- **core/package.d** - Module exports

### Managers

- **managers/spm.d** - Swift Package Manager interface and runners
- **managers/toolchain.d** - Toolchain, SDK, and Xcode management
- **managers/package.d** - Module exports

### Tooling

- **tooling/builders/base.d** - Base builder interface and factory
- **tooling/builders/spm.d** - Swift Package Manager builder
- **tooling/builders/swiftc.d** - Direct swiftc compiler builder
- **tooling/builders/xcode.d** - Xcode build system builder (macOS only)
- **tooling/formatters.d** - SwiftFormat and Apple swift-format integration
- **tooling/checkers.d** - SwiftLint, Swift-DocC, and XCFramework tools
- **tooling/package.d** - Module exports

### Analysis

- **analysis/manifest.d** - Package.swift and Package.resolved parsing
- **analysis/package.d** - Module exports

## Features

### Project Types

- **Executable** - Command-line applications and tools
- **Library** - Static and dynamic libraries
- **SystemModule** - C library wrappers
- **Test** - Unit and integration tests
- **Macro** - Swift macros (Swift 5.9+)
- **Plugin** - Build tool plugins

### Build Systems

1. **Swift Package Manager (SPM)** - Full-featured package manager (recommended)
2. **swiftc** - Direct compiler invocation for simple projects
3. **Xcode** - Xcode build system integration (macOS only)

Auto-detection based on project structure with intelligent fallback.

### Platform Support

- **macOS** - Full support with native toolchain
- **iOS** - Device and Simulator
- **tvOS** - Apple TV platform
- **watchOS** - Apple Watch platform
- **Linux** - Cross-platform Swift support
- **Windows** - Windows Swift support
- **Android** - Experimental Android support

### Toolchain Management

- System Swift toolchain detection
- Xcode-bundled Swift support
- Custom toolchain paths
- Swift snapshot support
- SDK path resolution (macOS)
- Cross-compilation target management

### Code Quality Tools

#### SwiftLint
- Comprehensive linting with 200+ rules
- Strict mode for CI/CD
- Custom rule configuration
- Autocorrect support
- Multiple reporter formats

#### SwiftFormat
- Consistent code formatting
- Support for both SwiftFormat and Apple swift-format
- Custom formatting rules
- In-place or check-only modes

#### Swift-DocC
- Modern documentation generation
- Static site generation
- Hosting-ready output
- Symbol graph generation

### Advanced Features

#### Library Evolution
- Binary framework stability
- ABI-stable interfaces
- Module interface emission
- Versioned API support

#### Optimization Levels
- **None** (-Onone) - No optimization, fast compilation
- **Speed** (-O) - Optimize for execution speed
- **Size** (-Osize) - Optimize for binary size
- **Unchecked** (-Ounchecked) - Aggressive optimization, no runtime checks

#### Build Modes
- **Incremental** - Fast rebuilds with incremental compilation
- **Whole Module** - Full optimization across module boundaries
- **Batch Mode** - Parallel compilation units
- **Index While Building** - IDE integration support

#### Sanitizers
- **Address** - Memory safety issues
- **Thread** - Data races and threading bugs
- **Undefined** - Undefined behavior detection

#### Code Coverage
- Generate coverage data
- Integration with coverage tools
- Per-target coverage tracking

### Package Management

- Automatic dependency resolution
- Version locking with Package.resolved
- Local and remote dependencies
- Git-based dependencies
- Branch/tag/revision pinning
- Private package support

### XCFramework Support

- Universal binary distribution
- Multi-platform frameworks
- Static and dynamic framework variants
- Automatic platform detection
- Internal distribution support

### Cross-Compilation

- Target triple specification
- SDK path configuration
- Architecture selection
- Custom compiler flags per platform

## Configuration Example

```json
{
  "swift": {
    "projectType": "library",
    "buildConfig": "release",
    "optimization": "speed",
    "libraryType": "dynamic",
    "enableLibraryEvolution": true,
    "emitModuleInterface": true,
    "wholeModuleOptimization": true,
    "platforms": [
      {
        "platform": "macos",
        "minVersion": "12.0"
      },
      {
        "platform": "ios",
        "minVersion": "15.0"
      }
    ],
    "swiftlint": {
      "enabled": true,
      "strict": true
    },
    "swiftformat": {
      "enabled": true,
      "lineLength": 120
    },
    "documentation": {
      "enabled": true,
      "outputPath": ".docs"
    },
    "testing": {
      "parallel": true,
      "enableCodeCoverage": true
    }
  }
}
```

## Build Modes

### Standard Build
```json
{
  "mode": "build",
  "buildConfig": "release"
}
```

### Run After Build
```json
{
  "mode": "run",
  "product": "MyApp"
}
```

### Test Execution
```json
{
  "mode": "test",
  "testing": {
    "filter": ["MyTests"],
    "parallel": true,
    "enableCodeCoverage": true
  }
}
```

### Type Check Only
```json
{
  "mode": "check"
}
```

### Generate Xcode Project
```json
{
  "mode": "generate-xcodeproj"
}
```

## Dependency Management

Package.swift manifest is automatically detected and parsed. Dependencies are resolved using SPM's native resolution system.

Example configuration:
```json
{
  "skipUpdate": false,
  "disableAutomaticResolution": false,
  "forceResolvedVersions": false
}
```

## Toolchain Selection

### System Swift (default)
```json
{
  "toolchain": "system"
}
```

### Xcode Swift (macOS)
```json
{
  "toolchain": "xcode"
}
```

### Custom Toolchain
```json
{
  "toolchain": "custom",
  "swiftVersion": {
    "toolchainPath": "/path/to/toolchain"
  }
}
```

### Swift Snapshot
```json
{
  "toolchain": "snapshot",
  "swiftVersion": {
    "snapshot": "swift-DEVELOPMENT-SNAPSHOT-2024-01-01-a"
  }
}
```

## Integration Points

- **CI/CD**: Strict linting, test execution, coverage reporting
- **IDE**: Index-while-building, module interfaces
- **Documentation**: Automatic DocC generation and hosting
- **Distribution**: XCFramework generation for binary distribution
- **Cross-Platform**: Linux/Windows/Android builds from macOS

## Platform-Specific Features

### macOS
- Full Xcode integration
- Framework and XCFramework generation
- Code signing support
- Sandbox configuration

### iOS/tvOS/watchOS
- Device and simulator builds
- App bundle generation
- Provisioning profile handling
- Asset catalog compilation

### Linux
- System Swift or custom toolchain
- Dynamic linking support
- Static binary generation

### Windows
- Windows SDK integration
- DLL and EXE generation
- MSVC compatibility

## Performance Optimizations

- Parallel compilation with configurable job count
- Incremental builds for fast iteration
- Whole-module optimization for release builds
- Batch mode for improved parallelism
- Build caching via SPM

## Language Version Support

- Swift 4.0 through Swift 6.0
- Automatic version detection
- Per-target language version
- Upcoming feature flags
- Experimental feature support

## Best Practices

1. **Use SPM** - Leverages full Swift toolchain capabilities
2. **Enable Library Evolution** - For stable binary distribution
3. **Strict Linting** - Catch issues early with SwiftLint
4. **Code Coverage** - Track test coverage for quality assurance
5. **Documentation** - Generate docs with Swift-DocC
6. **XCFramework** - Distribute binary frameworks universally
7. **Incremental Builds** - Fast iteration during development
8. **Whole Module** - Maximum optimization for release builds

## Extensibility

The modular architecture enables:
- Custom build strategies
- Additional tooling integration
- Platform-specific optimizations
- Build pipeline customization
- Advanced dependency management

## Future Enhancements

- Swift Testing framework support (Swift 6+)
- Hermetic builds
- Remote caching
- Distributed compilation
- Advanced profiling integration
- Memory graph generation

