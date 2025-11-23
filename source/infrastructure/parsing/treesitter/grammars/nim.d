module infrastructure.parsing.treesitter.grammars.nim;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Nim grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_nim() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_nim();
        if (!grammar) {
            Logger.debugLog("Nim grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("nim");
        if (!config) {
            Logger.warning("Nim config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "nim",
            &ts_load_nim,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Nim tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Nim grammar not loaded: " ~ e.msg);
    }
}

/// Check if Nim grammar is available
bool isNimGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
