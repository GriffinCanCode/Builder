module languages.dotnet.fsharp.platforms;

/// F# Platforms Package
/// 
/// Cross-platform support for F#:
/// - Fable: F# to JavaScript/TypeScript compilation (implemented in builders)
/// - WASM: WebAssembly via Fable
/// - Native: Native AOT compilation (implemented in builders)
///
/// Note: Platform support is primarily implemented through builders.
/// This package serves as a documentation and organization point.

// Platforms are implemented in the builders package
public import languages.dotnet.fsharp.tooling.builders.fable;
public import languages.dotnet.fsharp.tooling.builders.native;

