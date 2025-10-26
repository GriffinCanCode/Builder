module config.lexer;

import std.conv;
import std.string;
import std.array;
import std.uni;
import std.ascii : isDigit, isAlpha, isAlphaNum, isWhite;
import std.algorithm;
import errors;

/// Token types with compile-time enumeration
enum TokenType
{
    // Literals
    Identifier,
    String,
    Number,
    
    // Keywords
    Target,
    Type,
    Language,
    Sources,
    Deps,
    Flags,
    Env,
    Output,
    Includes,
    
    // Types
    Executable,
    Library,
    Test,
    Custom,
    
    // Punctuation
    LeftParen,      // (
    RightParen,     // )
    LeftBrace,      // {
    RightBrace,     // }
    LeftBracket,    // [
    RightBracket,   // ]
    Colon,          // :
    Semicolon,      // ;
    Comma,          // ,
    
    // Special
    EOF,
    Invalid
}

/// Token with position tracking
struct Token
{
    TokenType type;
    string value;
    size_t line;
    size_t column;
    
    /// Check if token matches type
    bool isType(TokenType t) const pure nothrow @nogc
    {
        return type == t;
    }
    
    /// Get human-readable token name
    string typeName() const
    {
        return type.to!string;
    }
}

/// Lexical analyzer with zero-allocation scanning
struct Lexer
{
    private string source;
    private size_t position;
    private size_t line = 1;
    private size_t column = 1;
    private string filePath;
    
    /// Keywords map for O(1) lookup
    private static immutable string[string] keywords;
    
    shared static this()
    {
        keywords = [
            "target": "Target",
            "type": "Type",
            "language": "Language",
            "sources": "Sources",
            "deps": "Deps",
            "flags": "Flags",
            "env": "Env",
            "output": "Output",
            "includes": "Includes",
            // Type keywords
            "executable": "Executable",
            "library": "Library",
            "test": "Test",
            "custom": "Custom"
        ];
    }
    
    this(string source, string filePath = "")
    {
        this.source = source;
        this.filePath = filePath;
    }
    
    /// Lex entire source into tokens
    Result!(Token[], BuildError) tokenize()
    {
        Token[] tokens;
        tokens.reserve(source.length / 10); // Heuristic
        
        while (!isAtEnd())
        {
            skipWhitespaceAndComments();
            if (isAtEnd())
                break;
            
            auto tokenResult = nextToken();
            if (tokenResult.isErr)
                return Err!(Token[], BuildError)(tokenResult.unwrapErr());
            
            auto token = tokenResult.unwrap();
            if (token.type != TokenType.Invalid)
                tokens ~= token;
        }
        
        tokens ~= Token(TokenType.EOF, "", line, column);
        return Ok!(Token[], BuildError)(tokens);
    }
    
    /// Get next token
    private Result!(Token, BuildError) nextToken()
    {
        if (isAtEnd())
            return Ok!(Token, BuildError)(Token(TokenType.EOF, "", line, column));
        
        char c = peek();
        size_t startLine = line;
        size_t startCol = column;
        
        // Single-character tokens
        switch (c)
        {
            case '(': advance(); return ok(TokenType.LeftParen, "(", startLine, startCol);
            case ')': advance(); return ok(TokenType.RightParen, ")", startLine, startCol);
            case '{': advance(); return ok(TokenType.LeftBrace, "{", startLine, startCol);
            case '}': advance(); return ok(TokenType.RightBrace, "}", startLine, startCol);
            case '[': advance(); return ok(TokenType.LeftBracket, "[", startLine, startCol);
            case ']': advance(); return ok(TokenType.RightBracket, "]", startLine, startCol);
            case ':': advance(); return ok(TokenType.Colon, ":", startLine, startCol);
            case ';': advance(); return ok(TokenType.Semicolon, ";", startLine, startCol);
            case ',': advance(); return ok(TokenType.Comma, ",", startLine, startCol);
            case '"': case '\'': return scanString(c);
            default:
                if (isDigit(c) || (c == '-' && peekNext().isDigit))
                    return scanNumber();
                if (isAlpha(c) || c == '_')
                    return scanIdentifier();
                
                // Unknown character
                auto error = new ParseError(filePath, 
                    "Unexpected character: '" ~ c ~ "'",
                    ErrorCode.ParseFailed);
                error.line = line;
                error.column = column;
                return Err!(Token, BuildError)(error);
        }
    }
    
