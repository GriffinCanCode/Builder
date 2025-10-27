module tests.unit.languages.handlers;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import languages.base;
import languages.scripting.python;
import languages.web.javascript;
import languages.web.typescript;
import languages.scripting.go;
import languages.compiled.rust;
import languages.compiled.d;
import languages.jvm.java;
import languages.jvm.kotlin;
import languages.jvm.scala;
import languages.dotnet.csharp;
import languages.scripting.ruby;
import languages.scripting.php;
import languages.compiled.zig;
import languages.scripting.lua;
import languages.scripting.r;
import languages.scripting.elixir;
import languages.compiled.cpp;
import languages.compiled.nim;
import languages.compiled.swift;
import languages.dotnet.fsharp;
import languages.web.css;
import config.schema;
import errors;
import tests.harness;
import tests.fixtures;

// ==================== PYTHON HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Python handler basic functionality");
    
    auto handler = new PythonHandler();
    auto tempDir = scoped(new TempDir("python-test"));
    
    tempDir.createFile("hello.py", "print('Hello, World!')");
    auto sourcePath = buildPath(tempDir.getPath(), "hello.py");
    
    auto target = TargetBuilder.create("hello")
        .withType(TargetType.Executable)
        .withLanguage("Python")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    // Test needsRebuild (should return true for new file)
    Assert.isTrue(handler.needsRebuild(target, config));
    
    // Test analyze imports (basic smoke test)
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Python handler basic functionality works\x1b[0m");
}

// ==================== JAVASCRIPT HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - JavaScript handler basic functionality");
    
    auto handler = new JavaScriptHandler();
    auto tempDir = scoped(new TempDir("js-test"));
    
    tempDir.createFile("app.js", "console.log('Hello');");
    auto sourcePath = buildPath(tempDir.getPath(), "app.js");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("JavaScript")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ JavaScript handler basic functionality works\x1b[0m");
}

// ==================== TYPESCRIPT HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - TypeScript handler basic functionality");
    
    auto handler = new TypeScriptHandler();
    auto tempDir = scoped(new TempDir("ts-test"));
    
    tempDir.createFile("app.ts", "const msg: string = 'Hello';\nconsole.log(msg);");
    auto sourcePath = buildPath(tempDir.getPath(), "app.ts");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("TypeScript")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ TypeScript handler basic functionality works\x1b[0m");
}

// ==================== GO HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Go handler basic functionality");
    
    auto handler = new GoHandler();
    auto tempDir = scoped(new TempDir("go-test"));
    
    tempDir.createFile("main.go", "package main\n\nfunc main() {}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.go");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Go")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Go handler basic functionality works\x1b[0m");
}

// ==================== RUST HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Rust handler basic functionality");
    
    auto handler = new RustHandler();
    auto tempDir = scoped(new TempDir("rust-test"));
    
    tempDir.createFile("main.rs", "fn main() {\n    println!(\"Hello\");\n}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.rs");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Rust")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Rust handler basic functionality works\x1b[0m");
}

// ==================== D HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - D handler basic functionality");
    
    auto handler = new DHandler();
    auto tempDir = scoped(new TempDir("d-test"));
    
    tempDir.createFile("main.d", "void main() {}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.d");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("D")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ D handler basic functionality works\x1b[0m");
}

// ==================== JAVA HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Java handler basic functionality");
    
    auto handler = new JavaHandler();
    auto tempDir = scoped(new TempDir("java-test"));
    
    tempDir.createFile("Main.java", 
        "public class Main {\n    public static void main(String[] args) {}\n}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "Main.java");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Java")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Java handler basic functionality works\x1b[0m");
}

// ==================== KOTLIN HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Kotlin handler basic functionality");
    
    auto handler = new KotlinHandler();
    auto tempDir = scoped(new TempDir("kotlin-test"));
    
    tempDir.createFile("Main.kt", "fun main() {}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "Main.kt");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Kotlin")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Kotlin handler basic functionality works\x1b[0m");
}

// ==================== SCALA HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Scala handler basic functionality");
    
    auto handler = new ScalaHandler();
    auto tempDir = scoped(new TempDir("scala-test"));
    
    tempDir.createFile("Main.scala", "object Main extends App {}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "Main.scala");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Scala")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Scala handler basic functionality works\x1b[0m");
}

// ==================== C# HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - C# handler basic functionality");
    
    auto handler = new CSharpHandler();
    auto tempDir = scoped(new TempDir("csharp-test"));
    
    tempDir.createFile("Program.cs", 
        "class Program {\n    static void Main() {}\n}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "Program.cs");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("CSharp")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ C# handler basic functionality works\x1b[0m");
}

