module infrastructure.parsing.treesitter.grammars.csharp;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Csharp grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_csharp() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_csharp();
        if (!grammar) {
            Logger.debugLog("Csharp grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("csharp");
        if (!config) {
            Logger.warning("Csharp config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "csharp",
            &ts_load_csharp,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Csharp tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Csharp grammar not loaded: " ~ e.msg);
    }
}

/// Check if Csharp grammar is available
bool isCsharpGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
