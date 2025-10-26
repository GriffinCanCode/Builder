# Java Language Support

Comprehensive, modular Java language support for Builder with first-class support for Maven, Gradle, and the entire Java ecosystem.

## Architecture

This module follows a clean, modular architecture matching the PHP/Python/Go patterns in the codebase:

```
java/
├── core/            # Core handler and configuration
│   ├── handler.d    # Main JavaHandler orchestrator
│   ├── config.d     # Configuration types, enums, and parsing
│   └── package.d    # Public exports
├── managers/        # Build tool and dependency management
│   ├── maven.d      # Maven pom.xml parsing and operations
│   ├── gradle.d     # Gradle build.gradle parsing and operations
│   ├── factory.d    # Auto-detection and tool selection
│   └── package.d    # Public exports
├── tooling/         # Development tools and utilities
│   ├── detection.d  # Tool detection and availability
│   ├── info.d       # Java version and capability detection
│   ├── builders/    # Build strategy implementations
│   │   ├── base.d           # Builder interface and factory
│   │   ├── jar.d            # Standard JAR builder
│   │   ├── fatjar.d         # Fat JAR (uber-jar) with dependencies
│   │   ├── war.d            # WAR/EAR/RAR web archives
│   │   ├── modular.d        # Java 9+ modular JARs
│   │   ├── native_.d        # GraalVM native image
│   │   └── package.d        # Public exports
│   ├── formatters/  # Code formatting
│   │   ├── base.d           # Formatter interface and factory
│   │   ├── google.d         # google-java-format
│   │   ├── eclipse.d        # Eclipse formatter
│   │   └── package.d        # Public exports
│   ├── processors/  # Annotation processors (Lombok, MapStruct, etc.)
│   └── package.d    # Public exports
├── analysis/        # Static analysis
│   ├── base.d       # Analyzer interface and factory
│   ├── spotbugs.d   # SpotBugs integration
│   ├── pmd.d        # PMD integration
│   ├── checkstyle.d # Checkstyle integration
│   └── package.d    # Public exports
├── package.d        # Main module exports
└── README.md        # This file
```

## Design Philosophy

### Modularity

