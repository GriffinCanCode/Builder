#!/usr/bin/env bash

# Real-world build test runner
# Tests builder against actual example projects to catch regressions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLES_DIR="$PROJECT_ROOT/examples"
BUILDER_BIN="$PROJECT_ROOT/bin/builder"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Check if builder is built
if [ ! -f "$BUILDER_BIN" ]; then
    echo -e "${RED}Error: builder executable not found at $BUILDER_BIN${NC}"
    echo "Build it first with: make"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          BUILDER REAL-WORLD BUILD TEST SUITE                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Builder: $BUILDER_BIN"
echo "Examples: $EXAMPLES_DIR"
echo ""

# Function to test a project
test_project() {
    local project_name=$1
    local project_path=$2
    
    if [ ! -d "$project_path" ]; then
        echo -e "  ${YELLOW}⊘ SKIP${NC} $project_name (not found)"
        SKIPPED=$((SKIPPED + 1))
        return
    fi
    
    # Check if Builderfile exists
    if [ ! -f "$project_path/Builderfile" ] && [ ! -f "$project_path/Builderspace" ]; then
        echo -e "  ${YELLOW}⊘ SKIP${NC} $project_name (no Builderfile)"
        SKIPPED=$((SKIPPED + 1))
        return
    fi
    
    # Clean previous builds
    rm -rf "$project_path/bin" 2>/dev/null || true
    
    # Run build
    local start_time=$(date +%s%N)
    
    if (cd "$project_path" && "$BUILDER_BIN" build > /tmp/builder-test-$$.log 2>&1); then
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))
        
        echo -e "  ${GREEN}✓ PASS${NC} $project_name (${duration}ms)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC} $project_name"
        echo "    See: /tmp/builder-test-$$.log"
        FAILED=$((FAILED + 1))
    fi
}

# Test all example projects
echo -e "${BLUE}[TEST]${NC} Testing example projects..."
echo ""

# Compiled languages
test_project "simple" "$EXAMPLES_DIR/simple"
test_project "python-multi" "$EXAMPLES_DIR/python-multi"
test_project "go-project" "$EXAMPLES_DIR/go-project"
test_project "rust-project" "$EXAMPLES_DIR/rust-project"
test_project "cpp-project" "$EXAMPLES_DIR/cpp-project"
test_project "java-project" "$EXAMPLES_DIR/java-project"
test_project "d-project" "$EXAMPLES_DIR/d-project"

# Scripting languages
test_project "lua-project" "$EXAMPLES_DIR/lua-project"
test_project "ruby-project" "$EXAMPLES_DIR/ruby-project"
test_project "php-project" "$EXAMPLES_DIR/php-project"
test_project "r-project" "$EXAMPLES_DIR/r-project"
test_project "nim-project" "$EXAMPLES_DIR/nim-project"
test_project "zig-project" "$EXAMPLES_DIR/zig-project"

# Web projects
test_project "typescript-app" "$EXAMPLES_DIR/typescript-app"
test_project "javascript-basic" "$EXAMPLES_DIR/javascript/javascript-basic"
test_project "javascript-node" "$EXAMPLES_DIR/javascript/javascript-node"
test_project "javascript-browser" "$EXAMPLES_DIR/javascript/javascript-browser"
test_project "javascript-library" "$EXAMPLES_DIR/javascript/javascript-library"
test_project "elm-project" "$EXAMPLES_DIR/elm-project"

# Complex projects
test_project "mixed-lang" "$EXAMPLES_DIR/mixed-lang"
test_project "javascript-react" "$EXAMPLES_DIR/javascript/javascript-react"
test_project "javascript-vite-react" "$EXAMPLES_DIR/javascript/javascript-vite-react"
test_project "javascript-vite-vue" "$EXAMPLES_DIR/javascript/javascript-vite-vue"

# .NET
test_project "csharp-project" "$EXAMPLES_DIR/csharp-project"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC}  $PASSED"
echo -e "  ${RED}Failed:${NC}  $FAILED"
echo -e "  ${YELLOW}Skipped:${NC} $SKIPPED"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo -e "${RED}Some tests failed. Check logs for details.${NC}"
    exit 1
fi

if [ $PASSED -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}Warning: No tests passed. Check if examples exist.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All real-world build tests passed!${NC}"
exit 0

