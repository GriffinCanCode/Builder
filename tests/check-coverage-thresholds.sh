#!/bin/bash
# Coverage Threshold Checker for Builder
# Enforces minimum coverage requirements

set -e

# Get the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Coverage thresholds
THRESHOLD_CORE=80
THRESHOLD_OVERALL=70

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

cd "${PROJECT_ROOT}"

# Find all .lst files
LST_FILES=$(find . -maxdepth 1 -name "*.lst" -type f)

if [ -z "$LST_FILES" ]; then
    echo -e "${YELLOW}[WARN]${NC} No coverage files found"
    exit 0
fi

echo ""
echo -e "${CYAN}[INFO]${NC} Checking coverage thresholds..."
echo "  Core modules:    ${THRESHOLD_CORE}% minimum"
echo "  Overall:         ${THRESHOLD_OVERALL}% minimum"
echo ""

# Core module patterns (engine/core, engine/runtime, etc.)
CORE_PATTERNS=(
    "engine-core"
    "engine-runtime"
    "engine-graph"
    "engine-cache"
)

declare -A overall_coverage
declare -A core_coverage
overall_total=0
overall_covered=0
core_total=0
core_covered=0

# Parse coverage files
for lst_file in $LST_FILES; do
    filename=$(basename "$lst_file" .lst)
    
    total_lines=0
    covered_lines=0
    
    while IFS='|' read -r coverage line_num source_line; do
        [ -z "$coverage" ] && continue
        
        total_lines=$((total_lines + 1))
        
        if [[ "$coverage" != "0000000" ]] && [[ "$coverage" =~ ^[0-9]+$ ]] && [ "$coverage" -gt 0 ]; then
            covered_lines=$((covered_lines + 1))
        fi
    done < "$lst_file"
    
    # Check if this is a core module
    is_core=false
    for pattern in "${CORE_PATTERNS[@]}"; do
        if [[ "$filename" == *"$pattern"* ]]; then
            is_core=true
            break
        fi
    done
    
    # Add to totals
    overall_total=$((overall_total + total_lines))
    overall_covered=$((overall_covered + covered_lines))
    
    if [ "$is_core" = true ]; then
        core_total=$((core_total + total_lines))
        core_covered=$((core_covered + covered_lines))
    fi
    
    # Calculate file coverage
    if [ $total_lines -gt 0 ]; then
        file_coverage=$(awk "BEGIN {printf \"%.1f\", ($covered_lines/$total_lines)*100}")
        overall_coverage["$filename"]=$file_coverage
        
        if [ "$is_core" = true ]; then
            core_coverage["$filename"]=$file_coverage
        fi
    fi
done

# Calculate overall percentages
if [ $overall_total -gt 0 ]; then
    overall_percent=$(awk "BEGIN {printf \"%.1f\", ($overall_covered/$overall_total)*100}")
else
    overall_percent=0
fi

if [ $core_total -gt 0 ]; then
    core_percent=$(awk "BEGIN {printf \"%.1f\", ($core_covered/$core_total)*100}")
else
    core_percent=100  # No core files means threshold met
fi

# Print results
echo "Coverage Results:"
echo "  Overall: ${overall_percent}% (${overall_covered}/${overall_total} lines)"
echo "  Core:    ${core_percent}% (${core_covered}/${core_total} lines)"
echo ""

# Check thresholds
threshold_passed=true

# Check overall threshold
if (( $(echo "$overall_percent < $THRESHOLD_OVERALL" | bc -l) )); then
    echo -e "${RED}✗ Overall coverage ${overall_percent}% below threshold ${THRESHOLD_OVERALL}%${NC}"
    threshold_passed=false
else
    echo -e "${GREEN}✓ Overall coverage ${overall_percent}% meets threshold ${THRESHOLD_OVERALL}%${NC}"
fi

# Check core threshold
if (( $(echo "$core_percent < $THRESHOLD_CORE" | bc -l) )); then
    echo -e "${RED}✗ Core coverage ${core_percent}% below threshold ${THRESHOLD_CORE}%${NC}"
    threshold_passed=false
else
    echo -e "${GREEN}✓ Core coverage ${core_percent}% meets threshold ${THRESHOLD_CORE}%${NC}"
fi

# Print low coverage modules
echo ""
echo "Modules below overall threshold:"
for filename in "${!overall_coverage[@]}"; do
    coverage="${overall_coverage[$filename]}"
    if (( $(echo "$coverage < $THRESHOLD_OVERALL" | bc -l) )); then
        echo -e "  ${YELLOW}⚠${NC}  $filename: ${coverage}%"
    fi
done

echo ""

if [ "$threshold_passed" = true ]; then
    exit 0
else
    exit 1
fi

