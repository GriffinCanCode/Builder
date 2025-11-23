module infrastructure.parsing.treesitter.grammars.go;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Go grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_go() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_go();
        if (!grammar) {
            Logger.debugLog("Go grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("go");
        if (!config) {
            Logger.warning("Go config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "go",
            &ts_load_go,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Go tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Go grammar not loaded: " ~ e.msg);
    }
}

/// Check if Go grammar is available
bool isGoGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
