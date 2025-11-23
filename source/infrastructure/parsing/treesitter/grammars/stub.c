/*
 * Tree-sitter Grammar Stub
 * 
 * This is a stub implementation that demonstrates the grammar loader interface.
 * Actual grammars would be compiled from tree-sitter grammar repositories.
 * 
 * To add real grammars:
 * 1. Clone grammar repo: git clone https://github.com/tree-sitter/tree-sitter-<lang>
 * 2. Build grammar: cd tree-sitter-<lang> && npm install && npm run build
 * 3. Link against: tree-sitter-<lang>/src/parser.c
 * 
 * See: https://tree-sitter.github.io/tree-sitter/creating-parsers
 */

#include <stddef.h>

/* 
 * Stub function - does nothing but provides symbol for linking
 * 
 * In a real implementation, this would return actual TSLanguage* pointers
 * from grammar libraries like tree-sitter-python, tree-sitter-java, etc.
 */
void* ts_grammar_stub_init(void) {
    return NULL;
}

/*
 * Future: Add grammar loaders here
 * 
 * Example for Python:
 * 
 * extern const TSLanguage *tree_sitter_python(void);
 * 
 * const TSLanguage* ts_get_python_grammar(void) {
 *     return tree_sitter_python();
 * }
 */

