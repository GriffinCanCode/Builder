module infrastructure.parsing.treesitter.grammars.cpp;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Cpp grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_cpp() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_cpp();
        if (!grammar) {
            Logger.debugLog("Cpp grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("cpp");
        if (!config) {
            Logger.warning("Cpp config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "cpp",
            &ts_load_cpp,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Cpp tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Cpp grammar not loaded: " ~ e.msg);
    }
}

/// Check if Cpp grammar is available
bool isCppGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
