module tests.unit.config.stmtparser;

import std.stdio;
import std.algorithm;
import config.parsing.lexer;
import config.parsing.stmtparser;
import config.workspace.stmt;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse let statement");
    
    string source = `let x = 42;`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isLet);
    
    writeln("\x1b[32m  ✓ Let statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse const statement");
    
    string source = `const PI = 3.14159;`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isConst);
    
    writeln("\x1b[32m  ✓ Const statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse function definition");
    
    string source = `
        fn add(a, b) {
            return a + b;
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isFunction);
    
    writeln("\x1b[32m  ✓ Function definition parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse function with default parameters");
    
    string source = `
        fn greet(name, greeting = "Hello") {
            return greeting + " " + name;
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isFunction);
    
    writeln("\x1b[32m  ✓ Function with default parameters parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse macro definition");
    
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
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isMacro);
    
    writeln("\x1b[32m  ✓ Macro definition parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse if statement");
    
    string source = `
        if (x > 10) {
            y = 20;
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isIf);
    
    writeln("\x1b[32m  ✓ If statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse if-else statement");
    
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
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isIf);
    
    writeln("\x1b[32m  ✓ If-else statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse for-in loop");
    
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
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isFor);
    
    writeln("\x1b[32m  ✓ For-in loop parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse return statement");
    
    string source = `return 42;`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isReturn);
    
    writeln("\x1b[32m  ✓ Return statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse return statement with expression");
    
    string source = `return x + y;`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isReturn);
    
    writeln("\x1b[32m  ✓ Return statement with expression parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse import statement");
    
    string source = `import Builderfile.d;`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isImport);
    
    writeln("\x1b[32m  ✓ Import statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse target declaration");
    
    string source = `
        target("app") {
            type: executable;
            sources: ["main.py"];
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isTarget);
    
    writeln("\x1b[32m  ✓ Target declaration parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse target assignment");
    
    string source = `target("mylib") = pythonLib("mylib", [":utils"]);`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    // Could be target or expression statement depending on implementation
    auto stmt = result.unwrap();
    
    writeln("\x1b[32m  ✓ Target assignment parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse expression statement");
    
    string source = `myFunction(1, 2, 3);`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isExpression);
    
    writeln("\x1b[32m  ✓ Expression statement parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse multiple statements");
    
    string source = `
        let x = 10;
        let y = 20;
        let z = x + y;
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseProgram();
    Assert.isTrue(result.isOk);
    
    auto statements = result.unwrap();
    Assert.equal(statements.length, 3);
    
    writeln("\x1b[32m  ✓ Multiple statements parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse nested blocks");
    
    string source = `
        if (x > 0) {
            if (y > 0) {
                z = x + y;
            }
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isIf);
    
    writeln("\x1b[32m  ✓ Nested blocks parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Parse complex program");
    
    string source = `
        let packages = ["core", "utils", "api"];
        let version = "1.0.0";
        
        fn createLib(name) {
            return {
                type: library,
                sources: ["lib/" + name + "/**/*.py"]
            };
        }
        
        for pkg in packages {
            target(pkg) = createLib(pkg);
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseProgram();
    Assert.isTrue(result.isOk);
    
    auto statements = result.unwrap();
    Assert.isTrue(statements.length > 0);
    
    writeln("\x1b[32m  ✓ Complex program parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Empty function body");
    
    string source = `
        fn noop() {
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isFunction);
    
    writeln("\x1b[32m  ✓ Empty function body parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Function with no parameters");
    
    string source = `
        fn getValue() {
            return 42;
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isFunction);
    
    writeln("\x1b[32m  ✓ Function with no parameters parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Nested for loops");
    
    string source = `
        for i in range(10) {
            for j in range(10) {
                result = i * j;
            }
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isFor);
    
    writeln("\x1b[32m  ✓ Nested for loops parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - If-else if-else chain");
    
    string source = `
        if (x > 10) {
            result = "big";
        } else if (x > 5) {
            result = "medium";
        } else {
            result = "small";
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isIf);
    
    writeln("\x1b[32m  ✓ If-else if-else chain parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Error: missing semicolon");
    
    string source = `let x = 42`; // Missing semicolon
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    
    // Should fail due to missing semicolon
    Assert.isTrue(result.isErr);
    
    writeln("\x1b[32m  ✓ Missing semicolon error detected\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Error: unclosed block");
    
    string source = `
        if (x > 10) {
            y = 20;
    `; // Missing closing brace
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    
    // Should fail due to unclosed block
    Assert.isTrue(result.isErr);
    
    writeln("\x1b[32m  ✓ Unclosed block error detected\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Error: invalid for loop syntax");
    
    string source = `
        for pkg packages {
            // Missing 'in' keyword
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    
    // Should fail due to invalid syntax
    Assert.isTrue(result.isErr);
    
    writeln("\x1b[32m  ✓ Invalid for loop syntax error detected\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Macro expansion call");
    
    string source = `genTests(["utils", "models", "api"]);`;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isExpression); // Macro call is an expression statement
    
    writeln("\x1b[32m  ✓ Macro expansion call parsed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.stmtparser - Target in for loop");
    
    string source = `
        for pkg in packages {
            target(pkg) {
                type: library;
                sources: ["lib/" + pkg + "/**/*.py"];
            }
        }
    `;
    
    auto lexResult = lex(source);
    Assert.isTrue(lexResult.isOk);
    
    auto parser = new StmtParser(lexResult.unwrap(), "test.builderfile");
    auto result = parser.parseStatement();
    Assert.isTrue(result.isOk);
    
    auto stmt = result.unwrap();
    Assert.isTrue(stmt.isFor);
    
    writeln("\x1b[32m  ✓ Target in for loop parsed\x1b[0m");
}

