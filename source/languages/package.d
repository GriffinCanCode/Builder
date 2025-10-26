module languages;

/// Language Support Package
/// Language-specific build handlers and dependency analysis
/// 
/// Architecture:
///   base.d       - Base language interface
///   python/      - Python language support (modular)
///   javascript/  - JavaScript/Node.js support (modular)
///   typescript/  - TypeScript support with type checking (modular)
///   go/          - Go language support (modular)
///   rust/        - Rust language support (modular)
///   java.d       - Java language support
///   cpp.d        - C++ language support
///   csharp.d     - C# language support
///   ruby.d       - Ruby language support
///   php/         - PHP language support (modular)
///   r/           - R language support (modular - scripts, packages, Shiny, RMarkdown)
///   swift.d      - Swift language support
///   kotlin.d     - Kotlin language support
///   scala.d      - Scala language support
///   elixir/      - Elixir language support (modular - scripts, Mix, Phoenix, Umbrella, Escript, Nerves)
///   lua/         - Lua language support (modular - runtimes, LuaRocks, LuaJIT, formatters, linters, testers)
///   nim/         - Nim language support (modular)
///   zig.d        - Zig language support
///
/// Usage:
///   import languages;
///   
///   auto handler = LanguageFactory.create("python");
///   auto deps = handler.analyzeDependencies(sourceFile);
///   handler.build(target);

public import languages.base.base;
public import languages.scripting.python;
public import languages.scripting.javascript;
public import languages.scripting.typescript;
public import languages.scripting.go;
public import languages.compiled.rust;
public import languages.compiled.d;
public import languages.jvm.java;
public import languages.compiled.cpp;
public import languages.dotnet.csharp;
public import languages.scripting.ruby;
public import languages.scripting.php;
public import languages.scripting.r;
public import languages.dotnet.swift;
public import languages.jvm.kotlin;
public import languages.jvm.scala;
public import languages.scripting.elixir;
public import languages.scripting.lua;
public import languages.compiled.nim;
public import languages.compiled.zig;

