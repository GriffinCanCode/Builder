module languages.compiled.swift;

/// Comprehensive Swift language support for Builder
/// 
/// Architecture:
///   core/       - Configuration and build handler
///   managers/   - Swift Package Manager and toolchain management
///   tooling/    - Builders, formatters, and linters
///   analysis/   - Package manifest and dependency analysis
/// 
/// Features:
///   - Swift Package Manager (SPM) integration
///   - Direct swiftc compilation
///   - Xcode build system support (macOS)
///   - Cross-compilation support
///   - SwiftLint integration
///   - SwiftFormat integration
///   - Swift-DocC documentation generation
///   - XCFramework generation
///   - Multiple platform targets (macOS, iOS, Linux, Windows)
///   - Library evolution support
///   - Module interface emission
///   - Sanitizers (address, thread, undefined)
///   - Code coverage
///   - Advanced optimization options
/// 
/// Usage:
///   import languages.compiled.swift;
///   
///   auto handler = new SwiftHandler();
///   auto result = handler.build(target, config);

public import languages.compiled.swift.core;
public import languages.compiled.swift.managers;
public import languages.compiled.swift.tooling;
public import languages.compiled.swift.analysis;