// ==================== RUBY HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Ruby handler basic functionality");
    
    auto handler = new RubyHandler();
    auto tempDir = scoped(new TempDir("ruby-test"));
    
    tempDir.createFile("main.rb", "puts 'Hello'\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.rb");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Ruby")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Ruby handler basic functionality works\x1b[0m");
}

// ==================== PHP HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - PHP handler basic functionality");
    
    auto handler = new PHPHandler();
    auto tempDir = scoped(new TempDir("php-test"));
    
    tempDir.createFile("index.php", "<?php\necho 'Hello';\n?>\n");
    auto sourcePath = buildPath(tempDir.getPath(), "index.php");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("PHP")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ PHP handler basic functionality works\x1b[0m");
}

// ==================== ZIG HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Zig handler basic functionality");
    
    auto handler = new ZigHandler();
    auto tempDir = scoped(new TempDir("zig-test"));
    
    tempDir.createFile("main.zig", 
        "const std = @import(\"std\");\npub fn main() void {}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.zig");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Zig")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Zig handler basic functionality works\x1b[0m");
}

// ==================== LUA HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Lua handler basic functionality");
    
    auto handler = new LuaHandler();
    auto tempDir = scoped(new TempDir("lua-test"));
    
    tempDir.createFile("main.lua", "print('Hello')\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.lua");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Lua")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Lua handler basic functionality works\x1b[0m");
}

// ==================== R HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - R handler basic functionality");
    
    auto handler = new RHandler();
    auto tempDir = scoped(new TempDir("r-test"));
    
    tempDir.createFile("main.R", "print('Hello')\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.R");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("R")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ R handler basic functionality works\x1b[0m");
}

// ==================== C++ HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - C++ handler basic functionality");
    
    auto handler = new CppHandler();
    auto tempDir = scoped(new TempDir("cpp-test"));
    
    tempDir.createFile("main.cpp", 
        "#include <iostream>\n\nint main() {\n    std::cout << \"Hello\" << std::endl;\n    return 0;\n}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.cpp");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Cpp")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ C++ handler basic functionality works\x1b[0m");
}

// ==================== NIM HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Nim handler basic functionality");
    
    auto handler = new NimHandler();
    auto tempDir = scoped(new TempDir("nim-test"));
    
    tempDir.createFile("main.nim", 
        "echo \"Hello from Nim\"\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.nim");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Nim")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Nim handler basic functionality works\x1b[0m");
}

// ==================== SWIFT HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Swift handler basic functionality");
    
    auto handler = new SwiftHandler();
    auto tempDir = scoped(new TempDir("swift-test"));
    
    tempDir.createFile("main.swift", 
        "import Foundation\n\nprint(\"Hello from Swift\")\n");
    auto sourcePath = buildPath(tempDir.getPath(), "main.swift");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Swift")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Swift handler basic functionality works\x1b[0m");
}

// ==================== F# HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - F# handler basic functionality");
    
    auto handler = new FSharpHandler();
    auto tempDir = scoped(new TempDir("fsharp-test"));
    
    tempDir.createFile("Program.fs", 
        "[<EntryPoint>]\nlet main argv =\n    printfn \"Hello from F#\"\n    0\n");
    auto sourcePath = buildPath(tempDir.getPath(), "Program.fs");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("FSharp")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ F# handler basic functionality works\x1b[0m");
}

// ==================== ELIXIR HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Elixir handler basic functionality");
    
    auto handler = new ElixirHandler();
    auto tempDir = scoped(new TempDir("elixir-test"));
    
    tempDir.createFile("hello.ex", 
        "defmodule Hello do\n  def main do\n    IO.puts \"Hello from Elixir\"\n  end\nend\n");
    auto sourcePath = buildPath(tempDir.getPath(), "hello.ex");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Elixir")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Elixir handler basic functionality works\x1b[0m");
}

