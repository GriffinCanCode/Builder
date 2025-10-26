module languages.jvm.kotlin;

/// Kotlin Language Support
/// 
/// Comprehensive modular Kotlin support with:
/// - Multiple build modes (JAR, Fat JAR, Native, JS, Multiplatform, Android)
/// - Build tool integration (Gradle, Maven, Direct)
/// - Platform targets (JVM, JS, Native, Android, Wasm)
/// - Annotation processing (KAPT, KSP)
/// - Static analysis (detekt, compiler warnings)
/// - Code formatting (ktlint, ktfmt, IntelliJ)
/// - Testing frameworks (kotlin.test, JUnit, Kotest, Spek)
/// - Coroutines support
/// - Multiplatform utilities
/// 
/// Architecture:
///   core/          - Handler and configuration
///   managers/      - Gradle and Maven integration
///   tooling/       - Builders, detection, formatters, processors
///   analysis/      - Static analysis (detekt, compiler)
///   multiplatform/ - Multiplatform project utilities
/// 
/// Usage:
///   import languages.jvm.kotlin;
///   
///   auto handler = new KotlinHandler();
///   auto config = parseKotlinConfig(target);
///   auto result = handler.build(target, workspaceConfig);

public import languages.jvm.kotlin.core;
public import languages.jvm.kotlin.managers;
public import languages.jvm.kotlin.tooling;
public import languages.jvm.kotlin.analysis;
public import languages.jvm.kotlin.multiplatform;

