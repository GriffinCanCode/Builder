# Kotlin Language Support

Comprehensive, modular Kotlin language support for the Builder build system with first-class support for modern Kotlin features including multiplatform, coroutines, KSP, and Android.

## Architecture

This module follows a clean, modular architecture inspired by the TypeScript, Rust, and Java patterns in the codebase:

```
kotlin/
├── core/                    # Core handler and configuration
│   ├── config.d            # Comprehensive configuration types
│   ├── handler.d           # Main KotlinHandler orchestrator
│   └── package.d           # Public exports
├── managers/               # Build tool integration
│   ├── gradle.d            # Gradle operations and metadata parsing
│   ├── maven.d             # Maven operations and POM parsing
│   └── package.d           # Public exports
├── tooling/                # Development tools and utilities
│   ├── builders/           # Build strategy implementations
│   │   ├── base.d          # Builder interface and factory
│   │   ├── jar.d           # Standard JAR builder
│   │   ├── fatjar.d        # Fat JAR with dependencies
│   │   ├── native_.d       # Kotlin/Native compiler
│   │   ├── js.d            # Kotlin/JS compiler (IR backend)
│   │   ├── multiplatform.d # Multiplatform project builder
│   │   ├── android.d       # Android AAR/APK builder
│   │   └── package.d       # Public exports
│   ├── detection.d         # Tool detection and versioning
│   ├── formatters/         # Code formatting
│   │   ├── base.d          # Formatter interface and factory
│   │   ├── ktlint.d        # ktlint integration (official style)
│   │   ├── ktfmt.d         # ktfmt integration (Google style)
│   │   ├── intellij.d      # IntelliJ IDEA formatter
│   │   └── package.d       # Public exports
│   ├── processors/         # Annotation processing
│   │   └── package.d       # KAPT and KSP integration
│   └── package.d           # Tooling exports
├── analysis/               # Static analysis
│   └── package.d           # detekt and compiler warnings
├── multiplatform/          # Multiplatform utilities
│   └── package.d           # Target detection and validation
├── package.d               # Main module exports
└── README.md               # This file
```

## Features

### 🎯 Core Capabilities

- **Multiple Build Modes**: JAR, Fat JAR, Native, JS, Multiplatform, Android
- **Build Tools**: Gradle (Kotlin DSL), Maven, Direct kotlinc
- **Platform Targets**: JVM, JS (IR backend), Native, Android, WebAssembly
- **Language Versions**: Full support from Kotlin 1.3 to 2.0+ with K2 compiler
- **JVM Targets**: Java 8, 11, 17, 21 compatibility

### 🚀 Advanced Features

- **Multiplatform**: Full KMP support with hierarchical structure, expect/actual
- **Kotlin/Native**: Cross-compilation, C interop, static linking
- **Kotlin/JS**: IR backend, source maps, multiple module systems
- **Android**: AAR/APK builds, multiple variants, R8/ProGuard
- **Coroutines**: kotlinx-coroutines with flow, channels, debug mode
- **Annotation Processing**: KAPT (legacy) and KSP (modern symbol processing)

### 🛠️ Tooling Integration

- **Formatters**: ktlint (official), ktfmt (Google), IntelliJ IDEA
- **Static Analysis**: detekt (comprehensive), compiler warnings
- **Build Tools**: Gradle wrapper, Maven integration, direct compilation
- **Testing**: kotlin.test, JUnit 4/5, Kotest, Spek

### 📦 Packaging Options

- **JAR**: Standard JAR with optional Kotlin runtime
- **Fat JAR**: Uber JAR with all dependencies (Shadow plugin)
- **Native**: Platform-specific executables
- **Android**: AAR (libraries) or APK (applications)
- **JS**: UMD, CommonJS, AMD module formats

## Configuration

### Basic JAR Build

```d
target("my-app") {
    type: executable;
    language: kotlin;
    sources: ["src/main/kotlin/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"jar\",
            \"buildTool\": \"gradle\",
            \"languageVersion\": \"1.9\",
            \"jvmTarget\": \"17\"
        }"
    };
}
```

### Fat JAR with Dependencies

```d
target("uber-jar") {
    type: executable;
    language: kotlin;
    sources: ["src/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"fatjar\",
            \"buildTool\": \"gradle\",
            \"packaging\": {
                \"mainClass\": \"com.example.MainKt\",
                \"includeDependencies\": true
            }
        }"
    };
}
```

### Kotlin Multiplatform

```d
target("multiplatform-lib") {
    type: library;
    language: kotlin;
    sources: ["src/commonMain/kotlin/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"multiplatform\",
            \"buildTool\": \"gradle\",
            \"multiplatform\": {
                \"enabled\": true,
                \"targets\": [\"jvm\", \"js\", \"native\"],
                \"hierarchical\": true
            }
        }"
    };
}
```

