#!/usr/bin/env bash
# Automated Tree-sitter Grammar Build System
# Downloads and builds all configured tree-sitter grammars

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAMMARS_DIR="$SCRIPT_DIR/vendor"
BUILD_DIR="$SCRIPT_DIR/build"
OUT_DIR="$SCRIPT_DIR/../../../../../bin/obj/treesitter"

# Create directories
mkdir -p "$GRAMMARS_DIR" "$BUILD_DIR" "$OUT_DIR"

# Grammar repositories
declare -A GRAMMARS=(
    ["c"]="https://github.com/tree-sitter/tree-sitter-c"
    ["cpp"]="https://github.com/tree-sitter/tree-sitter-cpp"
    ["python"]="https://github.com/tree-sitter/tree-sitter-python"
    ["java"]="https://github.com/tree-sitter/tree-sitter-java"
    ["javascript"]="https://github.com/tree-sitter/tree-sitter-javascript"
    ["typescript"]="https://github.com/tree-sitter/tree-sitter-typescript"
    ["go"]="https://github.com/tree-sitter/tree-sitter-go"
    ["rust"]="https://github.com/tree-sitter/tree-sitter-rust"
    ["csharp"]="https://github.com/tree-sitter/tree-sitter-c-sharp"
    ["ruby"]="https://github.com/tree-sitter/tree-sitter-ruby"
    ["php"]="https://github.com/tree-sitter/tree-sitter-php"
    ["swift"]="https://github.com/tree-sitter/tree-sitter-swift"
    ["kotlin"]="https://github.com/fwcd/tree-sitter-kotlin"
    ["scala"]="https://github.com/tree-sitter/tree-sitter-scala"
    ["elixir"]="https://github.com/elixir-lang/tree-sitter-elixir"
    ["lua"]="https://github.com/tree-sitter-grammars/tree-sitter-lua"
    ["perl"]="https://github.com/tree-sitter-perl/tree-sitter-perl"
    ["r"]="https://github.com/r-lib/tree-sitter-r"
    ["haskell"]="https://github.com/tree-sitter/tree-sitter-haskell"
    ["ocaml"]="https://github.com/tree-sitter/tree-sitter-ocaml"
    ["nim"]="https://github.com/alaviss/tree-sitter-nim"
    ["zig"]="https://github.com/maxxnino/tree-sitter-zig"
    ["d"]="https://github.com/gdamore/tree-sitter-d"
    ["elm"]="https://github.com/elm-tooling/tree-sitter-elm"
    ["fsharp"]="https://github.com/Nsidorenco/tree-sitter-fsharp"
    ["css"]="https://github.com/tree-sitter/tree-sitter-css"
    ["protobuf"]="https://github.com/yusdacra/tree-sitter-protobuf"
)

# Compiler settings
CC="${CC:-gcc}"
CFLAGS="-O3 -Wall -Wextra -std=c11 -fPIC -DNDEBUG"

# Detect platform
UNAME_S="$(uname -s)"
if [[ "$UNAME_S" == "Darwin" ]]; then
    BREW_PREFIX="$(brew --prefix 2>/dev/null || echo "/usr/local")"
    CFLAGS="$CFLAGS -I$BREW_PREFIX/include"
    DYLIB_EXT="dylib"
else
    DYLIB_EXT="so"
fi

echo "================================="
echo "Tree-sitter Grammar Build System"
echo "================================="
echo ""
echo "Building ${#GRAMMARS[@]} grammars"
echo "Output: $OUT_DIR"
echo ""

# Function to clone or update a grammar
clone_grammar() {
    local name="$1"
    local url="$2"
    local dir="$GRAMMARS_DIR/$name"
    
    if [[ -d "$dir" ]]; then
        echo "  Updating $name..."
        (cd "$dir" && git pull -q)
    else
        echo "  Cloning $name..."
        git clone -q --depth 1 "$url" "$dir"
    fi
}

