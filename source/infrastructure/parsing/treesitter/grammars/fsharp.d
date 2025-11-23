module infrastructure.parsing.treesitter.grammars.fsharp;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Fsharp grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_fsharp() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_fsharp();
        if (!grammar) {
            Logger.debugLog("Fsharp grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("fsharp");
        if (!config) {
            Logger.warning("Fsharp config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "fsharp",
            &ts_load_fsharp,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Fsharp tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Fsharp grammar not loaded: " ~ e.msg);
    }
}

/// Check if Fsharp grammar is available
bool isFsharpGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
