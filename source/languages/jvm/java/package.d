module languages.jvm.java;

/// Java Language Support
///
/// Comprehensive Java build support with Maven, Gradle, and direct javac support.
///
/// Architecture:
///   core/       - Main build handler and configuration
///   tooling/    - JDK detection and version management
///
/// Features:
///   - Multi-build-tool support (Maven, Gradle, direct javac)
///   - JDK version detection
///   - JAR, WAR, EAR packaging
///   - GraalVM native image support
///   - Testing with JUnit
///
/// Usage:
///   import languages.jvm.java;
///   
///   auto handler = new JavaHandler();
///   handler.build(target, config);

public import languages.jvm.java.core;
public import languages.jvm.java.tooling;

