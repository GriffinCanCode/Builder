#!/usr/bin/env bash
# Tree-sitter Setup Script for Builder
# Sets up tree-sitter dependencies for the build system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "================================="
echo "Builder Tree-sitter Setup"
echo "================================="
echo ""

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macOS"
    PKG_MANAGER="brew"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="Linux"
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    else
        PKG_MANAGER="unknown"
    fi
else
    PLATFORM="unknown"
    PKG_MANAGER="unknown"
fi

echo "Platform: $PLATFORM"
echo "Package Manager: $PKG_MANAGER"
echo ""

# Check if tree-sitter is installed
check_treesitter() {
    if pkg-config --exists tree-sitter 2>/dev/null; then
        echo "✓ tree-sitter found via pkg-config"
        VERSION=$(pkg-config --modversion tree-sitter 2>/dev/null || echo "unknown")
        echo "  Version: $VERSION"
        return 0
    elif [[ -f "/opt/homebrew/lib/libtree-sitter.dylib" ]]; then
        echo "✓ tree-sitter found at /opt/homebrew/lib"
        return 0
    elif [[ -f "/usr/local/lib/libtree-sitter.dylib" ]] || [[ -f "/usr/local/lib/libtree-sitter.a" ]]; then
        echo "✓ tree-sitter found at /usr/local/lib"
        return 0
    elif [[ -f "/usr/lib/libtree-sitter.so" ]]; then
        echo "✓ tree-sitter found at /usr/lib"
        return 0
    else
        return 1
    fi
}

# Install tree-sitter
install_treesitter() {
    echo "Installing tree-sitter..."
    echo ""
    
    case $PKG_MANAGER in
        brew)
            echo "Running: brew install tree-sitter"
            brew install tree-sitter
            ;;
        apt)
            echo "Running: sudo apt-get update && sudo apt-get install -y libtree-sitter-dev"
            sudo apt-get update
            sudo apt-get install -y libtree-sitter-dev
            ;;
        yum)
            echo "Running: sudo yum install -y tree-sitter"
            sudo yum install -y tree-sitter
            ;;
        *)
            echo "❌ Unknown package manager. Please install tree-sitter manually:"
            echo ""
            echo "From source:"
            echo "  git clone https://github.com/tree-sitter/tree-sitter"
            echo "  cd tree-sitter"
            echo "  make"
            echo "  sudo make install"
            echo ""
            exit 1
            ;;
    esac
}

# Build grammar stubs
build_grammars() {
    echo ""
    echo "Building grammar stubs..."
    cd "$SCRIPT_DIR/grammars"
    make clean
    make
    cd "$PROJECT_ROOT"
}

# Main setup flow
main() {
    echo "Step 1: Checking tree-sitter installation"
    echo "==========================================="
    
    if check_treesitter; then
        echo ""
        echo "Tree-sitter is already installed."
        echo ""
    else
        echo ""
        echo "❌ tree-sitter not found"
        echo ""
        read -p "Would you like to install it now? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_treesitter
            echo ""
            echo "✓ tree-sitter installed successfully"
        else
            echo "Skipping installation. Note: Builder will fall back to file-level tracking."
            echo ""
        fi
    fi
    
    echo ""
    echo "Step 2: Building grammar loaders"
    echo "==========================================="
    build_grammars
    
    echo ""
    echo "Step 3: Verifying setup"
    echo "==========================================="
    
    # Check for stub library
    if [[ -f "$PROJECT_ROOT/bin/obj/treesitter/libts_grammars.a" ]]; then
        echo "✓ Grammar library built"
    else
        echo "⚠️  Grammar library not found (expected at bin/obj/treesitter/libts_grammars.a)"
    fi
    
    # Verify dub configuration
    if grep -q "tree-sitter" "$PROJECT_ROOT/dub.json"; then
        echo "✓ dub.json configured for tree-sitter"
    else
        echo "⚠️  dub.json may need tree-sitter configuration"
    fi
    
    echo ""
    echo "================================="
    echo "Setup Complete!"
    echo "================================="
    echo ""
    echo "Next steps:"
    echo "  1. Build the project: dub build"
    echo "  2. Run the builder: ./bin/builder"
    echo ""
    echo "Note: Currently using stub implementation (no actual parsing)."
    echo "To enable full parsing, add language grammars in grammars/ directory."
    echo "See: grammars/README.md for instructions."
    echo ""
}

# Handle command-line arguments
case "${1:-}" in
    --check)
        check_treesitter
        exit $?
        ;;
    --install)
        install_treesitter
        exit $?
        ;;
    --build)
        build_grammars
        exit $?
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  (none)      Run full setup (check, install if needed, build)"
        echo "  --check     Check if tree-sitter is installed"
        echo "  --install   Install tree-sitter only"
        echo "  --build     Build grammar loaders only"
        echo "  --help      Show this help message"
        echo ""
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Run with --help for usage information"
        exit 1
        ;;
esac

