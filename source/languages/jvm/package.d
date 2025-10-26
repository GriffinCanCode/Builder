module languages.jvm;

/// JVM Languages Package
/// 
/// This package contains comprehensive handlers for JVM-based languages including:
///   - Java (Maven, Gradle, multiple build modes, static analysis)
///   - Kotlin (multiplatform, coroutines, KSP, Android)
///   - Scala (sbt, Mill, Scala 2/3, Scala.js, Scala Native)
///
/// All JVM languages share common infrastructure for:
///   - Build tool integration (Maven, Gradle)
///   - Dependency management
///   - JAR packaging and variants
///   - Testing frameworks
///   - Static analysis and formatting
///   - Native compilation support

public import languages.jvm.java;
public import languages.jvm.kotlin;
public import languages.jvm.scala;

