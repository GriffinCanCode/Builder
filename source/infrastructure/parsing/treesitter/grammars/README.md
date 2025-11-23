# Tree-sitter Grammar Loaders

This directory contains the C interface for loading tree-sitter language grammars.

## Current Status

**Phase 2 - In Progress**

Currently provides a stub implementation. Full grammar integration requires:

1. Tree-sitter C library installed
2. Individual language grammar libraries compiled
3. Grammar loader functions implemented

## Installation

### Prerequisites

**Option 1: Homebrew (macOS - Recommended)**

```bash
# Install tree-sitter core library
brew install tree-sitter

# Verify installation
brew list tree-sitter
pkg-config --modversion tree-sitter
```

This installs tree-sitter to:
- **Apple Silicon**: `/opt/homebrew/lib/libtree-sitter.dylib`
- **Intel Mac**: `/usr/local/lib/libtree-sitter.dylib`

The build system (`dub.json`) is already configured to search both locations.

**Option 2: System Package Manager (Linux)**

```bash
# Ubuntu/Debian
sudo apt-get install libtree-sitter-dev

# Fedora/RHEL
sudo yum install tree-sitter-devel

# Verify installation
pkg-config --modversion tree-sitter
```

**Option 3: From Source**

```bash
git clone https://github.com/tree-sitter/tree-sitter
cd tree-sitter
make
sudo make install
```

### Automated Setup

Use the provided setup script:

```bash
cd source/infrastructure/parsing/treesitter
./setup.sh
```

This will:
1. Check for tree-sitter installation
2. Offer to install via package manager if not found
3. Build the grammar stub library
4. Verify the configuration

### Manual Building

```bash
cd source/infrastructure/parsing/treesitter/grammars
make
```

This creates `bin/obj/treesitter/libts_grammars.a`.

**Verifying the Build:**

```bash
# Check if tree-sitter is found
make check-deps

# Should output:
# ✓ tree-sitter library found via pkg-config
# or
# ✓ tree-sitter library found via Homebrew at /opt/homebrew
```

## Adding a Language Grammar

### Method 1: Using Pre-built Grammars (Recommended)

Most languages have pre-built grammars available:

```bash
# Example: Adding Python support
cd source/infrastructure/parsing/treesitter/grammars

# Clone the grammar
git clone https://github.com/tree-sitter/tree-sitter-python

# Build it
cd tree-sitter-python
npm install  # Installs tree-sitter-cli
npm run build  # Generates parser.c

# Copy artifacts
cp src/parser.c ../python_parser.c
cp src/tree_sitter/parser.h ../
```

### Method 2: Using System Grammars

If grammars are installed system-wide (e.g., via package manager):

```bash
# Ubuntu: Install tree-sitter grammars
sudo apt-get install tree-sitter-grammars

# Then link against them in Makefile
```

### Method 3: Dynamic Loading

Load grammars at runtime:

```d
// In D code
extern(C) void* dlopen(const char* filename, int flags);
extern(C) void* dlsym(void* handle, const char* symbol);

auto lib = dlopen("libtree-sitter-python.so", RTLD_LAZY);
auto grammarFunc = cast(TSLanguage* function())dlsym(lib, "tree_sitter_python");
auto grammar = grammarFunc();
```

## Implementation Guide

### 1. Add Grammar Source

Create `<lang>_parser.c`:

```c
// python_loader.c
#include "parser.h"

// Link against tree-sitter-python library
extern const TSLanguage *tree_sitter_python(void);

const TSLanguage* ts_get_python_grammar(void) {
    return tree_sitter_python();
}
```

### 2. Update Makefile

```makefile
# Add to GRAMMARS list
GRAMMARS = stub python java

# Add grammar-specific rules
$(OUT_DIR)/python.o: python_loader.c
	$(CC) $(CFLAGS) $(TS_CFLAGS) -c $< -o $@
```

### 3. Declare in D Bindings

Update `source/infrastructure/parsing/treesitter/bindings.d`:

```d
// Declare grammar loader
extern(C) const(TSLanguage)* ts_get_python_grammar() @system nothrow @nogc;
```