### Kotlin/Native Executable

```d
target("native-app") {
    type: executable;
    language: kotlin;
    sources: ["src/nativeMain/kotlin/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"native\",
            \"native\": {
                \"enabled\": true,
                \"target\": \"linuxX64\",
                \"optimization\": \"release\",
                \"staticLink\": true
            }
        }"
    };
}
```

### Android Library

```d
target("android-lib") {
    type: library;
    language: kotlin;
    sources: ["src/main/kotlin/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"android\",
            \"buildTool\": \"gradle\",
            \"android\": {
                \"enabled\": true,
                \"compileSdk\": 34,
                \"minSdk\": 21,
                \"targetSdk\": 34,
                \"enableR8\": true
            }
        }"
    };
}
```

### With Coroutines

```d
target("async-app") {
    type: executable;
    language: kotlin;
    sources: ["src/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"jar\",
            \"coroutines\": {
                \"enabled\": true,
                \"version\": \"1.8.0\",
                \"flow\": true,
                \"channels\": true,
                \"debug\": true
            }
        }"
    };
}
```

### With Annotation Processing (KSP)

```d
target("codegen-app") {
    type: executable;
    language: kotlin;
    sources: ["src/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"jar\",
            \"processors\": {
                \"enabled\": true,
                \"type\": \"ksp\",
                \"processors\": [
                    \"com.google.devtools.ksp:symbol-processing-api:1.9.0-1.0.13\"
                ],
                \"incremental\": true
            }
        }"
    };
}
```

### With Static Analysis

```d
target("analyzed-app") {
    type: executable;
    language: kotlin;
    sources: ["src/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"jar\",
            \"analysis\": {
                \"enabled\": true,
                \"analyzer\": \"detekt\",
                \"failOnWarnings\": false,
                \"failOnErrors\": true,
                \"detektParallel\": true
            }
        }"
    };
}
```

### With Code Formatting

```d
target("formatted-app") {
    type: executable;
    language: kotlin;
    sources: ["src/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"jar\",
            \"formatter\": {
                \"enabled\": true,
                \"formatter\": \"ktlint\",
                \"autoFormat\": true,
                \"ktlintAndroidStyle\": false
            }
        }"
    };
}
```

### With Testing

```d
target("test-suite") {
    type: test;
    language: kotlin;
    sources: ["src/test/kotlin/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"test\": {
                \"framework\": \"junit5\",
                \"parallel\": true,
                \"coverage\": true,
                \"coverageTool\": \"kover\",
                \"coverageThreshold\": 80
            }
        }"
    };
}
```

## Configuration Options

### Build Modes

- **JAR**: Standard JAR library or executable
- **FatJAR**: Uber JAR with all dependencies
- **Native**: Kotlin/Native executable
- **JS**: Kotlin/JS bundle
- **Multiplatform**: Kotlin Multiplatform project
- **Android**: Android AAR/APK
- **Compile**: Compilation only, no packaging

### Build Tools

- **Auto**: Auto-detect from project structure
- **Gradle**: Gradle with Kotlin DSL (recommended)
- **Maven**: Maven with Kotlin plugin
- **Direct**: Direct kotlinc compilation
- **None**: Manual control

### Compilers

- **Auto**: Auto-detect best available
- **KotlinC**: Official kotlinc (JVM)
- **KotlinNative**: Kotlin/Native compiler
- **KotlinJS**: Kotlin/JS compiler (IR backend)
- **KotlinJVM**: Kotlin/JVM compiler (optimized)

### Platform Targets

- **JVM**: JVM bytecode (default)
- **JS**: JavaScript (IR backend)
- **Native**: Native binary (platform-specific)
- **Common**: Common multiplatform code
- **Android**: Android platform
- **Wasm**: WebAssembly (experimental)

### Testing Frameworks

- **Auto**: Auto-detect from dependencies
- **KotlinTest**: kotlin.test
- **JUnit5**: JUnit 5 (Jupiter)
- **JUnit4**: JUnit 4
- **Kotest**: Kotest framework
- **Spek**: Spek framework
- **None**: Skip testing

### Analyzers

- **Auto**: Auto-detect best available
- **Detekt**: Comprehensive static analysis
- **KtLint**: Style checking (also a formatter)
- **Compiler**: Compiler warnings only
- **None**: Skip analysis

### Formatters

- **Auto**: Auto-detect best available
- **KtLint**: Official Kotlin style
- **KtFmt**: Google style
- **IntelliJ**: IntelliJ IDEA formatter
- **None**: Skip formatting

## Language Version Features

The configuration system tracks Kotlin version capabilities:

### Kotlin 1.3+
- Coroutines
- Inline classes
- Contracts

### Kotlin 1.4+
- Kotlin/JS IR backend

### Kotlin 1.5+
- JVM IR backend
- KSP support
- Sealed interfaces

