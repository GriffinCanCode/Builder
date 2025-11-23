# Tree-sitter Grammar Loader Makefile
# Builds grammar loaders for tree-sitter language support

CC = gcc
CFLAGS = -O3 -Wall -Wextra -std=c11 -fPIC -DNDEBUG
AR = ar
ARFLAGS = rcs

# Detect platform
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Output directory (relative to project root)
# Makefile is in: source/infrastructure/parsing/treesitter/grammars/
# Go up 5 levels to reach project root: grammars -> treesitter -> parsing -> infrastructure -> source -> Builder
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT := $(abspath $(MAKEFILE_DIR)../../../../..)
OUT_DIR := $(PROJECT_ROOT)/bin/obj/treesitter

# Check for tree-sitter library
TS_CFLAGS = $(shell pkg-config --cflags tree-sitter 2>/dev/null || echo "-I/usr/local/include")
TS_LIBS = $(shell pkg-config --libs tree-sitter 2>/dev/null || echo "-ltree-sitter")

# Platform-specific settings
ifeq ($(UNAME_S),Darwin)
    # macOS - check homebrew (Apple Silicon uses /opt/homebrew, Intel uses /usr/local)
    BREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo "/usr/local")
    TS_CFLAGS += -I$(BREW_PREFIX)/include
    TS_LIBS += -L$(BREW_PREFIX)/lib -Wl,-rpath,$(BREW_PREFIX)/lib
    
    # Also check standard location
    ifneq ($(wildcard /opt/homebrew/include/tree_sitter/api.h),)
        TS_CFLAGS += -I/opt/homebrew/include
        TS_LIBS += -L/opt/homebrew/lib -Wl,-rpath,/opt/homebrew/lib
    endif
    ifneq ($(wildcard /usr/local/include/tree_sitter/api.h),)
        TS_CFLAGS += -I/usr/local/include
        TS_LIBS += -L/usr/local/lib -Wl,-rpath,/usr/local/lib
    endif
else ifeq ($(UNAME_S),Linux)
    # Linux - check common locations
    TS_LIBS += -Wl,-rpath,/usr/local/lib -Wl,-rpath,/usr/lib
endif

# Grammar languages (for future full grammar build)
GRAMMARS = c cpp python java javascript typescript go rust csharp ruby php \
           swift kotlin scala elixir lua perl r haskell ocaml nim zig d \
           elm fsharp css protobuf

# Stub object (simple implementation for now)
STUB_OBJ = $(OUT_DIR)/stub.o

# Grammar library
GRAMMAR_LIB = $(OUT_DIR)/libts_grammars.a

.PHONY: all clean setup check-deps install-deps build-grammars stub

# Default: build stub version (fast, no external deps beyond tree-sitter core)
all: stub

# Stub version - provides interface without real parsing
stub: setup check-deps $(GRAMMAR_LIB)

# Full grammar build (requires cloning and building grammar repos)
build-grammars: setup check-deps
	@echo "Building tree-sitter grammars from source..."
	@echo "This will clone and build grammar repositories (may take a while)..."
	@bash build-grammars.sh

setup:
	@mkdir -p $(OUT_DIR)

