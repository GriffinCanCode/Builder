module infrastructure.parsing.treesitter.grammars.haskell;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Haskell grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_haskell() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_haskell();
        if (!grammar) {
            Logger.debugLog("Haskell grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("haskell");
        if (!config) {
            Logger.warning("Haskell config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "haskell",
            &ts_load_haskell,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Haskell tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Haskell grammar not loaded: " ~ e.msg);
    }
}

/// Check if Haskell grammar is available
bool isHaskellGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
