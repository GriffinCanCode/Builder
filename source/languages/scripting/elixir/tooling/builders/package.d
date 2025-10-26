module languages.scripting.elixir.tooling.builders;

/// Elixir project builders
///
/// This module provides specialized builders for different Elixir project types:
/// - ScriptBuilder: Simple .ex/.exs scripts
/// - MixProjectBuilder: Standard OTP applications
/// - PhoenixBuilder: Phoenix web applications
/// - UmbrellaBuilder: Multi-app umbrella projects
/// - EscriptBuilder: Standalone executables
/// - NervesBuilder: Embedded systems firmware

public import languages.scripting.elixir.tooling.builders.base;
public import languages.scripting.elixir.tooling.builders.script;
public import languages.scripting.elixir.tooling.builders.mix;
public import languages.scripting.elixir.tooling.builders.phoenix;
public import languages.scripting.elixir.tooling.builders.umbrella;
public import languages.scripting.elixir.tooling.builders.escript;
public import languages.scripting.elixir.tooling.builders.nerves;

