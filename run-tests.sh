#!/bin/bash
# Builder Test Runner Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    BUILDER TEST SUITE                          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Parse arguments
VERBOSE=""
PARALLEL=""
FILTER=""
COVERAGE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE="--verbose"
            shift
            ;;
        -p|--parallel)
            PARALLEL="--parallel"
            shift
            ;;
        -f|--filter)
            FILTER="--filter=$2"
            shift 2
            ;;
        -c|--coverage)
            COVERAGE="--coverage"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-v|--verbose] [-p|--parallel] [-f|--filter FILTER] [-c|--coverage]"
            exit 1
            ;;
    esac
done

# Build the test runner
echo -e "${CYAN}[INFO]${NC} Building test suite..."
dub build --config=unittest $COVERAGE

# Run tests
echo -e "${CYAN}[INFO]${NC} Running tests..."
dub test $COVERAGE -- $VERBOSE $PARALLEL $FILTER

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All tests passed!${NC}"
    
    if [ -n "$COVERAGE" ]; then
        echo ""
        echo -e "${CYAN}[INFO]${NC} Coverage report generated"
        echo "View coverage files in project root (.lst files)"
    fi
    
    exit 0
else
    echo ""
    echo -e "${RED}✗ Tests failed${NC}"
    exit 1
fi

