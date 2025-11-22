module infrastructure.analysis.manifests;

/// Package Manifest Parsing
/// 
/// Extracts structured information from language-specific package manifests
/// Used by both init/wizard commands and migration system to avoid duplication

public import infrastructure.analysis.manifests.types;
public import infrastructure.analysis.manifests.npm;
public import infrastructure.analysis.manifests.cargo;
public import infrastructure.analysis.manifests.python;
public import infrastructure.analysis.manifests.go;
public import infrastructure.analysis.manifests.maven;
public import infrastructure.analysis.manifests.composer;

