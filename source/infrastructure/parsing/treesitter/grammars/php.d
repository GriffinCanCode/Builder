module infrastructure.parsing.treesitter.grammars.php;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Php grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_php() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_php();
        if (!grammar) {
            Logger.debugLog("Php grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("php");
        if (!config) {
            Logger.warning("Php config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "php",
            &ts_load_php,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Php tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Php grammar not loaded: " ~ e.msg);
    }
}

/// Check if Php grammar is available
bool isPhpGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
