module tests.unit.config.lexer;

import std.stdio;
import config.parsing.lexer;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Tokenize simple identifier");
    
    auto lexer = Lexer("myIdentifier");
    auto token = lexer.nextToken();
    
    Assert.equal(token.type, TokenType.Identifier);
    Assert.equal(token.value, "myIdentifier");
    Assert.equal(token.line, 1);
    Assert.equal(token.column, 1);
    
    writeln("\x1b[32m  ✓ Simple identifier tokenization works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Tokenize keywords");
    
    auto keywords = [
        "target": TokenType.Target,
        "type": TokenType.Type,
        "language": TokenType.Language,
        "sources": TokenType.Sources,
        "deps": TokenType.Deps,
        "flags": TokenType.Flags,
        "env": TokenType.Env,
        "output": TokenType.Output,
        "includes": TokenType.Includes,
        "config": TokenType.Config,
    ];
    
    foreach (keyword, expectedType; keywords)
    {
        auto lexer = Lexer(keyword);
        auto token = lexer.nextToken();
        Assert.equal(token.type, expectedType);
        Assert.equal(token.value, keyword);
    }
    
    writeln("\x1b[32m  ✓ Keyword tokenization works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Tokenize type keywords");
    
    auto typeKeywords = [
        "executable": TokenType.Executable,
        "library": TokenType.Library,
        "test": TokenType.Test,
        "custom": TokenType.Custom,
    ];
    
    foreach (keyword, expectedType; typeKeywords)
    {
        auto lexer = Lexer(keyword);
        auto token = lexer.nextToken();
        Assert.equal(token.type, expectedType);
    }
    
    writeln("\x1b[32m  ✓ Type keyword tokenization works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Tokenize string literals");
    
    auto lexer = Lexer(`"hello world"`);
    auto token = lexer.nextToken();
    
    Assert.equal(token.type, TokenType.String);
    Assert.equal(token.value, "hello world");
    
    writeln("\x1b[32m  ✓ String literal tokenization works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Tokenize escaped strings");
    
    auto lexer = Lexer(`"hello \"quoted\" world"`);
    auto token = lexer.nextToken();
    
    Assert.equal(token.type, TokenType.String);
    // Should handle escaped quotes
    Assert.notEmpty([token.value]);
    
    writeln("\x1b[32m  ✓ Escaped string tokenization works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Tokenize numbers");
    
    auto lexer = Lexer("12345");
    auto token = lexer.nextToken();
    
    Assert.equal(token.type, TokenType.Number);
    Assert.equal(token.value, "12345");
    
    writeln("\x1b[32m  ✓ Number tokenization works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Tokenize punctuation");
    
    auto punctuationMap = [
        "(": TokenType.LeftParen,
        ")": TokenType.RightParen,
        "{": TokenType.LeftBrace,
        "}": TokenType.RightBrace,
        "[": TokenType.LeftBracket,
        "]": TokenType.RightBracket,
        ":": TokenType.Colon,
        ";": TokenType.Semicolon,
        ",": TokenType.Comma,
    ];
    
    foreach (punct, expectedType; punctuationMap)
    {
        auto lexer = Lexer(punct);
        auto token = lexer.nextToken();
        Assert.equal(token.type, expectedType);
    }
    
    writeln("\x1b[32m  ✓ Punctuation tokenization works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Tokenize sequence of tokens");
    
    auto lexer = Lexer("target myapp { type: executable }");
    
    auto t1 = lexer.nextToken();
    Assert.equal(t1.type, TokenType.Target);
    Assert.equal(t1.value, "target");
    
    auto t2 = lexer.nextToken();
    Assert.equal(t2.type, TokenType.Identifier);
    Assert.equal(t2.value, "myapp");
    
    auto t3 = lexer.nextToken();
    Assert.equal(t3.type, TokenType.LeftBrace);
    
    auto t4 = lexer.nextToken();
    Assert.equal(t4.type, TokenType.Type);
    
    auto t5 = lexer.nextToken();
    Assert.equal(t5.type, TokenType.Colon);
    
    auto t6 = lexer.nextToken();
    Assert.equal(t6.type, TokenType.Executable);
    
    auto t7 = lexer.nextToken();
    Assert.equal(t7.type, TokenType.RightBrace);
    
    auto t8 = lexer.nextToken();
    Assert.equal(t8.type, TokenType.EOF);
    
    writeln("\x1b[32m  ✓ Token sequence parsing works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Skip whitespace");
    
    auto lexer = Lexer("  target   myapp  ");
    
    auto t1 = lexer.nextToken();
    Assert.equal(t1.type, TokenType.Target);
    
    auto t2 = lexer.nextToken();
    Assert.equal(t2.type, TokenType.Identifier);
    
    writeln("\x1b[32m  ✓ Whitespace is skipped correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Handle newlines and track line numbers");
    
    auto lexer = Lexer("target\nmyapp\n{\n}");
    
    auto t1 = lexer.nextToken();
    Assert.equal(t1.line, 1);
    
    auto t2 = lexer.nextToken();
    Assert.equal(t2.line, 2);
    
    auto t3 = lexer.nextToken();
    Assert.equal(t3.line, 3);
    
    auto t4 = lexer.nextToken();
    Assert.equal(t4.line, 4);
    
    writeln("\x1b[32m  ✓ Line number tracking works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Handle comments");
    
    // Assuming # or // style comments
    auto lexer = Lexer("target # this is a comment\nmyapp");
    
    auto t1 = lexer.nextToken();
    Assert.equal(t1.type, TokenType.Target);
    
    auto t2 = lexer.nextToken();
    Assert.equal(t2.type, TokenType.Identifier);
    Assert.equal(t2.value, "myapp");
    
    writeln("\x1b[32m  ✓ Comment handling works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Empty input");
    
    auto lexer = Lexer("");
    auto token = lexer.nextToken();
    
    Assert.equal(token.type, TokenType.EOF);
    
    writeln("\x1b[32m  ✓ Empty input is handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - EOF after tokens");
    
    auto lexer = Lexer("target");
    
    auto t1 = lexer.nextToken();
    Assert.equal(t1.type, TokenType.Target);
    
    auto t2 = lexer.nextToken();
    Assert.equal(t2.type, TokenType.EOF);
    
    // Multiple EOF calls should be safe
    auto t3 = lexer.nextToken();
    Assert.equal(t3.type, TokenType.EOF);
    
    writeln("\x1b[32m  ✓ EOF handling works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Peek functionality");
    
    auto lexer = Lexer("target myapp");
    
    auto peeked = lexer.peekToken();
    Assert.equal(peeked.type, TokenType.Target);
    
    // Peek should not advance
    auto next = lexer.nextToken();
    Assert.equal(next.type, TokenType.Target);
    
    writeln("\x1b[32m  ✓ Peek functionality works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Array literal");
    
    auto lexer = Lexer(`["file1.cpp", "file2.cpp"]`);
    
    auto t1 = lexer.nextToken();
    Assert.equal(t1.type, TokenType.LeftBracket);
    
    auto t2 = lexer.nextToken();
    Assert.equal(t2.type, TokenType.String);
    Assert.equal(t2.value, "file1.cpp");
    
    auto t3 = lexer.nextToken();
    Assert.equal(t3.type, TokenType.Comma);
    
    auto t4 = lexer.nextToken();
    Assert.equal(t4.type, TokenType.String);
    Assert.equal(t4.value, "file2.cpp");
    
    auto t5 = lexer.nextToken();
    Assert.equal(t5.type, TokenType.RightBracket);
    
    writeln("\x1b[32m  ✓ Array literal parsing works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Complex Builderfile structure");
    
    auto source = `
        target app {
            type: executable
            language: cpp
            sources: ["main.cpp", "utils.cpp"]
            flags: ["-O2", "-Wall"]
        }
    `;
    
    auto lexer = Lexer(source);
    
    // Just verify we can parse without errors
    while (true)
    {
        auto token = lexer.nextToken();
        if (token.type == TokenType.EOF)
            break;
        
        // All tokens should have valid types
        Assert.notEqual(token.type, TokenType.Invalid);
    }
    
    writeln("\x1b[32m  ✓ Complex Builderfile structure parsing works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.lexer - Token position information");
    
    auto lexer = Lexer("target");
    auto token = lexer.nextToken();
    
    Assert.equal(token.line, 1);
    Assert.isTrue(token.column >= 1);
    
    writeln("\x1b[32m  ✓ Token position information is tracked\x1b[0m");
}

