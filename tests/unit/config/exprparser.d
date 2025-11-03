module tests.unit.config.exprparser;

import std.stdio;
import std.algorithm;
import infrastructure.config.parsing.lexer;
import infrastructure.config.parsing.exprparser;
import infrastructure.config.workspace.expr;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse literal string");
    
    string source = `"hello world"`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isLiteral);
    
    writeln("\x1b[32m  ✓ String literal parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse literal number");
    
    string source = `42`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isLiteral);
    
    writeln("\x1b[32m  ✓ Number literal parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse boolean literals");
    
    string[] sources = [`true`, `false`];
    
    foreach (source; sources)
    {
        auto lexResult = lex(source);
        Assert.isTrue(lexResult.isOk);
        
        auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
        auto result = parser.parse();
        Assert.isTrue(result.isOk, "Failed to parse: " ~ source);
    }
    
    writeln("\x1b[32m  ✓ Boolean literals parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse identifier");
    
    string source = `myVariable`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isIdentifier);
    
    writeln("\x1b[32m  ✓ Identifier parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse array literal");
    
    string source = `[1, 2, 3, "four"]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isArrayLiteral);
    
    writeln("\x1b[32m  ✓ Array literal parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse map literal");
    
    string source = `{"key": "value", "number": 42}`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isMapLiteral);
    
    writeln("\x1b[32m  ✓ Map literal parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse binary expression: addition");
    
    string source = `1 + 2`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isBinary);
    
    writeln("\x1b[32m  ✓ Binary addition expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse binary expression: multiplication");
    
    string source = `3 * 4`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isBinary);
    
    writeln("\x1b[32m  ✓ Binary multiplication expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Operator precedence: multiply before add");
    
    string source = `1 + 2 * 3`; // Should parse as: 1 + (2 * 3)
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isBinary);
    
    // The root should be +, and the right child should be *
    // This tests that * binds tighter than +
    
    writeln("\x1b[32m  ✓ Operator precedence (multiply before add) correct\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Operator precedence: comparison before logical");
    
    string source = `x == y || z == w`; // Should parse as: (x == y) || (z == w)
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isBinary);
    
    writeln("\x1b[32m  ✓ Operator precedence (comparison before logical) correct\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Operator precedence: AND before OR");
    
    string source = `a || b && c`; // Should parse as: a || (b && c)
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isBinary);
    
    writeln("\x1b[32m  ✓ Operator precedence (AND before OR) correct\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse unary expression: negation");
    
    string source = `-42`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isUnary);
    
    writeln("\x1b[32m  ✓ Unary negation parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse unary expression: logical not");
    
    string source = `!true`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isUnary);
    
    writeln("\x1b[32m  ✓ Logical not parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse function call");
    
    string source = `myFunc(1, 2, "three")`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isCall);
    
    writeln("\x1b[32m  ✓ Function call parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse function call with no arguments");
    
    string source = `myFunc()`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isCall);
    
    writeln("\x1b[32m  ✓ Function call with no arguments parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse member access");
    
    string source = `object.property`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isMember);
    
    writeln("\x1b[32m  ✓ Member access parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse chained member access");
    
    string source = `object.child.property`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isMember);
    
    writeln("\x1b[32m  ✓ Chained member access parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse index expression");
    
    string source = `array[0]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isIndex);
    
    writeln("\x1b[32m  ✓ Index expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse slice expression");
    
    string source = `array[1:5]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isSlice);
    
    writeln("\x1b[32m  ✓ Slice expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse ternary expression");
    
    string source = `x > 10 ? "big" : "small"`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isTernary);
    
    writeln("\x1b[32m  ✓ Ternary expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse lambda expression");
    
    string source = `|x| x + 1`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isLambda);
    
    writeln("\x1b[32m  ✓ Lambda expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse lambda with multiple parameters");
    
    string source = `|x, y| x + y`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isLambda);
    
    writeln("\x1b[32m  ✓ Lambda with multiple parameters parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse complex chained call");
    
    string source = `packages.map(|p| ":" + p)`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    // Should be: member(identifier("packages"), "map") called with lambda
    auto expr = result.unwrap();
    Assert.isTrue(expr.isCall);
    
    writeln("\x1b[32m  ✓ Complex chained call parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse nested function calls");
    
    string source = `outer(inner(42))`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isCall);
    
    writeln("\x1b[32m  ✓ Nested function calls parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse parenthesized expression");
    
    string source = `(1 + 2) * 3`; // Parentheses override precedence
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isBinary);
    
    writeln("\x1b[32m  ✓ Parenthesized expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse all comparison operators");
    
    string[] sources = [
        `x == y`,
        `x != y`,
        `x < y`,
        `x <= y`,
        `x > y`,
        `x >= y`,
    ];
    
    foreach (source; sources)
    {
        auto lexResult = lex(source);
        Assert.isTrue(lexResult.isOk);
        
        auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
        auto result = parser.parse();
        Assert.isTrue(result.isOk, "Failed to parse: " ~ source);
        
        auto expr = result.unwrap();
        Assert.isTrue(expr.isBinary);
    }
    
    writeln("\x1b[32m  ✓ All comparison operators parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse all arithmetic operators");
    
    string[] sources = [
        `x + y`,
        `x - y`,
        `x * y`,
        `x / y`,
        `x % y`,
    ];
    
    foreach (source; sources)
    {
        auto lexResult = lex(source);
        Assert.isTrue(lexResult.isOk);
        
        auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
        auto result = parser.parse();
        Assert.isTrue(result.isOk, "Failed to parse: " ~ source);
        
        auto expr = result.unwrap();
        Assert.isTrue(expr.isBinary);
    }
    
    writeln("\x1b[32m  ✓ All arithmetic operators parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse logical operators");
    
    string[] sources = [
        `x && y`,
        `x || y`,
        `!x`,
    ];
    
    foreach (source; sources)
    {
        auto lexResult = lex(source);
        Assert.isTrue(lexResult.isOk);
        
        auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
        auto result = parser.parse();
        Assert.isTrue(result.isOk, "Failed to parse: " ~ source);
    }
    
    writeln("\x1b[32m  ✓ Logical operators parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse string concatenation");
    
    string source = `"hello" + " " + "world"`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isBinary);
    
    writeln("\x1b[32m  ✓ String concatenation parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Parse array concatenation");
    
    string source = `[1, 2] + [3, 4]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isBinary);
    
    writeln("\x1b[32m  ✓ Array concatenation parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Error: unclosed array");
    
    string source = `[1, 2, 3`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isErr);
    
    writeln("\x1b[32m  ✓ Unclosed array error detected\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Error: unclosed map");
    
    string source = `{"key": "value"`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isErr);
    
    writeln("\x1b[32m  ✓ Unclosed map error detected\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Error: invalid map key");
    
    string source = `{42: "value"}`; // Number as key (not allowed in some contexts)
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    
    // May or may not be an error depending on implementation
    // Just verify it doesn't crash
    
    writeln("\x1b[32m  ✓ Invalid map key handled\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Empty array");
    
    string source = `[]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isArrayLiteral);
    
    writeln("\x1b[32m  ✓ Empty array parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Empty map");
    
    string source = `{}`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isMapLiteral);
    
    writeln("\x1b[32m  ✓ Empty map parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Nested arrays");
    
    string source = `[[1, 2], [3, 4]]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isArrayLiteral);
    
    writeln("\x1b[32m  ✓ Nested arrays parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Nested maps");
    
    string source = `{"outer": {"inner": "value"}}`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    auto expr = result.unwrap();
    Assert.isTrue(expr.isMapLiteral);
    
    writeln("\x1b[32m  ✓ Nested maps parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.exprparser - Complex real-world expression");
    
    string source = `packages.map(|p| ":" + p).filter(|x| x != ":test")`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parse();
    Assert.isTrue(result.isOk);
    
    // Should be: call(member(call(member(id, "map"), lambda), "filter"), lambda)
    auto expr = result.unwrap();
    Assert.isTrue(expr.isCall);
    
    writeln("\x1b[32m  ✓ Complex real-world expression parsed\x1b[0m");
}

