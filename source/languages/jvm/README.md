# JVM Languages Package

Comprehensive support for JVM-based programming languages in the Builder build system. This package provides unified, modular implementations for Java, Kotlin, and Scala with shared infrastructure for build tools, dependency management, and packaging.

## Overview

The JVM languages package supports three major JVM languages with full-featured, production-ready implementations:

- **Java** - Enterprise-grade Java with Maven/Gradle, multiple packaging modes, static analysis
- **Kotlin** - Modern JVM language with multiplatform, coroutines, Android, and advanced tooling
- **Scala** - Functional programming with sbt/Mill, Scala 2/3, Scala.js, and Scala Native

## Architecture

```
jvm/
├── java/                    # Java language support
│   ├── core/               # Handler and configuration
│   ├── managers/           # Maven and Gradle integration
│   ├── tooling/            # Builders, formatters, detection
│   ├── analysis/           # SpotBugs, PMD, Checkstyle
│   ├── package.d           # Java module exports
│   └── README.md           # Java documentation
├── kotlin/                 # Kotlin language support
│   ├── core/               # Handler and configuration
│   ├── managers/           # Gradle and Maven integration
│   ├── tooling/            # Builders, formatters, detection
│   ├── analysis/           # detekt, compiler warnings
│   ├── multiplatform/      # Multiplatform utilities
│   ├── package.d           # Kotlin module exports
│   └── README.md           # Kotlin documentation
├── scala/                  # Scala language support
│   ├── core/               # Handler and configuration
│   ├── managers/           # sbt, Mill, Maven, Gradle
│   ├── tooling/            # Builders, formatters, checkers
│   ├── analysis/           # Dependency analysis
│   ├── package.d           # Scala module exports
│   └── README.md           # Scala documentation
├── package.d               # JVM package exports (this module)
└── README.md               # This file
```

## Supported Languages

### Java

Enterprise-grade Java support with first-class Maven and Gradle integration.

**Key Features:**
- Build Tools: Maven, Gradle, direct javac
- Build Modes: JAR, Fat JAR, WAR, EAR, Modular JAR, Native Image
- Static Analysis: SpotBugs, PMD, Checkstyle
- Formatters: google-java-format, Eclipse formatter
- Java Versions: 8, 11, 17, 21 (LTS)
- Advanced: Annotation processors (Lombok, MapStruct), GraalVM native

[Full Java Documentation →](java/README.md)

### Kotlin

Modern JVM language with multiplatform capabilities and advanced tooling.

**Key Features:**
- Build Tools: Gradle (Kotlin DSL), Maven, direct kotlinc
- Build Modes: JAR, Fat JAR, Native, JS, Multiplatform, Android
- Platform Targets: JVM, JS (IR), Native, Android, WebAssembly
- Static Analysis: detekt, compiler warnings
- Formatters: ktlint, ktfmt, IntelliJ IDEA
- Advanced: Coroutines, KSP/KAPT, multiplatform, Android

[Full Kotlin Documentation →](kotlin/README.md)

### Scala

Functional programming language with powerful type system and tooling.

**Key Features:**
- Build Tools: sbt, Mill, Scala CLI, Maven, Gradle, Bloop
- Build Modes: JAR, Assembly, Native Image, Scala.js, Scala Native
- Scala Versions: 2.12, 2.13, 3.x (Dotty)
- Static Analysis: Scalafix, WartRemover, Scapegoat
- Formatters: Scalafmt
- Testing: ScalaTest, Specs2, MUnit, uTest, ScalaCheck, ZIO Test

[Full Scala Documentation →](scala/README.md)

## Common Features

All JVM languages share common infrastructure and capabilities:

### 🛠️ Build Tool Integration

- **Maven** - pom.xml parsing, dependency resolution, plugin execution
- **Gradle** - build.gradle/build.gradle.kts, multi-project builds, wrapper support
- **Auto-Detection** - Automatically detect and use appropriate build tool
- **Wrapper Support** - Prefer project wrappers (mvnw, gradlew) for reproducibility

### 📦 Packaging Options

- **JAR** - Standard Java Archive format
- **Fat JAR / Uber JAR** - Single JAR with all dependencies
- **WAR** - Web Application Archive (Java only)
- **Native Executable** - GraalVM native image, Kotlin/Native, Scala Native
- **Modular JAR** - Java 9+ module system
- **Platform-Specific** - Android AAR/APK (Kotlin), Scala.js bundles

