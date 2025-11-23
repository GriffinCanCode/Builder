module infrastructure.parsing.treesitter.grammars.rust;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Rust grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_rust() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_rust();
        if (!grammar) {
            Logger.debugLog("Rust grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("rust");
        if (!config) {
            Logger.warning("Rust config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "rust",
            &ts_load_rust,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Rust tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Rust grammar not loaded: " ~ e.msg);
    }
}

/// Check if Rust grammar is available
bool isRustGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