// ==================== CSS HANDLER TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - CSS handler basic functionality");
    
    auto handler = new CSSHandler();
    auto tempDir = scoped(new TempDir("css-test"));
    
    tempDir.createFile("styles.css", 
        "body {\n    margin: 0;\n    padding: 0;\n    font-family: Arial, sans-serif;\n}\n");
    auto sourcePath = buildPath(tempDir.getPath(), "styles.css");
    
    auto target = TargetBuilder.create("styles")
        .withType(TargetType.Library)
        .withLanguage("CSS")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([sourcePath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ CSS handler basic functionality works\x1b[0m");
}

// ==================== MULTI-FILE TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Multi-file Python project");
    
    auto handler = new PythonHandler();
    auto tempDir = scoped(new TempDir("python-multi-test"));
    
    tempDir.createFile("main.py", "import utils\nutils.hello()");
    tempDir.createFile("utils.py", "def hello():\n    print('Hello')");
    
    auto mainPath = buildPath(tempDir.getPath(), "main.py");
    auto utilsPath = buildPath(tempDir.getPath(), "utils.py");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Python")
        .withSources([mainPath, utilsPath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([mainPath, utilsPath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Multi-file Python project works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Multi-file JavaScript project");
    
    auto handler = new JavaScriptHandler();
    auto tempDir = scoped(new TempDir("js-multi-test"));
    
    tempDir.createFile("app.js", "const utils = require('./utils');\nutils.greet();");
    tempDir.createFile("utils.js", "exports.greet = () => console.log('Hi');");
    
    auto appPath = buildPath(tempDir.getPath(), "app.js");
    auto utilsPath = buildPath(tempDir.getPath(), "utils.js");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("JavaScript")
        .withSources([appPath, utilsPath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([appPath, utilsPath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Multi-file JavaScript project works\x1b[0m");
}

// ==================== ERROR HANDLING TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Handler with missing source file");
    
    auto handler = new PythonHandler();
    auto tempDir = scoped(new TempDir("missing-test"));
    
    auto missingPath = buildPath(tempDir.getPath(), "nonexistent.py");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Python")
        .withSources([missingPath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    // Should handle missing file gracefully
    auto imports = handler.analyzeImports([missingPath]);
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Handler with missing source file handled gracefully\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Empty source file handling");
    
    auto handler = new PythonHandler();
    auto tempDir = scoped(new TempDir("empty-test"));
    
    tempDir.createFile("empty.py", "");
    auto emptyPath = buildPath(tempDir.getPath(), "empty.py");
    
    auto target = TargetBuilder.create("app")
        .withType(TargetType.Executable)
        .withLanguage("Python")
        .withSources([emptyPath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    Assert.isTrue(handler.needsRebuild(target, config));
    
    auto imports = handler.analyzeImports([emptyPath]);
    Assert.notNull(imports);
    Assert.isEmpty(imports, "Empty file should have no imports");
    
    writeln("\x1b[32m  ✓ Empty source file handled correctly\x1b[0m");
}

// ==================== CROSS-LANGUAGE COMPARISON TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - All handlers implement base interface");
    
    LanguageHandler[] handlers = [
        cast(LanguageHandler)new PythonHandler(),
        cast(LanguageHandler)new JavaScriptHandler(),
        cast(LanguageHandler)new TypeScriptHandler(),
        cast(LanguageHandler)new GoHandler(),
        cast(LanguageHandler)new RustHandler(),
        cast(LanguageHandler)new DHandler(),
        cast(LanguageHandler)new JavaHandler(),
        cast(LanguageHandler)new KotlinHandler(),
        cast(LanguageHandler)new ScalaHandler(),
        cast(LanguageHandler)new CSharpHandler(),
        cast(LanguageHandler)new RubyHandler(),
        cast(LanguageHandler)new PHPHandler(),
        cast(LanguageHandler)new ZigHandler(),
        cast(LanguageHandler)new LuaHandler(),
        cast(LanguageHandler)new RHandler(),
        cast(LanguageHandler)new CppHandler(),
        cast(LanguageHandler)new NimHandler(),
        cast(LanguageHandler)new SwiftHandler(),
        cast(LanguageHandler)new FSharpHandler(),
        cast(LanguageHandler)new ElixirHandler(),
        cast(LanguageHandler)new CSSHandler()
    ];
    
    foreach (handler; handlers)
    {
        Assert.notNull(handler, "Handler should not be null");
    }
    
    Assert.equal(handlers.length, 21, "Should have 21 language handlers");
    
    writeln("\x1b[32m  ✓ All handlers implement base interface\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.handlers - Handlers are stateless");
    
    auto handler1 = new PythonHandler();
    auto handler2 = new PythonHandler();
    
    auto tempDir = scoped(new TempDir("stateless-test"));
    tempDir.createFile("test.py", "print('test')");
    auto sourcePath = buildPath(tempDir.getPath(), "test.py");
    
    auto target = TargetBuilder.create("test")
        .withType(TargetType.Executable)
        .withLanguage("Python")
        .withSources([sourcePath])
        .build();
    
    auto config = new WorkspaceConfig();
    config.rootDir = tempDir.getPath();
    
    // Both handlers should behave identically
    auto result1 = handler1.needsRebuild(target, config);
    auto result2 = handler2.needsRebuild(target, config);
    
    Assert.equal(result1, result2, "Handlers should be stateless");
    
    writeln("\x1b[32m  ✓ Handlers are stateless\x1b[0m");
}

