module frontend.query.parsing;

/// Query Language Parsing Module
/// 
/// Provides lexical analysis, parsing, and AST construction
/// for the bldrquery DSL (Builder Query Language).
/// 
/// Components:
/// - Lexer: Tokenization with position tracking
/// - Parser: Recursive descent parser producing AST
/// - AST: Immutable expression tree nodes with visitor pattern
/// 
/// Example:
/// ```d
/// auto lexer = QueryLexer("deps(//src:app)");
/// auto tokens = lexer.tokenize();
/// auto parser = QueryParser(tokens.unwrap());
/// auto ast = parser.parse();
/// ```

public import frontend.query.parsing.ast;
public import frontend.query.parsing.lexer;
public import frontend.query.parsing.parser;

