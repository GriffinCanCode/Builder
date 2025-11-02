module config.parsing;

/// Parsing system for Builder DSL
///
/// This package provides unified parsing for:
/// - Lexical analysis (tokenization)
/// - Expression parsing (Pratt parser)
/// - Statement parsing (programmability features)

public import config.parsing.lexer;
public import config.parsing.exprparser;
public import config.parsing.stmtparser;

