module config;

/// Configuration Package
/// Build configuration parsing and workspace management
/// 
/// Architecture:
///   parsing/    - Lexical analysis and unified DSL parsing
///   workspace/  - AST definitions and workspace management
///   schema/     - Target and configuration schemas
///   analysis/   - Semantic analysis (AST → Targets)
///   caching/    - Parse cache for performance
///   scripting/  - Tier 1 programmability (let, fn, for, if)
///   macros/     - Tier 2 programmability (D-based macros)
///
/// Usage:
///   import config;
///   
///   auto result = parseDSL(source, filePath, workspaceRoot);
///   if (result.isOk) {
///       auto targets = result.unwrap().targets;
///   }

public import config.parsing.lexer;
public import config.parsing.unified;
public import config.workspace.ast;
public import config.workspace.workspace;
public import config.analysis.semantic;
public import config.schema.schema;
public import config.caching.parse;