check-deps:
	@echo "Checking for tree-sitter library..."
	@if pkg-config --exists tree-sitter 2>/dev/null; then \
		echo "✓ tree-sitter library found via pkg-config"; \
		echo "  Version: $$(pkg-config --modversion tree-sitter 2>/dev/null || echo 'unknown')"; \
		echo "  CFLAGS: $(TS_CFLAGS)"; \
		echo "  LIBS: $(TS_LIBS)"; \
	elif [ -f "$(BREW_PREFIX)/lib/libtree-sitter.dylib" ] || [ -f "$(BREW_PREFIX)/lib/libtree-sitter.a" ]; then \
		echo "✓ tree-sitter library found via Homebrew at $(BREW_PREFIX)"; \
	elif [ -f "/opt/homebrew/lib/libtree-sitter.dylib" ]; then \
		echo "✓ tree-sitter library found at /opt/homebrew/lib"; \
	elif [ -f "/usr/local/lib/libtree-sitter.dylib" ] || [ -f "/usr/local/lib/libtree-sitter.a" ]; then \
		echo "✓ tree-sitter library found at /usr/local/lib"; \
	elif [ -f "/usr/lib/libtree-sitter.so" ]; then \
		echo "✓ tree-sitter library found at /usr/lib"; \
	else \
		echo ""; \
		echo "⚠️  tree-sitter library not found!"; \
		echo ""; \
		echo "Install via:"; \
		echo "  macOS:  brew install tree-sitter"; \
		echo "  Linux:  sudo apt-get install libtree-sitter-dev"; \
		echo "  Or build from source: https://github.com/tree-sitter/tree-sitter"; \
		echo ""; \
		echo "For now, building stub version (no parsing, fallback to file-level tracking)"; \
		echo ""; \
	fi

# Stub loader (no actual grammars, just demonstrates the interface)
$(OUT_DIR)/stub.o: stub.c
	@mkdir -p $(OUT_DIR)
	$(CC) $(CFLAGS) $(TS_CFLAGS) -c $< -o $@

# Create grammar library (stub version)
$(GRAMMAR_LIB): $(STUB_OBJ)
	$(AR) $(ARFLAGS) $@ $^
	@echo "✓ Built tree-sitter grammar library (stub)"

# Clean
clean:
	rm -rf $(OUT_DIR) build vendor
	@echo "✓ Cleaned build artifacts"

# Install tree-sitter dependencies (helper target)
install-deps:
	@echo "Installing tree-sitter dependencies..."
	@if command -v brew >/dev/null 2>&1; then \
		echo "Using Homebrew..."; \
		brew install tree-sitter; \
	elif command -v apt-get >/dev/null 2>&1; then \
		echo "Using apt..."; \
		sudo apt-get update && sudo apt-get install -y libtree-sitter-dev; \
	else \
		echo "Please install tree-sitter manually from: https://github.com/tree-sitter/tree-sitter"; \
	fi

# Help target
help:
	@echo "Tree-sitter Grammar Loader Build System"
	@echo "========================================"
	@echo ""
	@echo "Targets:"
	@echo "  all (default)    - Build stub grammar library (fast, no real parsing)"
	@echo "  stub             - Same as 'all'"
	@echo "  build-grammars   - Build full grammar libraries from source (slow)"
	@echo "  check-deps       - Check if tree-sitter library is installed"
	@echo "  install-deps     - Install tree-sitter via package manager"
	@echo "  clean            - Remove build artifacts"
	@echo "  help             - Show this help message"
	@echo ""
	@echo "Quick Setup:"
	@echo "  1. Install tree-sitter:    make install-deps"
	@echo "  2. Build stub library:     make"
	@echo "  3. Build main project:     cd ../../../.. && dub build"
	@echo ""
	@echo "Or use the automated setup script:"
	@echo "  cd .. && ./setup.sh"
	@echo ""
	@echo "Configuration:"
	@echo "  Project root: $(PROJECT_ROOT)"
	@echo "  Output dir:   $(OUT_DIR)"
	@echo "  Platform:     $(UNAME_S) $(UNAME_M)"
	@echo ""
	@echo "Supported Grammars (for full build): $(words $(GRAMMARS))"
	@echo "  $(GRAMMARS)"
	@echo ""
	@echo "Notes:"
	@echo "  - Default builds stub version (no real parsing, fast)"
	@echo "  - Falls back to file-level incremental compilation"
	@echo "  - For full AST parsing, use 'make build-grammars'"
	@echo "  - See README.md for detailed documentation"
	@echo ""
	@echo "Notes:"
	@echo "  - Requires tree-sitter C library installed"
	@echo "  - Automatically downloads grammar sources"
	@echo "  - Or uses system-installed grammars if available"

