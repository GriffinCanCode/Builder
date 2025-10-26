module languages.compiled.d;

/// D Language Support
///
/// Comprehensive D build support with DUB integration, multiple compiler support,
/// and advanced tooling (dfmt, dscanner).
///
/// Architecture:
///   core/       - Main build handler and configuration
///   builders/   - DUB and direct compiler builders
///   analysis/   - DUB manifest parsing and module analysis
///   managers/   - Compiler detection and toolchain management
///   tooling/    - dfmt, dscanner, dub test, documentation tools
///
/// Features:
///   - Multi-compiler support (DMD, LDC, GDC)
///   - Full DUB integration (dub.json and dub.sdl)
///   - Advanced build configurations
///   - Code formatting with dfmt
///   - Static analysis with dscanner
///   - Coverage reporting
///   - Cross-compilation support
///   - BetterC mode
///
/// Usage:
///   import languages.compiled.d;
///   
///   auto handler = new DHandler();
///   handler.build(target, config);

public import languages.compiled.d.core;
public import languages.compiled.d.builders;
public import languages.compiled.d.analysis;
public import languages.compiled.d.managers;
public import languages.compiled.d.tooling;


