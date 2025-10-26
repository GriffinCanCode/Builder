module languages.compiled.swift.tooling.builders;

/// Swift build system implementations
/// 
/// Modules:
///   base.d   - Base builder interface and factory
///   spm.d    - Swift Package Manager builder
///   swiftc.d - Direct swiftc compiler builder
///   xcode.d  - Xcode build system builder (macOS only)

public import languages.compiled.swift.tooling.builders.base;
public import languages.compiled.swift.tooling.builders.spm;
public import languages.compiled.swift.tooling.builders.swiftc;
public import languages.compiled.swift.tooling.builders.xcode;

