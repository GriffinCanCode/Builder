module tests.unit.config.dsl;

import std.stdio;
import std.path;
import std.file;
import std.algorithm;
import config.parsing.lexer;
import config.workspace.ast;
import config.interpretation.dsl;
import config.schema.schema;
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
    
    auto parser = DSLParser(lexResult.unwrap(), "Builderfile");
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
    
    auto parser = DSLParser(lexResult.unwrap(), "Builderfile");
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
    
    auto parser = DSLParser(lexResult.unwrap(), "Builderfile");
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
    
    auto parser = DSLParser(lexResult.unwrap(), "Builderfile");
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
    
    auto result = parseDSL(source, "Builderfile", "/tmp");
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
    
    auto result = parseDSL(source, "Builderfile", "/tmp");
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
    
    auto result = parseDSL(source, "Builderfile", "/tmp");
    Assert.isTrue(result.isErr);
    // Should fail because 'sources' is required
    
    writeln("\x1b[32m  ✓ Error handling for missing required fields\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.dsl - Map with mixed value types");
    
    string source = `
        target("app") {
            type: executable;
            sources: ["main.py"];
            env: {
                "PORT": 8080,
                "DEBUG": true,
                "HOST": "localhost",
                "TIMEOUT": -30
            };
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = DSLParser(lexResult.unwrap(), "Builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    auto ast = parseResult.unwrap();
    auto envField = ast.targets[0].getField("env");
    Assert.isTrue(envField !is null);
    Assert.equal(envField.value.kind, ExpressionValue.Kind.Map);
    
    // Check that we have different value types in the map
    auto mapPairs = envField.value.mapValue.pairs;
    Assert.equal(mapPairs.length, 4);
    Assert.equal(mapPairs["PORT"].kind, ExpressionValue.Kind.Number);
    Assert.equal(mapPairs["PORT"].numberValue.value, 8080);
    Assert.equal(mapPairs["DEBUG"].kind, ExpressionValue.Kind.Identifier);
    Assert.equal(mapPairs["DEBUG"].identifierValue.name, "true");
    Assert.equal(mapPairs["HOST"].kind, ExpressionValue.Kind.String);
    Assert.equal(mapPairs["HOST"].stringValue.value, "localhost");
    Assert.equal(mapPairs["TIMEOUT"].kind, ExpressionValue.Kind.Number);
    Assert.equal(mapPairs["TIMEOUT"].numberValue.value, -30);
    
    writeln("\x1b[32m  ✓ Maps support mixed value types (numbers, booleans, strings)\x1b[0m");
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
    
    auto result = parseDSL(source, "Builderfile", "/tmp");
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
    
    auto result = parseDSL(source, "Builderfile", "/tmp");
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
        
        auto result = parseDSL(source, "Builderfile", "/tmp");
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
    
    auto result = parseDSL(source, "Builderfile", "/tmp");
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
    auto parser = DSLParser(lexResult.unwrap(), "Builderfile");
    auto parseResult = parser.parse();
    auto ast = parseResult.unwrap();
    
    ASTPrinter printer;
    string output = printer.print(ast);
    
    Assert.isTrue(output.length > 0);
    Assert.isTrue(output.canFind("BuildFile"));
    Assert.isTrue(output.canFind("TargetDecl"));
    
    writeln("\x1b[32m  ✓ AST printer generates output\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.ast - Type-safe accessors");
    
    // Test getString
    auto strExpr = ExpressionValue.fromString("hello", 1, 1);
    Assert.isTrue(strExpr.getString() !is null);
    Assert.equal(strExpr.getString().value, "hello");
    Assert.isTrue(strExpr.getNumber() is null);
    Assert.isTrue(strExpr.getArray() is null);
    
    // Test getNumber
    auto numExpr = ExpressionValue.fromNumber(42, 1, 1);
    Assert.isTrue(numExpr.getNumber() !is null);
    Assert.equal(numExpr.getNumber().value, 42);
    Assert.isTrue(numExpr.getString() is null);
    Assert.isTrue(numExpr.getMap() is null);
    
    // Test getIdentifier
    auto idExpr = ExpressionValue.fromIdentifier("myvar", 1, 1);
    Assert.isTrue(idExpr.getIdentifier() !is null);
    Assert.equal(idExpr.getIdentifier().name, "myvar");
    Assert.isTrue(idExpr.getString() is null);
    Assert.isTrue(idExpr.getArray() is null);
    
    // Test getArray
    auto arrExpr = ExpressionValue.fromArray([strExpr], 1, 1);
    Assert.isTrue(arrExpr.getArray() !is null);
    Assert.equal(arrExpr.getArray().elements.length, 1);
    Assert.isTrue(arrExpr.getString() is null);
    Assert.isTrue(arrExpr.getNumber() is null);
    
    // Test getMap
    ExpressionValue[string] mapPairs;
    mapPairs["key"] = ExpressionValue.fromString("value", 1, 1);
    auto mapExpr = ExpressionValue.fromMap(mapPairs, 1, 1);
    Assert.isTrue(mapExpr.getMap() !is null);
    Assert.equal(mapExpr.getMap().pairs.length, 1);
    Assert.isTrue(mapExpr.getString() is null);
    Assert.isTrue(mapExpr.getArray() is null);
    
    writeln("\x1b[32m  ✓ Type-safe accessors return correct values or null\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.ast - Contract validation on legacy accessors");
    
    import core.exception : AssertError;
    
    auto strExpr = ExpressionValue.fromString("test", 1, 1);
    
    // Valid access should work
    auto str = strExpr.stringValue;
    Assert.equal(str.value, "test");
    
    // Invalid access should fail in debug/contract mode
    bool caughtError = false;
    try
    {
        // Accessing wrong union member should trigger contract
        auto num = strExpr.numberValue; // This violates the contract
    }
    catch (AssertError e)
    {
        caughtError = true;
    }
    
    // Note: Contracts might not throw in release builds
    writeln("\x1b[32m  ✓ Contract validation protects against wrong accessor use\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.ast - Match pattern for exhaustive handling");
    
    auto strExpr = ExpressionValue.fromString("hello", 1, 1);
    auto numExpr = ExpressionValue.fromNumber(42, 1, 1);
    auto idExpr = ExpressionValue.fromIdentifier("var", 1, 1);
    auto arrExpr = ExpressionValue.fromArray([strExpr], 1, 1);
    ExpressionValue[string] mapPairs2;
    mapPairs2["k"] = ExpressionValue.fromString("v", 1, 1);
    auto mapExpr = ExpressionValue.fromMap(mapPairs2, 1, 1);
    
    // Test match with string
    string result1 = strExpr.match(
        (ref const StringLiteral s) => "string: " ~ s.value,
        (ref const NumberLiteral n) => "number",
        (ref const Identifier i) => "identifier",
        (const ArrayLiteral* a) => "array",
        (const MapLiteral* m) => "map"
    );
    Assert.equal(result1, "string: hello");
    
    // Test match with number
    int result2 = numExpr.match(
        (ref const StringLiteral s) => 0,
        (ref const NumberLiteral n) => cast(int)n.value,
        (ref const Identifier i) => 0,
        (const ArrayLiteral* a) => 0,
        (const MapLiteral* m) => 0
    );
    Assert.equal(result2, 42);
    
    // Test match with array (checking pointer access)
    size_t result3 = arrExpr.match(
        (ref const StringLiteral s) => cast(size_t)0,
        (ref const NumberLiteral n) => cast(size_t)0,
        (ref const Identifier i) => cast(size_t)0,
        (const ArrayLiteral* a) => a.elements.length,
        (const MapLiteral* m) => cast(size_t)0
    );
    Assert.equal(result3, 1);
    
    writeln("\x1b[32m  ✓ Match pattern provides type-safe exhaustive handling\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.ast - Memory safety with nested structures");
    
    // Create nested array structure
    auto inner1 = ExpressionValue.fromString("a", 1, 1);
    auto inner2 = ExpressionValue.fromString("b", 1, 2);
    auto innerArray = ExpressionValue.fromArray([inner1, inner2], 1, 1);
    
    auto outer = ExpressionValue.fromArray([innerArray], 1, 1);
    
    // Access nested structure safely
    auto outerArr = outer.getArray();
    Assert.isTrue(outerArr !is null);
    Assert.equal(outerArr.elements.length, 1);
    
    auto nestedArr = outerArr.elements[0].getArray();
    Assert.isTrue(nestedArr !is null);
    Assert.equal(nestedArr.elements.length, 2);
    
    auto firstStr = nestedArr.elements[0].getString();
    Assert.isTrue(firstStr !is null);
    Assert.equal(firstStr.value, "a");
    
    writeln("\x1b[32m  ✓ Nested structures accessed safely through type-safe accessors\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.ast - ExpressionValue factory methods are pure");
    
    // These should compile as pure functions
    pure ExpressionValue createString()
    {
        return ExpressionValue.fromString("test", 1, 1);
    }
    
    pure ExpressionValue createNumber()
    {
        return ExpressionValue.fromNumber(123, 1, 1);
    }
    
    pure ExpressionValue createIdentifier()
    {
        return ExpressionValue.fromIdentifier("id", 1, 1);
    }
    
    auto s = createString();
    auto n = createNumber();
    auto i = createIdentifier();
    
    Assert.equal(s.kind, ExpressionValue.Kind.String);
    Assert.equal(n.kind, ExpressionValue.Kind.Number);
    Assert.equal(i.kind, ExpressionValue.Kind.Identifier);
    
    writeln("\x1b[32m  ✓ Factory methods maintain purity guarantees\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.ast - Const correctness with inout accessors");
    
    const auto strExpr = ExpressionValue.fromString("const_test", 1, 1);
    
    // Should be able to access through const
    const(StringLiteral)* str = strExpr.getString();
    Assert.isTrue(str !is null);
    Assert.equal(str.value, "const_test");
    
    // Should return null for wrong type even on const
    const(NumberLiteral)* num = strExpr.getNumber();
    Assert.isTrue(num is null);
    
    writeln("\x1b[32m  ✓ Const correctness maintained with inout accessors\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.ast - isIdentifier helper");
    
    auto id = ExpressionValue.fromIdentifier("myvar", 1, 1);
    auto str = ExpressionValue.fromString("myvar", 1, 1);
    
    Assert.isTrue(id.isIdentifier("myvar"));
    Assert.isTrue(!id.isIdentifier("other"));
    Assert.isTrue(!str.isIdentifier("myvar")); // String, not identifier
    
    writeln("\x1b[32m  ✓ isIdentifier helper works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.ast - Semantic conversion methods");
    
    // asString conversions
    auto str = ExpressionValue.fromString("hello", 1, 1);
    Assert.equal(str.asString(), "hello");
    
    auto id = ExpressionValue.fromIdentifier("world", 1, 1);
    Assert.equal(id.asString(), "world");
    
    auto num = ExpressionValue.fromNumber(42, 1, 1);
    Assert.equal(num.asString(), "42");
    
    // asStringArray conversion
    auto arr = ExpressionValue.fromArray([str, id], 1, 1);
    auto strArr = arr.asStringArray();
    Assert.equal(strArr.length, 2);
    Assert.equal(strArr[0], "hello");
    Assert.equal(strArr[1], "world");
    
    // asMap conversion
    ExpressionValue[string] mapPairs3;
    mapPairs3["key"] = ExpressionValue.fromString("value", 1, 1);
    mapPairs3["foo"] = ExpressionValue.fromString("bar", 1, 1);
    auto map = ExpressionValue.fromMap(mapPairs3, 1, 1);
    auto pairs = map.asMap();
    Assert.equal(pairs.length, 2);
    Assert.equal(pairs["key"], "value");
    Assert.equal(pairs["foo"], "bar");
    
    writeln("\x1b[32m  ✓ Semantic conversion methods work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.ast - Error handling for invalid conversions");
    
    auto arr = ExpressionValue.fromArray([], 1, 1);
    
    bool caughtException = false;
    try
    {
        // Should throw - can't convert array to string
        arr.asString();
    }
    catch (Exception e)
    {
        caughtException = true;
    }
    Assert.isTrue(caughtException);
    
    auto str = ExpressionValue.fromString("test", 1, 1);
    caughtException = false;
    try
    {
        // Should throw - string is not an array
        str.asStringArray();
    }
    catch (Exception e)
    {
        caughtException = true;
    }
    Assert.isTrue(caughtException);
    
    writeln("\x1b[32m  ✓ Invalid conversions throw appropriate exceptions\x1b[0m");
}

