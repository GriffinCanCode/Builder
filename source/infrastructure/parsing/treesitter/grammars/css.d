module infrastructure.parsing.treesitter.grammars.css;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Css grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_css() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_css();
        if (!grammar) {
            Logger.debugLog("Css grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("css");
        if (!config) {
            Logger.warning("Css config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "css",
            &ts_load_css,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Css tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Css grammar not loaded: " ~ e.msg);
    }
}

/// Check if Css grammar is available
bool isCssGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