### 🧪 Testing Support

- **JUnit 4/5** - Industry-standard testing (all languages)
- **Language-Specific** - kotlin.test, ScalaTest, Specs2, etc.
- **Coverage** - JaCoCo (Java/Kotlin), scoverage (Scala)
- **Parallel Execution** - Multi-threaded test runs

### 🔍 Code Quality

- **Static Analysis** - Language-specific analyzers (SpotBugs, detekt, Scalafix)
- **Linting** - Style enforcement and best practices
- **Formatting** - Consistent code style (google-java-format, ktlint, Scalafmt)
- **Type Checking** - Compile-time safety

### ⚡ Performance Features

- **Incremental Compilation** - Only rebuild changed files
- **Build Caching** - Reuse previous build outputs
- **Parallel Builds** - Multi-threaded compilation
- **Dependency Caching** - Local repository reuse

## Usage

### Import JVM Languages

```d
import languages.jvm;

// All JVM languages are now available
auto javaHandler = new JavaHandler();
auto kotlinHandler = new KotlinHandler();
auto scalaHandler = new ScalaHandler();
```

### Import Specific Language

```d
import languages.jvm.java;
import languages.jvm.kotlin;
import languages.jvm.scala;
```

### Example Target Configuration

#### Java Project
```d
target("java-app") {
    type: executable;
    language: java;
    sources: ["src/main/java/**/*.java"];
    
    config: {
        "java": "{
            \"mode\": \"jar\",
            \"buildTool\": \"maven\",
            \"sourceVersion\": \"17\"
        }"
    };
}
```

#### Kotlin Project
```d
target("kotlin-app") {
    type: executable;
    language: kotlin;
    sources: ["src/main/kotlin/**/*.kt"];
    
    config: {
        "kotlin": "{
            \"mode\": \"jar\",
            \"buildTool\": \"gradle\",
            \"languageVersion\": \"1.9\"
        }"
    };
}
```

#### Scala Project
```d
target("scala-app") {
    type: executable;
    language: scala;
    sources: ["src/main/scala/**/*.scala"];
    
    config: {
        "scala": "{
            \"mode\": \"jar\",
            \"buildTool\": \"sbt\",
            \"scalaVersion\": \"3.3.0\"
        }"
    };
}
```

## Language Comparison

| Feature | Java | Kotlin | Scala |
|---------|------|--------|-------|
| **Type System** | Static | Static with inference | Advanced static with inference |
| **Functional** | Partial (8+) | Yes | Yes (primary paradigm) |
| **Null Safety** | No (Optional) | Built-in | Option type |
| **Concurrency** | Threads, CompletableFuture | Coroutines | Futures, Akka, ZIO |
| **Interop** | Native JVM | Full Java interop | Full Java interop |
| **Build Speed** | Fast | Medium | Slower |
| **Learning Curve** | Gentle | Moderate | Steep |
| **Ecosystem** | Massive | Growing rapidly | Mature |
| **Best For** | Enterprise, Android | Modern apps, Android | Data processing, DSLs |

## Build Tool Comparison

| Build Tool | Java | Kotlin | Scala | Features |
|------------|------|--------|-------|----------|
| **Maven** | ✅ Full | ✅ Full | ✅ Good | XML, plugins, multi-module |
| **Gradle** | ✅ Full | ✅ Full (preferred) | ✅ Good | Kotlin DSL, fast, flexible |
| **sbt** | ❌ | ❌ | ✅ Native | Scala-based, incremental |
| **Mill** | ❌ | ❌ | ✅ Modern | Scala-based, fast, simple |
| **Direct** | ✅ javac | ✅ kotlinc | ✅ scalac | Quick, no deps |

## Version Support

### Java
- **Java 8** - Baseline, lambdas, streams
- **Java 11** - LTS, HTTP client
- **Java 17** - LTS, sealed classes, pattern matching
- **Java 21** - LTS, virtual threads, sequenced collections

### Kotlin
- **1.3+** - Coroutines, inline classes, contracts
- **1.5+** - JVM IR backend, KSP, sealed interfaces
- **1.9+** - Data objects, improved K2 compiler
- **2.0+** - K2 compiler stable

### Scala
- **2.12** - Stable, Java 8 compatible
- **2.13** - Current stable, better collections
- **3.x (Dotty)** - New compiler, simplified syntax, improved types

