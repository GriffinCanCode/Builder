module infrastructure.parsing.treesitter.grammars.ocaml;

import infrastructure.parsing.treesitter.bindings;
import infrastructure.parsing.treesitter.config;
import infrastructure.parsing.treesitter.registry;
import infrastructure.parsing.treesitter.parser;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.logging.logger;

/// Ocaml grammar loader for tree-sitter
/// Dynamically loads grammar from system libraries if available

// Dynamic loader from C
extern(C) const(TSLanguage)* ts_load_ocaml() @system nothrow @nogc;

private bool grammarLoaded = false;

shared static this() @system {
    try {
        // Try to load grammar dynamically
        auto grammar = ts_load_ocaml();
        if (!grammar) {
            Logger.debugLog("Ocaml grammar not available (will use file-level tracking)");
            return;
        }
        
        auto config = LanguageConfigs.get("ocaml");
        if (!config) {
            Logger.warning("Ocaml config not found");
            return;
        }
        
        // Register with tree-sitter registry
        TreeSitterRegistry.instance().registerGrammar(
            "ocaml",
            &ts_load_ocaml,
            *config
        );
        
        // Create and register parser
        auto parser = new TreeSitterParser(grammar, *config);
        ASTParserRegistry.instance().registerParser(parser);
        
        grammarLoaded = true;
        Logger.info("✓ Ocaml tree-sitter grammar loaded");
    } catch (Exception e) {
        Logger.debugLog("Ocaml grammar not loaded: " ~ e.msg);
    }
}

/// Check if Ocaml grammar is available
bool isOcamlGrammarAvailable() @safe nothrow {
    return grammarLoaded;
}