The architecture separates concerns into distinct, focused modules:
- **core/** - Essential handler and configuration logic
- **managers/** - Build tools (Maven/Gradle) and project detection
- **tooling/** - Development tools, builders, formatters
- **analysis/** - Static analysis and code quality

### Extensibility

Each component uses interfaces and factory patterns:
- New builders can be added without modifying existing code
- Tool detection is automatic with fallback strategies
- Configuration supports auto-detection and explicit specification

### Auto-Detection

Intelligent detection of project configuration:
- Scan for `pom.xml` (Maven) or `build.gradle[.kts]` (Gradle)
- Auto-detect Java version from project files
- Detect wrappers (mvnw, gradlew) and prefer them
- Find main classes automatically
- Detect Spring Boot, Android, and other frameworks

### Type Safety

Strong typing throughout:
- Comprehensive enums for all option types
- Structured configuration with validation
- Result types with detailed error information

## Features

### 🎯 Build Modes

- **JAR** - Standard Java Archive (executable or library)
- **FatJAR** - Uber-jar with all dependencies included
- **WAR** - Web Application Archive (Servlet containers)
- **EAR** - Enterprise Archive (Java EE applications)
- **ModularJAR** - Java 9+ modular JAR with module-info
- **NativeImage** - GraalVM native executable
- **Compile** - Compilation only, no packaging

### 🛠️ Build Tool Integration

**Maven** - Full integration
- pom.xml parsing and analysis
- Dependency resolution
- Plugin execution
- Multi-module projects
- Maven wrapper support

**Gradle** - Full integration
- build.gradle/build.gradle.kts parsing
- Dependency resolution
- Task execution
- Multi-project builds
- Gradle wrapper support

**Direct** - Without build tools
- Direct javac compilation
- Manual classpath management
- Custom JAR creation

### 🔍 Static Analysis

Three major static analyzers with auto-detection:

**SpotBugs** - Bug detection (successor to FindBugs)
- Configurable effort levels
- Priority-based filtering
- XML/HTML/text reports
- Custom exclude filters

**PMD** - Source code analyzer
- Best practices enforcement
- Error-prone pattern detection
- Multiple ruleset categories
- Configurable priority levels

**Checkstyle** - Code style checker
- Google/Sun coding standards
- Custom style configuration
- Detailed violation reports
- Automatic fixing support (limited)

### ✨ Code Formatting

**google-java-format** - Google Style (recommended)
- Fast and deterministic
- Google or AOSP style
- In-place formatting or check-only mode

**Eclipse Formatter** - Eclipse Code Style
- Highly configurable
- Custom format profiles
- Workspace-wide consistency

### 📦 Packaging Options

- **Main Class** - Automatic detection or explicit specification
- **Manifest Attributes** - Custom JAR manifest entries
- **Dependency Inclusion** - Fat JAR with all dependencies
- **Package Relocation** - Shade/relocate for conflict resolution
- **Minimization** - Remove unused classes (ProGuard-style)
- **Sources/Javadoc JARs** - Generate documentation artifacts

### 🚀 Advanced Features

**Java 9+ Module System**
- module-info.java support
- Module path configuration
- Add-exports, add-opens, add-reads
- Modular JAR creation
- jlink integration (future)

**Annotation Processors**
- Lombok support
- MapStruct support
- AutoValue, Dagger, Immutables
- Custom processor configuration
- Processor path management

**GraalVM Native Image**
- AOT compilation to native executable
- Reflection configuration
- Static/dynamic linking
- Initialize-at-build-time configuration
- Custom native-image arguments

**Testing**
- JUnit 4/5 detection and execution
- TestNG support
- Coverage reporting (JaCoCo)
- Parallel test execution

## Configuration

### Basic Example

```json
{
  "java": {
    "mode": "jar",
    "sourceVersion": "17",
    "targetVersion": "17",
    "buildTool": "auto"
  }
}
```

### Complete Configuration

```json
{
  "java": {
    "mode": "fatjar",
    "buildTool": "maven",
    
    "sourceVersion": "21",
    "targetVersion": "21",
    
    "maven": {
      "autoInstall": true,
      "skipTests": false,
      "profiles": ["prod"],
      "goals": ["clean", "package"]
    },
    
    "gradle": {
      "autoInstall": true,
      "tasks": ["build"],
      "buildType": "release"
    },
    
    "packaging": {
      "mainClass": "com.example.Main",
      "includeDependencies": true,
      "createSourcesJar": true,
      "manifestAttributes": {
        "Implementation-Version": "1.0.0"
      }
    },
    
    "analysis": {
      "enabled": true,
      "analyzer": "spotbugs",
      "failOnErrors": true,
      "effort": "max",
      "threshold": "medium"
    },
    
    "formatter": {
      "enabled": true,
      "formatter": "google-java-format",
      "autoFormat": true
    },
    
    "modules": {
      "enabled": false,
      "moduleName": "com.example.app",
      "addModules": ["java.sql"]
    },
    
    "processors": {
      "enabled": true,
      "lombok": true,
      "mapstruct": true
    },
    
    "nativeImage": {
      "enabled": false,
      "staticImage": false,
      "noFallback": true
    },
    
    "test": {
      "framework": "junit5",
      "coverage": true,
      "parallel": true
    }
  }
}
```

## Usage Examples

### Simple JAR

```d
target("hello-world") {
    type: executable;
    language: java;
    sources: ["Main.java"];
    
    java: {
        mode: "jar",
        packaging: {
            mainClass: "Main"
        }
    };
}
```

### Maven Project

```d
target("spring-boot-app") {
    type: executable;
    language: java;
    sources: ["src/main/java/**/*.java"];
    
    java: {
        buildTool: "maven",
        maven: {
            autoInstall: true,
            profiles: ["prod"]
        }
    };
}
```

### Fat JAR with Dependencies

```d
target("standalone-app") {
    type: executable;
    language: java;
    sources: ["src/**/*.java"];
    
    java: {
        mode: "fatjar",
        sourceVersion: "17",
        packaging: {
            mainClass: "com.example.Application",
            includeDependencies: true
        }
    };
}
```

### WAR for Web Application

```d
target("webapp") {
    type: executable;
    language: java;
    sources: ["src/main/java/**/*.java"];
    
    java: {
        mode: "war",
        buildTool: "gradle",
        gradle: {
            tasks: ["war"]
        }
    };
}
```

### Modular JAR (Java 9+)

```d
target("modular-lib") {
    type: library;
    language: java;
    sources: ["src/main/java/**/*.java", "src/main/java/module-info.java"];
    
    java: {
        mode: "modular-jar",
        sourceVersion: "21",
        modules: {
            enabled: true,
            moduleName: "com.example.lib",
            addModules: ["java.sql", "java.xml"]
        }
    };
}
```

### GraalVM Native Image

```d
target("native-app") {
    type: executable;
    language: java;
    sources: ["src/**/*.java"];
    
    java: {
        mode: "native-image",
        sourceVersion: "21",
        packaging: {
            mainClass: "com.example.Main"
        },
        nativeImage: {
            enabled: true,
            staticImage: false,
            noFallback: true,
            initializeAtBuildTime: ["com.example.config"]
        }
    };
}
```

### With Static Analysis and Formatting

```d
target("quality-app") {
    type: executable;
    language: java;
    sources: ["src/main/java/**/*.java"];
    
    java: {
        mode: "jar",
        
        formatter: {
            enabled: true,
            formatter: "google-java-format",
            autoFormat: true
        },
        
        analysis: {
            enabled: true,
            analyzer: "spotbugs",
            failOnErrors: true,
            effort: "max"
        },
        
        packaging: {
            mainClass: "com.example.Main"
        }
    };
}
```

## Java Version Support

The module intelligently adapts to different Java versions:

- **Java 8** - Baseline support, lambdas, streams
- **Java 9+** - Module system, jlink
- **Java 10+** - Local variable type inference (var)
- **Java 11** - LTS, HTTP client, single-file launch
- **Java 14+** - Records, pattern matching (preview)
- **Java 15+** - Text blocks, sealed classes
- **Java 17** - LTS, sealed classes final, pattern matching
- **Java 21** - LTS, virtual threads, sequenced collections

The handler automatically detects available features and adjusts compilation flags accordingly.

## Build Tool Detection

The system automatically detects build tools in this order:

1. Check for `pom.xml` → Maven
2. Check for `build.gradle` or `build.gradle.kts` → Gradle
3. Check for `build.xml` → Ant
4. Fall back to direct javac compilation

Wrappers (mvnw/gradlew) are preferred when available for better reproducibility.

## Annotation Processor Support

Common annotation processors are auto-detected and configured:

- **Lombok** - Boilerplate reduction
- **MapStruct** - Bean mapping
- **AutoValue** - Immutable value classes
- **Dagger** - Dependency injection
- **Immutables** - Immutable object generation

## Framework Detection

The module detects and optimizes for common frameworks:

- **Spring Boot** - Auto-configures fat JAR mode
- **Android** - Detects Android Gradle plugin
- **Quarkus** - Native image optimization
- **Micronaut** - GraalVM native support

## Performance Optimizations

- **Incremental Compilation** - Leverages javac's incremental mode
- **Parallel Builds** - Maven/Gradle parallel execution
- **Build Caching** - Respects Maven/Gradle caches
- **Dependency Caching** - Local repository reuse

## Best Practices

1. **Use build tools** - Maven or Gradle for dependency management
2. **Enable analysis** - Catch bugs early with SpotBugs/PMD
3. **Auto-format** - Consistent style with google-java-format
4. **Target LTS versions** - Java 11, 17, or 21
5. **Use modules** - Java 9+ module system for better encapsulation
6. **Native images** - GraalVM for fast startup and low memory
7. **Test coverage** - Enable JaCoCo for comprehensive testing

## Integration with Builder

This module integrates seamlessly with Builder's:
- Dependency graph system
- Incremental builds
- Caching mechanism (BLAKE3-based)
- Parallel execution
- Error handling and recovery

## Future Enhancements

- [ ] jlink integration for custom JRE creation
- [ ] JPackage support for installers
- [ ] Enhanced Android build support
- [ ] Kotlin/Scala co-compilation
- [ ] Advanced ProGuard/R8 integration
- [ ] Container image generation
- [ ] CI/CD pipeline templates

## Comparison to Other Languages

| Feature | Java | Python | Go | PHP |
|---------|------|--------|----|----|
| Build Tools | Maven, Gradle | pip, poetry | go build | Composer |
| Modules | Yes (9+) | Yes | Yes | No |
| Native Compilation | GraalVM | PyInstaller | Native | No |
| Static Analysis | SpotBugs, PMD | mypy, pylint | golangci-lint | PHPStan |
| Formatters | google-java-format | ruff, black | gofmt | PHP-CS-Fixer |

## Contributing

When extending this module:
1. Follow the established patterns (see PHP/Go modules)
2. Keep files small and focused (< 500 lines)
3. Add comprehensive error handling
4. Update this README
5. Maintain strong typing
6. Add tests for new features

## Resources

- [Maven Documentation](https://maven.apache.org/guides/)
- [Gradle Documentation](https://docs.gradle.org/)
- [Java Module System](https://www.oracle.com/corporate/features/understanding-java-9-modules.html)
- [GraalVM Native Image](https://www.graalvm.org/reference-manual/native-image/)
- [google-java-format](https://github.com/google/google-java-format)
- [SpotBugs](https://spotbugs.github.io/)
- [PMD](https://pmd.github.io/)

