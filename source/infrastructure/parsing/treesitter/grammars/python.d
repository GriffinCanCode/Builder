module infrastructure.parsing.treesitter.grammars.python;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Python grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_python() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_python();
        if (!grammar) {
            Logger.debugLog("Python grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("python");
        if (!config) {
            Logger.warning("Python config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "python",
            &ts_load_python,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Python tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Python grammar not loaded: " ~ e.msg);
    }
}

/// Check if Python grammar is available
bool isPythonGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
