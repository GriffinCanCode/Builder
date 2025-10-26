module languages.scripting.elixir.managers;

/// Elixir package and version managers
///
/// This module provides:
/// - MixProjectParser: Parse mix.exs files
/// - MixRunner: Execute Mix tasks
/// - HexManager: Hex package management
/// - ReleaseManager: Build releases (Mix, Distillery, Burrito, Bakeware)
/// - VersionManager: Version management (asdf, kiex)

public import languages.scripting.elixir.managers.mix;
public import languages.scripting.elixir.managers.hex;
public import languages.scripting.elixir.managers.releases;
public import languages.scripting.elixir.managers.versions;

