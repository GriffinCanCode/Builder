module config;

/// Configuration Package
/// Build configuration parsing and workspace management
/// 
/// Architecture:
///   lexer.d     - Lexical analysis for DSL
///   parser.d    - Builderfile parsing
///   ast.d       - Abstract syntax tree
///   dsl.d       - DSL interpretation
///   schema.d    - Configuration schema definitions
///   workspace.d - Workspace and project management
///
/// Usage:
///   import config;
///   
///   auto workspace = new Workspace("path/to/project");
///   auto buildConfig = parseConfig("Builderfile");
///   auto targets = buildConfig.getTargets();

public import config.parsing.lexer;
public import config.parsing.parser;
public import config.workspace.ast;
public import config.interpretation.dsl;
public import config.schema.schema;
public import config.workspace.workspace;