### Kotlin 1.6+
- Context receivers (experimental)

### Kotlin 1.9+
- Data objects

### Kotlin 2.0+
- K2 compiler

## Design Patterns

### Factory Pattern
All builders, formatters, and analyzers use factories for creation:

```d
auto builder = KotlinBuilderFactory.create(mode, config);
auto formatter = KotlinFormatterFactory.create(formatterType);
auto analyzer = AnalyzerFactory.create(analyzerType);
```

### Strategy Pattern
Different build strategies for different output types (JAR, Native, JS, etc.)

### Interface-Based
Clean separation of concerns with interfaces for extensibility:
- `KotlinBuilder` for build strategies
- `KotlinFormatter_` for formatters
- `StaticAnalyzer` for analysis tools

### Configuration-Driven
All behavior configurable through `KotlinConfig` struct

## Best Practices

1. **Use Gradle for Modern Projects**: Gradle with Kotlin DSL is the recommended build tool
2. **Enable KSP over KAPT**: KSP is faster and more efficient than KAPT
3. **Use Multiplatform for Cross-Platform**: Leverage KMP for maximum code sharing
4. **Enable Static Analysis**: Use detekt for code quality
5. **Format Consistently**: Use ktlint or ktfmt for consistent style
6. **Target Latest LTS Java**: Use Java 17 or 21 for JVM projects
7. **Enable Coroutines**: Use coroutines for async/concurrent code
8. **Use K2 Compiler**: Enable K2 compiler (Kotlin 2.0+) for better performance
9. **Incremental Compilation**: Keep incremental compilation enabled
10. **Progressive Mode**: Enable progressive mode for stricter checks

## Performance Characteristics

| Build Tool | Speed | Features | Recommendation |
|------------|-------|----------|----------------|
| Gradle     | Fast  | Full     | Production     |
| Maven      | Medium| Good     | Legacy projects|
| Direct     | Fastest| Basic   | Quick prototypes|

| Compiler   | Speed | Output  | Use Case |
|------------|-------|---------|----------|
| kotlinc    | 1x    | JVM     | Standard |
| kotlin-native| 2-5x | Native  | Performance |
| kotlinc-js | 1-2x  | JS      | Web apps |

## Integration Examples

### Gradle Project Detection

The system automatically detects Gradle projects and uses the wrapper:

```kotlin
// build.gradle.kts detected → use Gradle
// gradlew/gradlew.bat detected → use wrapper
// Otherwise → direct kotlinc
```

### Maven Project Detection

```kotlin
// pom.xml detected → use Maven
// Otherwise → try Gradle or direct kotlinc
```

### Multiplatform Detection

```kotlin
// kotlin("multiplatform") in build.gradle.kts
// → Enable multiplatform mode
// → Detect available targets
// → Build all or specific targets
```

## Troubleshooting

### Compiler Not Found
```json
{
    "buildTool": "gradle"
}
```
Use Gradle/Maven instead of direct compilation.

### Missing Dependencies
```json
{
    "gradle": {
        "autoInstall": true
    }
}
```
Enable automatic dependency installation.

### Native Target Not Available
```json
{
    "native": {
        "target": "linuxX64"
    }
}
```
Ensure Kotlin/Native compiler is installed.

### Android SDK Not Found
```json
{
    "android": {
        "enabled": true
    }
}
```
Set `ANDROID_HOME` or `ANDROID_SDK_ROOT` environment variable.

## Future Enhancements

- [ ] Kotlin Script (.kts) execution support
- [ ] Incremental compilation caching
- [ ] Build cache integration
- [ ] Gradle composite builds
- [ ] Maven multi-module projects
- [ ] Custom KSP processor development
- [ ] Kotlin Symbol Processing API integration
- [ ] Kotlin compiler plugins
- [ ] Dokka documentation generation
- [ ] Kover code coverage visualization
- [ ] Gradle version catalogs
- [ ] Convention plugins for reusable build logic

## Related Documentation

- [Java Language Support](../java/README.md) - JVM patterns
- [TypeScript Support](../../scripting/typescript/README.md) - Multi-compiler pattern
- [Rust Support](../../compiled/rust/README.md) - Advanced build configuration
- [Builder DSL](../../../../docs/DSL.md) - Configuration syntax
- [Architecture](../../../../docs/ARCHITECTURE.md) - Overall system design

## External Resources

- [Kotlin Documentation](https://kotlinlang.org/docs/)
- [Kotlin Multiplatform](https://kotlinlang.org/docs/multiplatform.html)
- [KSP Documentation](https://kotlinlang.org/docs/ksp-overview.html)
- [detekt](https://detekt.dev/)
- [ktlint](https://ktlint.github.io/)
- [Gradle Kotlin DSL](https://docs.gradle.org/current/userguide/kotlin_dsl.html)

