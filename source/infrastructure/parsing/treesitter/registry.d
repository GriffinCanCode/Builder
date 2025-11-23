module infrastructure.parsing.treesitter.registry;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;
import infrastructure.errors;

/// Registry for tree-sitter language grammars
/// Manages loading and instantiation of language parsers
final class TreeSitterRegistry {
    private static TreeSitterRegistry instance_;
    private GrammarEntry[string] grammars;
    
    private struct GrammarEntry {
        const(TSLanguage)* grammar;
        LanguageConfig config;
        bool loaded;
    }
    
    private this() @safe {
        // Singleton
    }
    
    static TreeSitterRegistry instance() @trusted {
        if (!instance_)
            instance_ = new TreeSitterRegistry();
        return instance_;
    }
    
    /// Register a language grammar
    /// Grammar loading functions should be extern(C) and return const(TSLanguage)*
    void registerGrammar(
        string languageId,
        const(TSLanguage)* function() @system nothrow @nogc grammarLoader,
        LanguageConfig config
    ) @system {
        GrammarEntry entry;
        entry.config = config;
        entry.loaded = false;
        
        // Lazy load - only load grammar when first parser is created
        grammars[languageId] = entry;
        
        Logger.debugLog("Registered tree-sitter grammar: " ~ languageId);
    }
    
    /// Create a parser for a language
    Result!(TreeSitterParser, BuildError) createParser(string languageId) @system {
        auto entry = languageId in grammars;
        if (!entry)
            return Result!(TreeSitterParser, BuildError).err(
                new GenericError("No grammar registered for: " ~ languageId,
                               ErrorCode.UnsupportedLanguage));
        
        // Load grammar if not already loaded
        if (!entry.loaded) {
            // Grammar loading would happen here
            // For now, we assume grammar is available
            entry.loaded = true;
        }
        
        if (!entry.grammar)
            return Result!(TreeSitterParser, BuildError).err(
                new GenericError("Failed to load grammar for: " ~ languageId,
                               ErrorCode.InternalError));
        
        auto parser = new TreeSitterParser(entry.grammar, entry.config);
        return Result!(TreeSitterParser, BuildError).ok(parser);
    }
    
    /// Check if a language is supported
    bool hasGrammar(string languageId) const @safe {
        return (languageId in grammars) !is null;
    }
    
    /// Get all supported languages
    string[] supportedLanguages() @system {
        return grammars.keys;
    }
    
    /// Get language config
    LanguageConfig* getConfig(string languageId) @system {
        auto entry = languageId in grammars;
        return entry ? &entry.config : null;
    }
}

/// Initialize tree-sitter parsers and register them
/// Call this after initializeASTParsers() to add tree-sitter support
void registerTreeSitterParsers() @system {
    auto tsRegistry = TreeSitterRegistry.instance();
    auto astRegistry = ASTParserRegistry.instance();
    
    // For each language with a config, register if grammar is available
    foreach (langId; LanguageConfigs.available()) {
        auto config = LanguageConfigs.get(langId);
        if (!config)
            continue;
        
        // Check if grammar loader is available (would be set by language modules)
        // For now, we just register the configs
        // Grammar loading will be added in Phase 2
        
        Logger.debugLog("Tree-sitter config available for: " ~ langId);
    }
    
    Logger.info("Tree-sitter parser registry initialized");
}

/// Grammar loader function type
/// Each language module should provide this
alias GrammarLoader = extern(C) const(TSLanguage)* function() @system nothrow @nogc;

/// Macro for declaring grammar loaders
/// Usage: mixin(DefineGrammarLoader!("python", "tree_sitter_python"));
template DefineGrammarLoader(string langId, string grammarSymbol) {
    enum DefineGrammarLoader = 
        "extern(C) const(TSLanguage)* " ~ grammarSymbol ~ "() @system nothrow @nogc;\n" ~
        "static this() {\n" ~
        "    auto config = LanguageConfigs.get(\"" ~ langId ~ "\");\n" ~
        "    if (config) {\n" ~
        "        TreeSitterRegistry.instance().registerGrammar(\n" ~
        "            \"" ~ langId ~ "\",\n" ~
        "            &" ~ grammarSymbol ~ ",\n" ~
        "            *config\n" ~
        "        );\n" ~
        "    }\n" ~
        "}\n";
}

