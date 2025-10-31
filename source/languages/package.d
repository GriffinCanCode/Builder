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
///   java/        - Java language support (modular - Maven, Gradle, builders, formatters, analysis)
///   cpp.d        - C++ language support
///   csharp/      - C# language support (modular - dotnet, MSBuild, Native AOT, formatters, analyzers)
///   ruby.d       - Ruby language support
///   php/         - PHP language support (modular)
///   r/           - R language support (modular - scripts, packages, Shiny, RMarkdown)
///   swift/       - Swift language support (modular - SPM, Xcode, cross-compilation)
///   kotlin/      - Kotlin language support (modular - Gradle, Maven, multiplatform, Android, KSP, detekt)
///   scala.d      - Scala language support
///   elixir/      - Elixir language support (modular - scripts, Mix, Phoenix, Umbrella, Escript, Nerves)
///   lua/         - Lua language support (modular - runtimes, LuaRocks, LuaJIT, formatters, linters, testers)
///   nim/         - Nim language support (modular)
///   zig.d        - Zig language support
///   protobuf/    - Protocol Buffers support (modular - protoc, buf, code generation)
///
/// Usage:
///   import languages;
///   
///   auto handler = LanguageFactory.create("python");
///   auto deps = handler.analyzeDependencies(sourceFile);
///   handler.build(target);

public import languages.base.base;
public import languages.scripting.python;
public import languages.web;
public import languages.scripting.go;
public import languages.compiled.rust;
public import languages.compiled.d;
public import languages.jvm;
public import languages.compiled.cpp;
public import languages.dotnet;
public import languages.scripting.ruby;
public import languages.scripting.php;
public import languages.scripting.r;
public import languages.compiled.swift;
public import languages.scripting.elixir;
public import languages.scripting.lua;
public import languages.compiled.nim;
public import languages.compiled.zig;

