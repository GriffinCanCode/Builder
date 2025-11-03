module infrastructure.config;

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

public import infrastructure.config.parsing.lexer;
public import infrastructure.config.parsing.unified;
public import infrastructure.config.workspace.ast;
public import infrastructure.config.workspace.workspace;
public import infrastructure.config.analysis.semantic;
public import infrastructure.config.schema.schema;
public import infrastructure.config.caching.parse;
