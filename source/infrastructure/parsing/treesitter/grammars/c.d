module infrastructure.parsing.treesitter.grammars.c;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// C grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_c() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_c();
        if (!grammar) {
            Logger.debugLog("C grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("c");
        if (!config) {
            Logger.warning("C config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "c",
            &ts_load_c,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ C tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("C grammar not loaded: " ~ e.msg);
    }
}

/// Check if C grammar is available
bool isCGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