# Function to build a grammar
build_grammar() {
    local name="$1"
    local src_dir="$GRAMMARS_DIR/$name"
    
    echo "  Building $name..."
    
    # Handle typescript special case (has multiple grammars)
    if [[ "$name" == "typescript" ]]; then
        # Build TypeScript
        $CC $CFLAGS -c "$src_dir/typescript/src/parser.c" \
            -o "$BUILD_DIR/tree_sitter_typescript.o"
        $CC $CFLAGS -c "$src_dir/typescript/src/scanner.c" \
            -o "$BUILD_DIR/tree_sitter_typescript_scanner.o" 2>/dev/null || true
        
        # Build TSX
        $CC $CFLAGS -c "$src_dir/tsx/src/parser.c" \
            -o "$BUILD_DIR/tree_sitter_tsx.o"
        $CC $CFLAGS -c "$src_dir/tsx/src/scanner.c" \
            -o "$BUILD_DIR/tree_sitter_tsx_scanner.o" 2>/dev/null || true
        return
    fi
    
    # Standard build
    local parser_c="$src_dir/src/parser.c"
    local scanner_c="$src_dir/src/scanner.c"
    local scanner_cc="$src_dir/src/scanner.cc"
    
    if [[ ! -f "$parser_c" ]]; then
        echo "    ⚠️  No parser.c found, skipping"
        return 1
    fi
    
    # Build parser
    $CC $CFLAGS -c "$parser_c" -o "$BUILD_DIR/tree_sitter_${name}.o"
    
    # Build scanner if exists
    if [[ -f "$scanner_c" ]]; then
        $CC $CFLAGS -c "$scanner_c" -o "$BUILD_DIR/tree_sitter_${name}_scanner.o" 2>/dev/null || true
    elif [[ -f "$scanner_cc" ]]; then
        g++ $CFLAGS -c "$scanner_cc" -o "$BUILD_DIR/tree_sitter_${name}_scanner.o" 2>/dev/null || true
    fi
}

# Function to check if a grammar is already available via system
check_system_grammar() {
    local name="$1"
    
    # Check Homebrew
    if [[ "$UNAME_S" == "Darwin" ]]; then
        if [[ -f "$BREW_PREFIX/lib/libtree-sitter-$name.$DYLIB_EXT" ]]; then
            echo "    ✓ Using system grammar from Homebrew"
            return 0
        fi
    fi
    
    # Check pkg-config
    if pkg-config --exists "tree-sitter-$name" 2>/dev/null; then
        echo "    ✓ Using system grammar via pkg-config"
        return 0
    fi
    
    return 1
}

# Main build loop
failed=0
built=0
skipped=0

for name in "${!GRAMMARS[@]}"; do
    echo ""
    echo "[$((built + failed + skipped + 1))/${#GRAMMARS[@]}] $name"
    echo "----------------------------------------"
    
    # Check if system grammar exists
    if check_system_grammar "$name"; then
        ((skipped++))
        continue
    fi
    
    # Clone/update
    if ! clone_grammar "$name" "${GRAMMARS[$name]}"; then
        echo "    ❌ Failed to clone"
        ((failed++))
        continue
    fi
    
    # Build
    if build_grammar "$name"; then
        echo "    ✓ Built successfully"
        ((built++))
    else
        echo "    ❌ Build failed"
        ((failed++))
    fi
done

# Create grammar library archive
echo ""
echo "================================="
echo "Creating Grammar Library"
echo "================================="

# Collect all object files
OBJECTS=$(find "$BUILD_DIR" -name "*.o" 2>/dev/null || true)

if [[ -n "$OBJECTS" ]]; then
    ar rcs "$OUT_DIR/libts_grammars.a" $OBJECTS
    echo "✓ Created $OUT_DIR/libts_grammars.a"
else
    echo "⚠️  No object files found to archive"
fi

# Summary
echo ""
echo "================================="
echo "Build Summary"
echo "================================="
echo "Built:   $built grammars"
echo "System:  $skipped grammars"
echo "Failed:  $failed grammars"
echo "Total:   ${#GRAMMARS[@]} grammars"
echo ""

if [[ $built -gt 0 ]] || [[ $skipped -gt 0 ]]; then
    echo "✓ Grammar build complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Run: make"
    echo "  2. Run: dub build"
    echo "  3. Grammars will be automatically loaded"
else
    echo "⚠️  No grammars available"
    echo ""
    echo "To install system grammars:"
    echo "  macOS:  brew install tree-sitter"
    echo "  Linux:  sudo apt-get install tree-sitter-grammars"
fi

exit 0

