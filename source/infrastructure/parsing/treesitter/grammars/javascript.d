module infrastructure.parsing.treesitter.grammars.javascript;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Javascript grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_javascript() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_javascript();
        if (!grammar) {
            Logger.debugLog("Javascript grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("javascript");
        if (!config) {
            Logger.warning("Javascript config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "javascript",
            &ts_load_javascript,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Javascript tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Javascript grammar not loaded: " ~ e.msg);
    }
}

/// Check if Javascript grammar is available
bool isJavascriptGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
