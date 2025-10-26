module tests.unit.config.dsl;

import std.stdio;
import std.path;
import std.file;
import std.algorithm;
import config.lexer;
import config.ast;
import config.dsl;
import config.schema;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Lexer basic tokenization");
    
    string source = `target("app") { type: executable; }`;
    
    auto result = lex(source);
    Assert.isTrue(result.isOk);
    
    auto tokens = result.unwrap();
    Assert.isTrue(tokens.length > 0);
    
    // Verify token sequence
    Assert.equal(tokens[0].type, TokenType.Target);
    Assert.equal(tokens[1].type, TokenType.LeftParen);
    Assert.equal(tokens[2].type, TokenType.String);
    Assert.equal(tokens[2].value, "app");
    Assert.equal(tokens[3].type, TokenType.RightParen);
    Assert.equal(tokens[4].type, TokenType.LeftBrace);
    Assert.equal(tokens[5].type, TokenType.Type);
    Assert.equal(tokens[6].type, TokenType.Colon);
    Assert.equal(tokens[7].type, TokenType.Executable);
    Assert.equal(tokens[8].type, TokenType.Semicolon);
    Assert.equal(tokens[9].type, TokenType.RightBrace);
    
    writeln("\x1b[32m  ✓ Lexer tokenizes basic DSL correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Lexer string literals");
    
    string source = `"hello" 'world' "escaped\"quote"`;
    
    auto result = lex(source);
    Assert.isTrue(result.isOk);
    
    auto tokens = result.unwrap();
    Assert.equal(tokens[0].type, TokenType.String);
    Assert.equal(tokens[0].value, "hello");
    Assert.equal(tokens[1].type, TokenType.String);
    Assert.equal(tokens[1].value, "world");
    Assert.equal(tokens[2].type, TokenType.String);
    Assert.equal(tokens[2].value, `escaped"quote`);
    
    writeln("\x1b[32m  ✓ Lexer handles string literals and escapes\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Lexer comments");
    
    string source = `
        // Line comment
        target("app") {
            /* Block comment */
            type: executable; # Shell-style comment
        }
    `;
    
    auto result = lex(source);
    Assert.isTrue(result.isOk);
    
    auto tokens = result.unwrap();
    // Comments should be filtered out
    Assert.isTrue(tokens[0].type == TokenType.Target);
    
    writeln("\x1b[32m  ✓ Lexer handles comments correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Parser basic target");
    
    string source = `
        target("app") {
            type: executable;
            language: python;
            sources: ["main.py"];
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = DSLParser(lexResult.unwrap(), "BUILD");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    auto ast = parseResult.unwrap();
    Assert.equal(ast.targets.length, 1);
    
    auto target = ast.targets[0];
    Assert.equal(target.name, "app");
    Assert.isTrue(target.hasField("type"));
    Assert.isTrue(target.hasField("language"));
    Assert.isTrue(target.hasField("sources"));
    
    writeln("\x1b[32m  ✓ Parser parses basic target correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Parser multiple targets");
    
    string source = `
        target("lib") {
            type: library;
            sources: ["lib.py"];
        }
        
        target("app") {
            type: executable;
            sources: ["main.py"];
            deps: [":lib"];
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = DSLParser(lexResult.unwrap(), "BUILD");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    auto ast = parseResult.unwrap();
    Assert.equal(ast.targets.length, 2);
    Assert.equal(ast.targets[0].name, "lib");
    Assert.equal(ast.targets[1].name, "app");
    
    writeln("\x1b[32m  ✓ Parser handles multiple targets\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Parser arrays");
    
    string source = `
        target("app") {
            type: executable;
            sources: ["a.py", "b.py", "c.py"];
            flags: ["-O2", "-Wall"];
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = DSLParser(lexResult.unwrap(), "BUILD");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    auto ast = parseResult.unwrap();
    auto sourcesField = ast.targets[0].getField("sources");
    Assert.isTrue(sourcesField !is null);
    Assert.equal(sourcesField.value.kind, ExpressionValue.Kind.Array);
    Assert.equal(sourcesField.value.arrayValue.elements.length, 3);
    
    writeln("\x1b[32m  ✓ Parser handles array literals\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Parser maps");
    
    string source = `
        target("app") {
            type: executable;
            sources: ["main.py"];
            env: {"PATH": "/usr/bin", "HOME": "/home/user"};
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = DSLParser(lexResult.unwrap(), "BUILD");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    auto ast = parseResult.unwrap();
    auto envField = ast.targets[0].getField("env");
    Assert.isTrue(envField !is null);
    Assert.equal(envField.value.kind, ExpressionValue.Kind.Map);
    Assert.equal(envField.value.mapValue.pairs.length, 2);
    
    writeln("\x1b[32m  ✓ Parser handles map literals\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Semantic analyzer");
    
    string source = `
        target("app") {
            type: executable;
            language: python;
            sources: ["main.py"];
            deps: [":lib"];
            flags: ["-O2"];
        }
    `;
    
    auto result = parseDSL(source, "BUILD", "/tmp");
    Assert.isTrue(result.isOk);
    
    auto targets = result.unwrap();
    Assert.equal(targets.length, 1);
    
    auto target = targets[0];
    Assert.equal(target.name, "app");
    Assert.equal(target.type, TargetType.Executable);
    Assert.equal(target.language, TargetLanguage.Python);
    Assert.equal(target.sources.length, 1);
    Assert.equal(target.sources[0], "main.py");
    Assert.equal(target.deps.length, 1);
    Assert.equal(target.deps[0], ":lib");
    Assert.equal(target.flags.length, 1);
    
    writeln("\x1b[32m  ✓ Semantic analyzer converts AST to Target\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Language inference");
    
    string source = `
        target("app") {
            type: executable;
            sources: ["main.py"];
        }
    `;
    
    auto result = parseDSL(source, "BUILD", "/tmp");
    Assert.isTrue(result.isOk);
    
    auto targets = result.unwrap();
    // Language should be inferred from .py extension
    Assert.equal(targets[0].language, TargetLanguage.Python);
    
    writeln("\x1b[32m  ✓ Language inference works in DSL\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Error handling - missing field");
    
    string source = `
        target("app") {
            type: executable;
        }
    `;
    
    auto result = parseDSL(source, "BUILD", "/tmp");
    Assert.isTrue(result.isErr);
    // Should fail because 'sources' is required
    
    writeln("\x1b[32m  ✓ Error handling for missing required fields\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Error handling - invalid syntax");
    
    string source = `
        target("app") {
            type: executable
            sources: ["main.py"];
        }
    `;
    
    auto result = parseDSL(source, "BUILD", "/tmp");
    Assert.isTrue(result.isErr);
    // Should fail because missing semicolon after 'executable'
    
    writeln("\x1b[32m  ✓ Error handling for syntax errors\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - All target types");
    
    string source = `
        target("exec") {
            type: executable;
            sources: ["main.py"];
        }
        
        target("lib") {
            type: library;
            sources: ["lib.py"];
        }
        
        target("tests") {
            type: test;
            sources: ["test.py"];
        }
        
        target("custom") {
            type: custom;
            sources: ["build.sh"];
        }
    `;
    
    auto result = parseDSL(source, "BUILD", "/tmp");
    Assert.isTrue(result.isOk);
    
    auto targets = result.unwrap();
    Assert.equal(targets.length, 4);
    Assert.equal(targets[0].type, TargetType.Executable);
    Assert.equal(targets[1].type, TargetType.Library);
    Assert.equal(targets[2].type, TargetType.Test);
    Assert.equal(targets[3].type, TargetType.Custom);
    
    writeln("\x1b[32m  ✓ All target types parsed correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - All language types");
    
    string[] languages = [
        "d", "python", "javascript", "typescript", 
        "go", "rust", "c", "cpp", "java"
    ];
    
    foreach (lang; languages)
    {
        string source = `
            target("app") {
                type: executable;
                language: ` ~ lang ~ `;
                sources: ["main.` ~ lang ~ `"];
            }
        `;
        
        auto result = parseDSL(source, "BUILD", "/tmp");
        Assert.isTrue(result.isOk, "Failed to parse language: " ~ lang);
    }
    
    writeln("\x1b[32m  ✓ All language types parsed correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Complex target");
    
    string source = `
        target("complex-app") {
            type: executable;
            language: python;
            sources: [
                "main.py",
                "utils.py",
                "config.py"
            ];
            deps: [
                "//lib:core",
                "//lib:utils",
                ":helpers"
            ];
            flags: [
                "-O2",
                "-Wall",
                "-Werror"
            ];
            env: {
                "PYTHONPATH": "/usr/lib/python",
                "DEBUG": "1"
            };
            output: "bin/app";
        }
    `;
    
    auto result = parseDSL(source, "BUILD", "/tmp");
    Assert.isTrue(result.isOk);
    
    auto targets = result.unwrap();
    auto target = targets[0];
    
    Assert.equal(target.name, "complex-app");
    Assert.equal(target.sources.length, 3);
    Assert.equal(target.deps.length, 3);
    Assert.equal(target.flags.length, 3);
    Assert.equal(target.env.length, 2);
    Assert.equal(target.outputPath, "bin/app");
    
    writeln("\x1b[32m  ✓ Complex target with all fields parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - AST printer");
    
    string source = `
        target("app") {
            type: executable;
            sources: ["main.py"];
        }
    `;
    
    auto lexResult = lex(source);
    auto parser = DSLParser(lexResult.unwrap(), "BUILD");
    auto parseResult = parser.parse();
    auto ast = parseResult.unwrap();
    
    ASTPrinter printer;
    string output = printer.print(ast);
    
    Assert.isTrue(output.length > 0);
    Assert.isTrue(output.canFind("BuildFile"));
    Assert.isTrue(output.canFind("TargetDecl"));
    
    writeln("\x1b[32m  ✓ AST printer generates output\x1b[0m");
}