## Advanced Features

### Multiplatform Support

- **Kotlin** - Full multiplatform with common code, expect/actual
- **Scala** - Scala.js for JavaScript, Scala Native for native binaries
- **Java** - GraalVM native for AOT compilation

### Native Compilation

- **Java** - GraalVM native-image for AOT compilation
- **Kotlin** - Kotlin/Native for platform-specific binaries
- **Scala** - Scala Native for LLVM-based compilation

### Web Development

- **Java** - WAR files for Servlet containers, Spring Boot
- **Kotlin** - Ktor server, Kotlin/JS for frontend
- **Scala** - Play Framework, Akka HTTP, Scala.js

### Mobile Development

- **Java** - Android (legacy)
- **Kotlin** - Android (official), Kotlin Multiplatform Mobile
- **Scala** - Limited Android support

## Best Practices

### Choosing a JVM Language

**Choose Java when:**
- Building enterprise applications with large teams
- Maximum ecosystem compatibility is required
- Long-term stability and support are critical
- Team has Java expertise

**Choose Kotlin when:**
- Building modern Android applications
- Need null safety and concise syntax
- Want multiplatform capabilities (mobile, web, backend)
- Gradual migration from Java

**Choose Scala when:**
- Building data-intensive applications
- Functional programming is a priority
- Need advanced type system features
- Working with big data (Spark, Flink)

### Build Tool Selection

1. **Maven** - Choose for:
   - Enterprise projects with strict standards
   - Multi-module projects
   - Heavy plugin usage
   - Team familiar with XML configuration

2. **Gradle** - Choose for:
   - Modern projects needing flexibility
   - Kotlin/Groovy DSL preference
   - Fast incremental builds
   - Android projects

3. **sbt** - Choose for:
   - Scala-first projects
   - Incremental compilation performance
   - Scala ecosystem integration

4. **Mill** - Choose for:
   - New Scala projects
   - Simple, fast builds
   - Modern Scala tooling

### Packaging Strategy

1. **JAR** - For libraries or when dependencies are managed externally
2. **Fat JAR** - For standalone applications with all dependencies
3. **Native** - For performance-critical or distribution-friendly apps
4. **WAR** - For traditional Java web applications
5. **Platform-Specific** - For Android, JavaScript, or native targets

## Integration with Builder

All JVM languages integrate seamlessly with Builder's core features:

- **Dependency Graph** - Track inter-file and inter-language dependencies
- **Incremental Builds** - Rebuild only what changed
- **Caching** - BLAKE3-based content hashing for build artifacts
- **Parallel Execution** - Multi-threaded compilation and linking
- **Error Recovery** - Graceful handling and helpful error messages
- **Cross-Language** - Mix Java, Kotlin, and Scala in one project

## Performance Characteristics

| Language | Compilation Speed | Runtime Performance | Memory Usage |
|----------|------------------|---------------------|--------------|
| Java | Fast | Excellent | Moderate |
| Kotlin | Moderate | Excellent | Moderate |
| Scala | Slower | Excellent | Higher |

All JVM languages compile to JVM bytecode with similar runtime performance characteristics. Differences in compilation speed are due to type inference complexity and macro systems.

## Contributing

When extending JVM language support:

1. Follow the established modular architecture (core, managers, tooling, analysis)
2. Maintain consistency with existing language patterns
3. Keep individual files focused and under 500 lines
4. Add comprehensive error handling with detailed messages
5. Update relevant README files
6. Add unit and integration tests
7. Ensure cross-language compatibility

## See Also

- [Languages Package](../README.md) - Overview of all language support
- [Java Documentation](java/README.md) - Detailed Java support
- [Kotlin Documentation](kotlin/README.md) - Detailed Kotlin support
- [Scala Documentation](scala/README.md) - Detailed Scala support
- [Builder Architecture](../../../docs/ARCHITECTURE.md) - System design
- [Builder DSL](../../../docs/DSL.md) - Configuration syntax

## External Resources

- [OpenJDK](https://openjdk.org/)
- [Kotlin Language](https://kotlinlang.org/)
- [Scala Language](https://www.scala-lang.org/)
- [Maven](https://maven.apache.org/)
- [Gradle](https://gradle.org/)
- [sbt](https://www.scala-sbt.org/)
- [GraalVM](https://www.graalvm.org/)

