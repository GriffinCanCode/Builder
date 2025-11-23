module infrastructure.parsing.treesitter.grammars.typescript;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Typescript grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_typescript() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_typescript();
        if (!grammar) {
            Logger.debugLog("Typescript grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("typescript");
        if (!config) {
            Logger.warning("Typescript config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "typescript",
            &ts_load_typescript,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Typescript tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Typescript grammar not loaded: " ~ e.msg);
    }
}

/// Check if Typescript grammar is available
bool isTypescriptGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
