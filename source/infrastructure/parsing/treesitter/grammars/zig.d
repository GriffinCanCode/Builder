module infrastructure.parsing.treesitter.grammars.zig;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Zig grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_zig() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_zig();
        if (!grammar) {
            Logger.debugLog("Zig grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("zig");
        if (!config) {
            Logger.warning("Zig config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "zig",
            &ts_load_zig,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Zig tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Zig grammar not loaded: " ~ e.msg);
    }
}

/// Check if Zig grammar is available
bool isZigGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
