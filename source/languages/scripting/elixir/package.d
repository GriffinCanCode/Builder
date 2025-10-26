module languages.scripting.elixir;

/// Comprehensive Elixir Language Support
///
/// This module provides complete, modular Elixir support for the Builder build system
/// with first-class support for the BEAM VM ecosystem.
///
/// Architecture:
/// ```
/// elixir/
/// ├── core/           # Core handler and configuration
/// ├── managers/       # Mix, Hex, releases, and version management
/// ├── tooling/        # Development tools (formatters, checkers, docs, builders)
/// └── analysis/       # Dependency and code analysis
/// ```
///
/// Features:
/// - **Project Types**: Scripts, Mix projects, Phoenix, Umbrella, Escript, Nerves
/// - **Build Systems**: Mix compilation, releases (Mix, Distillery, Burrito, Bakeware)
/// - **Package Management**: Hex packages, private registries
/// - **Quality Tools**: Dialyzer (type analysis), Credo (static analysis), mix format
/// - **Documentation**: ExDoc integration
/// - **Testing**: ExUnit with coverage (ExCoveralls)
/// - **Phoenix Support**: Asset compilation (esbuild, webpack, vite), migrations, LiveView
/// - **Embedded**: Nerves firmware builds
/// - **Version Management**: asdf, kiex integration
///
/// Usage:
/// ```d
/// import languages.scripting.elixir;
/// 
/// auto handler = new ElixirHandler();
/// auto result = handler.build(target, config);
/// ```

public import languages.scripting.elixir.core;
public import languages.scripting.elixir.managers;
public import languages.scripting.elixir.tooling;
public import languages.scripting.elixir.analysis;