    /// Scan string literal
    private Result!(Token, BuildError) scanString(char quote)
    {
        size_t startLine = line;
        size_t startCol = column;
        advance(); // Opening quote
        
        string value = "";
        
        while (!isAtEnd() && peek() != quote)
        {
            if (peek() == '\\')
            {
                advance();
                if (!isAtEnd())
                {
                    char escaped = peek();
                    switch (escaped)
                    {
                        case 'n': value ~= '\n'; break;
                        case 't': value ~= '\t'; break;
                        case 'r': value ~= '\r'; break;
                        case '\\': value ~= '\\'; break;
                        case '"': value ~= '"'; break;
                        case '\'': value ~= '\''; break;
                        default: value ~= escaped; break;
                    }
                    advance();
                }
            }
            else
            {
                value ~= peek();
                advance();
            }
        }
        
        if (isAtEnd())
        {
            auto error = new ParseError(filePath, 
                "Unterminated string literal",
                ErrorCode.ParseFailed);
            error.line = startLine;
            error.column = startCol;
            return Err!(Token, BuildError)(error);
        }
        
        advance(); // Closing quote
        return ok(TokenType.String, value, startLine, startCol);
    }
    
    /// Scan number literal
    private Result!(Token, BuildError) scanNumber()
    {
        size_t startLine = line;
        size_t startCol = column;
        string value = "";
        
        if (peek() == '-')
        {
            value ~= peek();
            advance();
        }
        
        while (!isAtEnd() && isDigit(peek()))
        {
            value ~= peek();
            advance();
        }
        
        return ok(TokenType.Number, value, startLine, startCol);
    }
    
    /// Scan identifier or keyword
    private Result!(Token, BuildError) scanIdentifier()
    {
        size_t startLine = line;
        size_t startCol = column;
        string value = "";
        
        while (!isAtEnd() && (isAlphaNum(peek()) || peek() == '_' || peek() == '-'))
        {
            value ~= peek();
            advance();
        }
        
        // Check if it's a keyword
        if (auto keywordType = value in keywords)
        {
            // Map keyword to TokenType
            switch (*keywordType)
            {
                case "Target": return ok(TokenType.Target, value, startLine, startCol);
                case "Type": return ok(TokenType.Type, value, startLine, startCol);
                case "Language": return ok(TokenType.Language, value, startLine, startCol);
                case "Sources": return ok(TokenType.Sources, value, startLine, startCol);
                case "Deps": return ok(TokenType.Deps, value, startLine, startCol);
                case "Flags": return ok(TokenType.Flags, value, startLine, startCol);
                case "Env": return ok(TokenType.Env, value, startLine, startCol);
                case "Output": return ok(TokenType.Output, value, startLine, startCol);
                case "Includes": return ok(TokenType.Includes, value, startLine, startCol);
                case "Executable": return ok(TokenType.Executable, value, startLine, startCol);
                case "Library": return ok(TokenType.Library, value, startLine, startCol);
                case "Test": return ok(TokenType.Test, value, startLine, startCol);
                case "Custom": return ok(TokenType.Custom, value, startLine, startCol);
                default: break;
            }
        }
        
        return ok(TokenType.Identifier, value, startLine, startCol);
    }
    
    /// Skip whitespace and comments
    private void skipWhitespaceAndComments()
    {
        while (!isAtEnd())
        {
            char c = peek();
            
            if (isWhite(c))
            {
                if (c == '\n')
                {
                    line++;
                    column = 1;
                }
                else
                {
                    column++;
                }
                position++;
            }
            else if (c == '/' && peekNext() == '/')
            {
                // Line comment
                while (!isAtEnd() && peek() != '\n')
                    advance();
            }
            else if (c == '/' && peekNext() == '*')
            {
                // Block comment
                advance(); // /
                advance(); // *
                
                while (!isAtEnd())
                {
                    if (peek() == '*' && peekNext() == '/')
                    {
                        advance(); // *
                        advance(); // /
                        break;
                    }
                    advance();
                }
            }
            else if (c == '#')
            {
                // Shell-style comment
                while (!isAtEnd() && peek() != '\n')
                    advance();
            }
            else
            {
                break;
            }
        }
    }
    
    /// Helper methods
    
    private char peek() const
    {
        return isAtEnd() ? '\0' : source[position];
    }
    
    private char peekNext() const
    {
        return (position + 1 >= source.length) ? '\0' : source[position + 1];
    }
    
    private void advance()
    {
        if (!isAtEnd())
        {
            if (source[position] == '\n')
            {
                line++;
                column = 1;
            }
            else
            {
                column++;
            }
            position++;
        }
    }
    
    private bool isAtEnd() const pure nothrow @nogc
    {
        return position >= source.length;
    }
    
    private Result!(Token, BuildError) ok(TokenType type, string value, size_t line, size_t col)
    {
        return Ok!(Token, BuildError)(Token(type, value, line, col));
    }
}

/// Convenience function for quick tokenization
Result!(Token[], BuildError) lex(string source, string filePath = "")
{
    auto lexer = Lexer(source, filePath);
    return lexer.tokenize();
}

unittest
{
    import std.stdio;
    
    // Test basic tokenization
    auto result = lex(`target("app") { type: executable; }`);
    assert(result.isOk);
    
    auto tokens = result.unwrap();
    assert(tokens[0].type == TokenType.Target);
    assert(tokens[1].type == TokenType.LeftParen);
    assert(tokens[2].type == TokenType.String);
    assert(tokens[2].value == "app");
}

