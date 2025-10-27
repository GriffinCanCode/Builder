#!/usr/bin/env bash
# Builder Documentation Generator
# Generates comprehensive DDoc documentation with HTML output

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs/api"
SOURCE_DIR="$PROJECT_ROOT/source"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Builder Documentation Generator${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"

# Clean previous documentation
echo -e "\n${YELLOW}Cleaning previous documentation...${NC}"
rm -rf "$DOCS_DIR"
mkdir -p "$DOCS_DIR"

# Find all D source files
echo -e "\n${YELLOW}Finding D source files...${NC}"
D_FILES=$(find "$SOURCE_DIR" -name "*.d" | wc -l | tr -d ' ')
echo -e "Found ${GREEN}$D_FILES${NC} D source files"

# Use Python script to extract DDoc comments
echo -e "\n${YELLOW}Extracting DDoc comments from source files...${NC}"

# Run the Python extractor
python3 "$SCRIPT_DIR/extract-ddoc.py" "$SOURCE_DIR" "$DOCS_DIR"

TOTAL_MODULES=$(find "$DOCS_DIR" -name "*.html" ! -name "index.html" | wc -l | tr -d ' ')

echo -e "\n${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Documentation Generated Successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "\n📁 Output directory: ${BLUE}$DOCS_DIR${NC}"
echo -e "📄 Index file: ${BLUE}$DOCS_DIR/index.html${NC}"
echo -e "📊 Total modules documented: ${GREEN}$TOTAL_MODULES${NC}"
echo -e "\n💡 To view documentation, open:"
echo -e "   ${YELLOW}open $DOCS_DIR/index.html${NC}"
echo -e "\n   Or start a simple HTTP server:"
echo -e "   ${YELLOW}python3 -m http.server --directory $DOCS_DIR 8000${NC}"
echo -e "   ${YELLOW}Then visit: http://localhost:8000${NC}"
echo -e "\n${GREEN}✨ Done!${NC}\n"
