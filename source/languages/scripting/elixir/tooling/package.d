module languages.scripting.elixir.tooling;

/// Elixir development tooling
///
/// This module provides:
/// - builders: Project type builders (script, mix, phoenix, umbrella, escript, nerves)
/// - formatters: Code formatting (mix format)
/// - checkers: Static analysis (Dialyzer, Credo)
/// - docs: Documentation generation (ExDoc)
/// - detection: Project type detection
/// - tools: Tool availability and version checking

public import languages.scripting.elixir.tooling.builders;
public import languages.scripting.elixir.tooling.formatters;
public import languages.scripting.elixir.tooling.checkers;
public import languages.scripting.elixir.tooling.docs;
public import languages.scripting.elixir.tooling.detection;
public import languages.scripting.elixir.tooling.tools;

