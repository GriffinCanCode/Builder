module runtime.services.registry;

import config.schema.schema : TargetLanguage;
import languages.base.base : LanguageHandler;
import errors;

/// Handler registry interface
interface IHandlerRegistry
{
    /// Get handler for language
    LanguageHandler get(TargetLanguage language);
    
    /// Check if handler exists for language
    bool has(TargetLanguage language);
    
    /// Register handler for language
    void register(TargetLanguage language, LanguageHandler handler);
    
    /// Get all registered languages
    TargetLanguage[] languages();
}

/// Concrete handler registry implementation
/// Manages language handler lifecycle and lookup
final class HandlerRegistry : IHandlerRegistry
{
    private LanguageHandler[TargetLanguage] handlers;
    private bool _initialized;
    
    this()
    {
        _initialized = false;
    }
    
    /// Initialize registry with all language handlers
    /// Lazy initialization pattern - only create handlers when needed
    void initialize() @trusted
    {
        if (_initialized)
            return;
        
        // Import all handler modules
        import languages.scripting.python : PythonHandler;
        import languages.web.javascript : JavaScriptHandler;
        import languages.web.typescript : TypeScriptHandler;
        import languages.web.elm : ElmHandler;
        import languages.scripting.go : GoHandler;
        import languages.compiled.rust : RustHandler;
        import languages.compiled.d : DHandler;
        import languages.compiled.cpp : CppHandler, CHandler;
        import languages.jvm.java : JavaHandler;
        import languages.jvm.kotlin : KotlinHandler;
        import languages.jvm.scala : ScalaHandler;
        import languages.dotnet.csharp : CSharpHandler;
        import languages.compiled.zig : ZigHandler;
        import languages.compiled.swift : SwiftHandler;
        import languages.scripting.ruby : RubyHandler;
        import languages.scripting.perl : PerlHandler;
        import languages.scripting.php : PHPHandler;
        import languages.scripting.elixir : ElixirHandler;
        import languages.compiled.nim : NimHandler;
        import languages.scripting.lua : LuaHandler;
        import languages.scripting.r : RHandler;
        import languages.compiled.haskell : HaskellHandler;
        import languages.compiled.ocaml : OCamlHandler;
        import languages.compiled.protobuf : ProtobufHandler;
        
        // Register all handlers
        handlers[TargetLanguage.Python] = new PythonHandler();
        handlers[TargetLanguage.JavaScript] = new JavaScriptHandler();
        handlers[TargetLanguage.TypeScript] = new TypeScriptHandler();
        handlers[TargetLanguage.Elm] = new ElmHandler();
        handlers[TargetLanguage.Go] = new GoHandler();
        handlers[TargetLanguage.Rust] = new RustHandler();
        handlers[TargetLanguage.D] = new DHandler();
        handlers[TargetLanguage.Cpp] = new CppHandler();
        handlers[TargetLanguage.C] = new CHandler();
        handlers[TargetLanguage.Java] = new JavaHandler();
        handlers[TargetLanguage.Kotlin] = new KotlinHandler();
        handlers[TargetLanguage.Scala] = new ScalaHandler();
        handlers[TargetLanguage.CSharp] = new CSharpHandler();
        handlers[TargetLanguage.Zig] = new ZigHandler();
        handlers[TargetLanguage.Swift] = new SwiftHandler();
        handlers[TargetLanguage.Ruby] = new RubyHandler();
        handlers[TargetLanguage.Perl] = new PerlHandler();
        handlers[TargetLanguage.PHP] = new PHPHandler();
        handlers[TargetLanguage.Elixir] = new ElixirHandler();
        handlers[TargetLanguage.Nim] = new NimHandler();
        handlers[TargetLanguage.Lua] = new LuaHandler();
        handlers[TargetLanguage.R] = new RHandler();
        handlers[TargetLanguage.Haskell] = new HaskellHandler();
        handlers[TargetLanguage.OCaml] = new OCamlHandler();
        handlers[TargetLanguage.Protobuf] = new ProtobufHandler();
        
        _initialized = true;
    }
    
    LanguageHandler get(TargetLanguage language) @trusted
    {
        if (!_initialized)
            initialize();
        
        return handlers.get(language, null);
    }
    
    bool has(TargetLanguage language) @trusted
    {
        if (!_initialized)
            initialize();
        
        return (language in handlers) !is null;
    }
    
    void register(TargetLanguage language, LanguageHandler handler) @trusted
    {
        handlers[language] = handler;
        _initialized = true;
    }
    
    TargetLanguage[] languages() @trusted
    {
        if (!_initialized)
            initialize();
        
        return handlers.keys;
    }
}

/// Null handler registry for testing
final class NullHandlerRegistry : IHandlerRegistry
{
    LanguageHandler get(TargetLanguage language) @trusted
    {
        return null;
    }
    
    bool has(TargetLanguage language) @trusted
    {
        return false;
    }
    
    void register(TargetLanguage language, LanguageHandler handler) @trusted
    {
    }
    
    TargetLanguage[] languages() @trusted
    {
        return [];
    }
}

