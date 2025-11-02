module config.macros;

/// Builder Programmability System - Tier 2: D-Based Macros
/// 
/// For advanced users who need full D power for complex build logic.
/// Provides compile-time code generation using D's metaprogramming features.
/// 
/// Architecture:
///   ctfe       - Compile-time function execution
///   compiler   - D code compilation interface
///   loader     - Dynamic macro loading
///   api        - Macro API for target generation
/// 
/// Features:
///   - Full D language access
///   - Compile-time code generation via CTFE
///   - Templates and mixins
///   - Type-safe with D's type system
///   - Zero runtime overhead when using CTFE
/// 
/// Example:
///   // Builderfile.d
///   import builder.macros;
///   
///   Target[] generateMicroservices(string[] services) {
///       return services.map!(name =>
///           Target(name, executable, go, ["services/" ~ name ~ "/**/*.go"])
///       ).array;
///   }

public import config.macros.api;
public import config.macros.ctfe;
public import config.macros.compiler;
public import config.macros.loader;

