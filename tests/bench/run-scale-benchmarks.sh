#!/bin/bash

# Builder Scale Benchmark Runner
# Runs comprehensive benchmarks with 50K-100K targets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Builder Scale Benchmark Runner                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUILDER_BINARY="${PROJECT_ROOT}/bin/builder"
WORKSPACE_DIR="${PROJECT_ROOT}/bench-workspace"
INTEGRATION_WORKSPACE="${PROJECT_ROOT}/integration-bench-workspace"
RUN_SIMULATED=true
RUN_INTEGRATION=true
KEEP_WORKSPACE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --simulated-only)
            RUN_INTEGRATION=false
            shift
            ;;
        --integration-only)
            RUN_SIMULATED=false
            shift
            ;;
        --keep-workspace)
            KEEP_WORKSPACE=true
            shift
            ;;
        --builder)
            BUILDER_BINARY="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --simulated-only     Run only simulated benchmarks (fast)"
            echo "  --integration-only   Run only integration benchmarks (real builds)"
            echo "  --keep-workspace     Don't clean up workspace after tests"
            echo "  --builder PATH       Path to Builder binary (default: bin/builder)"
            echo "  --help               Show this help message"
            echo
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if dub is available
if ! command -v dub &> /dev/null; then
    echo -e "${RED}✗ Error: dub not found${NC}"
    echo "Please install dub (D package manager)"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Configuration:"
echo "  Project Root: $PROJECT_ROOT"
echo "  Builder Binary: $BUILDER_BINARY"
echo "  Simulated Tests: $RUN_SIMULATED"
echo "  Integration Tests: $RUN_INTEGRATION"
echo

# Check if Builder binary exists (only if running integration tests)
if [ "$RUN_INTEGRATION" = true ]; then
    if [ ! -f "$BUILDER_BINARY" ]; then
        echo -e "${YELLOW}⚠ Warning: Builder binary not found at $BUILDER_BINARY${NC}"
        echo "Building Builder..."
        
        cd "$PROJECT_ROOT"
        if make; then
            echo -e "${GREEN}✓ Builder built successfully${NC}"
        else
            echo -e "${RED}✗ Failed to build Builder${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Builder binary found${NC}"
    fi
fi

# Function to run a benchmark
run_benchmark() {
    local name=$1
    local script=$2
    local args=$3
    
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Running: $name${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    cd "$SCRIPT_DIR"
    
    if dub run --single "$script" -- $args; then
        echo
        echo -e "${GREEN}✓ $name completed successfully${NC}"
        return 0
    else
        echo
        echo -e "${RED}✗ $name failed${NC}"
        return 1
    fi
}

# Track results
FAILED_TESTS=()
PASSED_TESTS=()

# Run simulated benchmarks
if [ "$RUN_SIMULATED" = true ]; then
    if run_benchmark "Simulated Scale Benchmark" "scale_benchmark.d" "--workspace=$WORKSPACE_DIR"; then
        PASSED_TESTS+=("Simulated Benchmark")
    else
        FAILED_TESTS+=("Simulated Benchmark")
    fi
fi

# Run integration benchmarks
if [ "$RUN_INTEGRATION" = true ]; then
    if run_benchmark "Integration Benchmark" "integration_bench.d" "--workspace=$INTEGRATION_WORKSPACE --builder=$BUILDER_BINARY"; then
        PASSED_TESTS+=("Integration Benchmark")
    else
        FAILED_TESTS+=("Integration Benchmark")
    fi
fi

# Cleanup workspaces (unless --keep-workspace is specified)
if [ "$KEEP_WORKSPACE" = false ]; then
    echo
    echo -e "${BLUE}[INFO]${NC} Cleaning up workspaces..."
    
    if [ -d "$WORKSPACE_DIR" ]; then
        rm -rf "$WORKSPACE_DIR"
        echo "  Removed: $WORKSPACE_DIR"
    fi
    
    if [ -d "$INTEGRATION_WORKSPACE" ]; then
        rm -rf "$INTEGRATION_WORKSPACE"
        echo "  Removed: $INTEGRATION_WORKSPACE"
    fi
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
else
    echo
    echo -e "${YELLOW}[INFO]${NC} Keeping workspaces for inspection:"
    [ -d "$WORKSPACE_DIR" ] && echo "  - $WORKSPACE_DIR"
    [ -d "$INTEGRATION_WORKSPACE" ] && echo "  - $INTEGRATION_WORKSPACE"
fi

# Print final summary
echo
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    BENCHMARK SUMMARY                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
    echo -e "${GREEN}Passed Tests (${#PASSED_TESTS[@]}):${NC}"
    for test in "${PASSED_TESTS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $test"
    done
    echo
fi

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo -e "${RED}Failed Tests (${#FAILED_TESTS[@]}):${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}✗${NC} $test"
    done
    echo
fi

# List generated reports
echo -e "${BLUE}Generated Reports:${NC}"
cd "$PROJECT_ROOT"
for report in benchmark-*.md; do
    if [ -f "$report" ]; then
        SIZE=$(du -h "$report" | cut -f1)
        echo "  - $report ($SIZE)"
    fi
done
echo

# Exit with appropriate status
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All benchmarks completed successfully!${NC}"
    echo
    exit 0
else
    echo -e "${RED}✗ Some benchmarks failed${NC}"
    echo
    exit 1
fi