### 4. Register Grammar

Update `source/infrastructure/parsing/treesitter/registry.d`:

```d
static this() {
    auto config = LanguageConfigs.get("python");
    if (config) {
        TreeSitterRegistry.instance().registerGrammar(
            "python",
            &ts_get_python_grammar,
            *config
        );
    }
}
```

## Available Grammars

Tree-sitter has grammars for 100+ languages. Commonly used ones:

### Tier 1 (Recommended)
- **Python**: https://github.com/tree-sitter/tree-sitter-python
- **Java**: https://github.com/tree-sitter/tree-sitter-java
- **JavaScript/TypeScript**: https://github.com/tree-sitter/tree-sitter-javascript
- **C/C++**: https://github.com/tree-sitter/tree-sitter-cpp
- **Go**: https://github.com/tree-sitter/tree-sitter-go
- **Rust**: https://github.com/tree-sitter/tree-sitter-rust

### Tier 2
- **C#**: https://github.com/tree-sitter/tree-sitter-c-sharp
- **Ruby**: https://github.com/tree-sitter/tree-sitter-ruby
- **PHP**: https://github.com/tree-sitter/tree-sitter-php
- **Swift**: https://github.com/tree-sitter/tree-sitter-swift
- **Kotlin**: https://github.com/fwcd/tree-sitter-kotlin
- **Scala**: https://github.com/tree-sitter/tree-sitter-scala

### Tier 3
- **Haskell**: https://github.com/tree-sitter/tree-sitter-haskell
- **OCaml**: https://github.com/tree-sitter/tree-sitter-ocaml
- **Elixir**: https://github.com/elixir-lang/tree-sitter-elixir
- **Lua**: https://github.com/Azganoth/tree-sitter-lua
- **Zig**: https://github.com/maxxnino/tree-sitter-zig

## Dynamic Grammar Loading (Future)

For easier deployment, grammars can be loaded dynamically:

### Approach 1: dlopen()

```d
class DynamicGrammarLoader {
    TSLanguage* loadGrammar(string languageId) {
        // Load from: /usr/local/lib/libtree-sitter-<lang>.so
        auto libPath = "/usr/local/lib/libtree-sitter-" ~ languageId ~ ".so";
        auto lib = dlopen(libPath.toStringz, RTLD_LAZY);
        if (!lib) return null;
        
        auto func = cast(TSLanguage* function())
            dlsym(lib, ("tree_sitter_" ~ languageId).toStringz);
        
        return func ? func() : null;
    }
}
```

### Approach 2: Plugin System

```d
// Grammar as plugin
interface IGrammarPlugin {
    TSLanguage* getGrammar();
    string[] supportedExtensions();
}

// Load from: ~/.builder/grammars/<lang>.so
```

## Testing

Test grammar loading:

```d
unittest {
    auto registry = TreeSitterRegistry.instance();
    
    // Check if Python grammar is available
    auto parser = registry.createParser("python");
    if (parser.isOk) {
        writeln("✓ Python grammar loaded successfully");
    } else {
        writeln("⚠ Python grammar not available");
    }
}
```

## Performance Notes

- Grammar loading is lazy (only when first needed)
- Grammars are singletons (loaded once, reused)
- Typical grammar size: 1-5 MB
- Parse speed: 500-1000 LOC/ms

## Troubleshooting

### "Symbol not found: _tree_sitter_python"

Grammar library not linked. Either:
1. Add to Makefile and rebuild
2. Install system grammar package
3. Use dynamic loading

### "libtree-sitter.so not found"

Tree-sitter C library not installed:
```bash
make install-deps
```

### Segfault in parser

1. Check grammar ABI compatibility (use same tree-sitter version)
2. Verify grammar was compiled correctly
3. Check for null grammar pointer

## See Also

- [Tree-sitter Documentation](https://tree-sitter.github.io/tree-sitter/)
- [Grammar Development Guide](https://tree-sitter.github.io/tree-sitter/creating-parsers)
- [Available Grammars](https://github.com/tree-sitter)

