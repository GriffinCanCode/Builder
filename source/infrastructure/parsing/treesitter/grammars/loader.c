/*
 * Dynamic Tree-sitter Grammar Loader
 * Loads grammars from system libraries at runtime
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

typedef struct TSLanguage TSLanguage;
typedef const TSLanguage *(*grammar_func_t)(void);

// Grammar loader cache
static void *grammar_handles[32] = {0};
static int num_handles = 0;

// Try to load a grammar from various locations
const TSLanguage *load_grammar(const char *lang_name) {
    char lib_paths[4][256];
    const char *symbol_name;
    char symbol_buf[128];
    void *handle = NULL;
    grammar_func_t func;
    
    // Build symbol name
    snprintf(symbol_buf, sizeof(symbol_buf), "tree_sitter_%s", lang_name);
    symbol_name = symbol_buf;
    
    // Special case for C# and F#
    if (strcmp(lang_name, "csharp") == 0) {
        symbol_name = "tree_sitter_c_sharp";
    } else if (strcmp(lang_name, "fsharp") == 0) {
        symbol_name = "tree_sitter_f_sharp";
    }
    
    // Try various library locations
#ifdef __APPLE__
    // macOS - Homebrew locations
    snprintf(lib_paths[0], sizeof(lib_paths[0]), 
             "/opt/homebrew/lib/libtree-sitter-%s.dylib", lang_name);
    snprintf(lib_paths[1], sizeof(lib_paths[1]), 
             "/usr/local/lib/libtree-sitter-%s.dylib", lang_name);
    snprintf(lib_paths[2], sizeof(lib_paths[2]), 
             "libtree-sitter-%s.dylib", lang_name);
    snprintf(lib_paths[3], sizeof(lib_paths[3]), 
             "libtree-sitter-%s.0.dylib", lang_name);
#else
    // Linux - standard locations
    snprintf(lib_paths[0], sizeof(lib_paths[0]), 
             "/usr/lib/libtree-sitter-%s.so", lang_name);
    snprintf(lib_paths[1], sizeof(lib_paths[1]), 
             "/usr/local/lib/libtree-sitter-%s.so", lang_name);
    snprintf(lib_paths[2], sizeof(lib_paths[2]), 
             "libtree-sitter-%s.so", lang_name);
    snprintf(lib_paths[3], sizeof(lib_paths[3]), 
             "/usr/lib/x86_64-linux-gnu/libtree-sitter-%s.so", lang_name);
#endif
    
    // Try each path
    for (int i = 0; i < 4; i++) {
        handle = dlopen(lib_paths[i], RTLD_LAZY | RTLD_LOCAL);
        if (handle) {
            break;
        }
    }
    
    // Also try loading from built grammars
    if (!handle) {
        // Try loading from our built library
        // This will be linked statically if available
        return NULL;
    }
    
    // Get the grammar function
    func = (grammar_func_t)dlsym(handle, symbol_name);
    if (!func) {
        dlclose(handle);
        return NULL;
    }
    
    // Cache the handle for cleanup
    if (num_handles < 32) {
        grammar_handles[num_handles++] = handle;
    }
    
    // Call the function to get the grammar
    return func();
}

// Cleanup function (called at exit)
void cleanup_grammars(void) {
    for (int i = 0; i < num_handles; i++) {
        if (grammar_handles[i]) {
            dlclose(grammar_handles[i]);
            grammar_handles[i] = NULL;
        }
    }
    num_handles = 0;
}

// Register cleanup at exit
__attribute__((constructor))
static void init_loader(void) {
    atexit(cleanup_grammars);
}

// Export wrapper functions for each language
#define DEFINE_GRAMMAR_LOADER(lang) \
    const TSLanguage *ts_load_##lang(void) { \
        return load_grammar(#lang); \
    }

DEFINE_GRAMMAR_LOADER(c)
DEFINE_GRAMMAR_LOADER(cpp)
DEFINE_GRAMMAR_LOADER(python)
DEFINE_GRAMMAR_LOADER(java)
DEFINE_GRAMMAR_LOADER(javascript)
DEFINE_GRAMMAR_LOADER(typescript)
DEFINE_GRAMMAR_LOADER(go)
DEFINE_GRAMMAR_LOADER(rust)
DEFINE_GRAMMAR_LOADER(csharp)
DEFINE_GRAMMAR_LOADER(ruby)
DEFINE_GRAMMAR_LOADER(php)
DEFINE_GRAMMAR_LOADER(swift)
DEFINE_GRAMMAR_LOADER(kotlin)
DEFINE_GRAMMAR_LOADER(scala)
DEFINE_GRAMMAR_LOADER(elixir)
DEFINE_GRAMMAR_LOADER(lua)
DEFINE_GRAMMAR_LOADER(perl)
DEFINE_GRAMMAR_LOADER(r)
DEFINE_GRAMMAR_LOADER(haskell)
DEFINE_GRAMMAR_LOADER(ocaml)
DEFINE_GRAMMAR_LOADER(nim)
DEFINE_GRAMMAR_LOADER(zig)
DEFINE_GRAMMAR_LOADER(d)
DEFINE_GRAMMAR_LOADER(elm)
DEFINE_GRAMMAR_LOADER(fsharp)
DEFINE_GRAMMAR_LOADER(css)
DEFINE_GRAMMAR_LOADER(protobuf)

