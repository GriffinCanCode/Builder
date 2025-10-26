module languages;

/// Language Support Package
/// Language-specific build handlers and dependency analysis
/// 
/// Architecture:
///   base.d       - Base language interface
///   python.d     - Python language support
///   javascript.d - JavaScript/Node.js support
///   typescript.d - TypeScript support with type checking
///   go.d         - Go language support
///   rust.d       - Rust language support
///   java.d       - Java language support
///   cpp.d        - C++ language support
///   csharp.d     - C# language support
///   ruby.d       - Ruby language support
///   php.d        - PHP language support
///   swift.d      - Swift language support
///   kotlin.d     - Kotlin language support
///   scala.d      - Scala language support
///   elixir.d     - Elixir language support
///   lua.d        - Lua language support
///   nim.d        - Nim language support
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
public import languages.jvm.java;
public import languages.compiled.cpp;
public import languages.dotnet.csharp;
public import languages.scripting.ruby;
public import languages.scripting.php;
public import languages.dotnet.swift;
public import languages.jvm.kotlin;
public import languages.jvm.scala;
public import languages.scripting.elixir;
public import languages.scripting.lua;
public import languages.compiled.nim;
public import languages.compiled.zig;

