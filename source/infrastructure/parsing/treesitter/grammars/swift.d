module infrastructure.parsing.treesitter.grammars.swift;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Swift grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_swift() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_swift();
        if (!grammar) {
            Logger.debugLog("Swift grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("swift");
        if (!config) {
            Logger.warning("Swift config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "swift",
            &ts_load_swift,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Swift tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Swift grammar not loaded: " ~ e.msg);
    }
}

/// Check if Swift grammar is available
bool isSwiftGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
