module infrastructure.parsing.treesitter.grammars.kotlin;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Kotlin grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_kotlin() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_kotlin();
        if (!grammar) {
            Logger.debugLog("Kotlin grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("kotlin");
        if (!config) {
            Logger.warning("Kotlin config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "kotlin",
            &ts_load_kotlin,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Kotlin tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Kotlin grammar not loaded: " ~ e.msg);
    }
}

/// Check if Kotlin grammar is available
bool isKotlinGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
