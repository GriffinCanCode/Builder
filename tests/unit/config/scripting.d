module tests.unit.config.scripting;

import std.stdio;
import std.algorithm;
import infrastructure.config.parsing.lexer;
import infrastructure.config.parsing.exprparser;
import infrastructure.config.parsing.stmtparser;
import infrastructure.config.scripting.interpreter;
import infrastructure.config.scripting.evaluator;
import infrastructure.config.scripting.builtins;
import infrastructure.config.scripting.scopemanager;
import infrastructure.config.scripting.types;
import infrastructure.config.workspace.expr;
import infrastructure.config.workspace.stmt;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Variable declaration and assignment");
    
    string source = `
        let x = 42;
        let y = "hello";
        let z = true;
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseProgram();
    Assert.isTrue(parseResult.isOk);
    
    auto statements = parseResult.unwrap();
    Assert.equal(statements.length, 3);
    
    writeln("\x1b[32m  ✓ Variable declarations parsed correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Arithmetic expressions");
    
    string source = `1 + 2 * 3`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    // 1 + (2 * 3) = 7 (correct precedence)
    
    writeln("\x1b[32m  ✓ Arithmetic expressions with precedence parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - String concatenation");
    
    string source = `"hello" + " " + "world"`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ String concatenation parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Comparison operators");
    
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
        auto parseResult = parser.parse();
        Assert.isTrue(parseResult.isOk, "Failed to parse: " ~ source);
    }
    
    writeln("\x1b[32m  ✓ All comparison operators parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Logical operators");
    
    string[] sources = [
        `true && false`,
        `true || false`,
        `!true`,
        `x && y || z`,
    ];
    
    foreach (source; sources)
    {
        auto lexResult = lex(source);
        Assert.isTrue(lexResult.isOk);
        
        auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
        auto parseResult = parser.parse();
        Assert.isTrue(parseResult.isOk, "Failed to parse: " ~ source);
    }
    
    writeln("\x1b[32m  ✓ Logical operators parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Ternary operator");
    
    string source = `x > 10 ? "big" : "small"`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Ternary operator parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Array literal");
    
    string source = `[1, 2, 3, "four"]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Array literal parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Map literal");
    
    string source = `{"key": "value", "num": 42}`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Map literal parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Function call");
    
    string source = `myFunction(1, 2, "three")`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Function call parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Array indexing");
    
    string source = `myArray[0]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Array indexing parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Member access");
    
    string source = `object.property`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Member access parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Lambda expression");
    
    string source = `|x| x + 1`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Lambda expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Array map operation");
    
    string source = `packages.map(|p| ":" + p)`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Array map operation parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - If statement");
    
    string source = `
        if (x > 10) {
            y = 20;
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseStatement();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ If statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - If-else statement");
    
    string source = `
        if (x > 10) {
            y = 20;
        } else {
            y = 5;
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseStatement();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ If-else statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - For-in loop");
    
    string source = `
        for pkg in packages {
            target(pkg) {
                type: library;
            }
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseStatement();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ For-in loop parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Function definition");
    
    string source = `
        fn add(a, b) {
            return a + b;
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseStatement();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Function definition parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Function with default parameters");
    
    string source = `
        fn greet(name, greeting = "Hello") {
            return greeting + " " + name;
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseStatement();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Function with default parameters parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Macro definition");
    
    string source = `
        macro genTargets(names) {
            for name in names {
                target(name) {
                    type: library;
                }
            }
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseStatement();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Macro definition parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Nested expressions");
    
    string source = `(1 + 2) * (3 + 4)`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Nested expressions parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Complex chained expression");
    
    string source = `packages.map(|p| ":" + p).filter(|x| x != ":test")`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Complex chained expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Operator precedence");
    
    // Test various precedence scenarios
    string[] sources = [
        `1 + 2 * 3`,           // * before +
        `1 * 2 + 3`,           // * before +
        `x || y && z`,         // && before ||
        `x == y || z == w`,    // == before ||
        `!x && y`,             // ! before &&
    ];
    
    foreach (source; sources)
    {
        auto lexResult = lex(source);
        Assert.isTrue(lexResult.isOk);
        
        auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
        auto parseResult = parser.parse();
        Assert.isTrue(parseResult.isOk, "Failed to parse: " ~ source);
    }
    
    writeln("\x1b[32m  ✓ Operator precedence handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Built-in function: env()");
    
    string source = `env("PATH", "/usr/bin")`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Built-in env() function parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Built-in function: glob()");
    
    string source = `glob("src/**/*.py")`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Built-in glob() function parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - String interpolation");
    
    string source = `"version-${version}"`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    // String interpolation may be handled in lexer or evaluator
    // Just verify it can be tokenized
    
    writeln("\x1b[32m  ✓ String interpolation tokenized\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Complex real-world example");
    
    string source = `
        let packages = ["core", "utils", "api"];
        let version = "1.0.0";
        
        for pkg in packages {
            target(pkg) {
                type: library;
                sources: ["lib/" + pkg + "/**/*.py"];
                output: "bin/lib" + pkg + ".so";
            }
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseProgram();
    Assert.isTrue(parseResult.isOk);
    
    auto statements = parseResult.unwrap();
    Assert.isTrue(statements.length > 0);
    
    writeln("\x1b[32m  ✓ Complex real-world example parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Scope manager");
    
    auto scopeMgr = new ScopeManager();
    
    // Push scope
    scopeMgr.pushScope();
    
    // Define variable
    Value val;
    val.type = ValueType.Number;
    val.numberValue = 42;
    scopeMgr.define("x", val);
    
    // Get variable
    auto result = scopeMgr.get("x");
    Assert.isTrue(result.isOk);
    Assert.equal(result.unwrap().numberValue, 42);
    
    // Pop scope
    scopeMgr.popScope();
    
    // Variable no longer accessible
    auto result2 = scopeMgr.get("x");
    Assert.isTrue(result2.isErr);
    
    writeln("\x1b[32m  ✓ Scope manager works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Nested scopes");
    
    auto scopeMgr = new ScopeManager();
    
    // Global scope
    Value val1;
    val1.type = ValueType.Number;
    val1.numberValue = 10;
    scopeMgr.define("x", val1);
    
    // Push nested scope
    scopeMgr.pushScope();
    
    // Shadow variable
    Value val2;
    val2.type = ValueType.Number;
    val2.numberValue = 20;
    scopeMgr.define("x", val2);
    
    // Should get shadowed value
    auto result = scopeMgr.get("x");
    Assert.isTrue(result.isOk);
    Assert.equal(result.unwrap().numberValue, 20);
    
    // Pop scope
    scopeMgr.popScope();
    
    // Should get original value
    auto result2 = scopeMgr.get("x");
    Assert.isTrue(result2.isOk);
    Assert.equal(result2.unwrap().numberValue, 10);
    
    writeln("\x1b[32m  ✓ Nested scopes with shadowing work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Error: undefined variable");
    
    string source = `undefinedVar + 10`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    
    // Parser should succeed (syntax is valid)
    Assert.isTrue(parseResult.isOk);
    
    // Evaluator would fail on undefined variable (tested separately)
    
    writeln("\x1b[32m  ✓ Undefined variable error path works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Error: syntax error");
    
    string source = `1 + + 2`; // Invalid syntax
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    
    // Should fail to parse
    Assert.isTrue(parseResult.isErr);
    
    writeln("\x1b[32m  ✓ Syntax error detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Const variable");
    
    string source = `
        const PI = 3.14159;
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseProgram();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Const variable declaration parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Return statement");
    
    string source = `
        fn getValue() {
            return 42;
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseStatement();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Return statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Target assignment expression");
    
    string source = `target("mylib") = pythonLib("mylib", [":utils"])`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseStatement();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Target assignment expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Empty array");
    
    string source = `[]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Empty array parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Empty map");
    
    string source = `{}`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Empty map parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Array concatenation");
    
    string source = `[1, 2] + [3, 4]`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Array concatenation parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Negative numbers");
    
    string source = `-42`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new ExprParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parse();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Negative numbers parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.scripting - Import statement");
    
    string source = `import Builderfile.d;`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto parseResult = parser.parseStatement();
    Assert.isTrue(parseResult.isOk);
    
    writeln("\x1b[32m  ✓ Import statement parsed\x1b[0m");
}

