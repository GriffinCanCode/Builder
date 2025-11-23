module infrastructure.parsing.treesitter;

/// Tree-sitter integration for universal AST parsing
/// 
/// Provides grammar-based AST parsing for 20+ languages using tree-sitter.
/// Enables symbol-level incremental compilation across all supported languages.
/// 
/// Usage:
///     import infrastructure.parsing.treesitter;
///     
///     // Register tree-sitter parsers (call during initialization)
///     registerTreeSitterParsers();
///     
///     // Parsers are automatically used by AST engine

public import infrastructure.parsing.treesitter.bindings;
public import infrastructure.parsing.treesitter.config;
public import infrastructure.parsing.treesitter.parser;
public import infrastructure.parsing.treesitter.registry;
public import infrastructure.parsing.treesitter.loader;
public import infrastructure.parsing.treesitter.deps;

