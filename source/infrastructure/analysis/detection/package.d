module infrastructure.analysis.detection;

/// Project detection and template generation for `builder init`
/// 
/// This package provides intelligent project detection capabilities
/// that scan directories to identify languages, frameworks, and project
/// structure. It generates appropriate Builderfile and Builderspace
/// configurations based on detected patterns.
/// 
/// Architecture:
///   detector.d   - Core detection engine
///   templates.d  - Template generation for config files
///   inference.d  - Zero-config target inference

public import infrastructure.analysis.detection.detector;
public import infrastructure.analysis.detection.templates;
public import infrastructure.analysis.detection.inference;

