module infrastructure.parsing.treesitter.grammars.ruby;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Ruby grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_ruby() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_ruby();
        if (!grammar) {
            Logger.debugLog("Ruby grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("ruby");
        if (!config) {
            Logger.warning("Ruby config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "ruby",
            &ts_load_ruby,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Ruby tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Ruby grammar not loaded: " ~ e.msg);
    }
}

/// Check if Ruby grammar is available
bool isRubyGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
