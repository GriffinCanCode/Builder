#!/usr/bin/env bash
# Memory Safety Audit Script
# Detects potentially unsafe patterns in the Builder codebase

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "======================================================"
echo "Memory Safety Audit for Builder"
echo "======================================================"
echo ""

# Counter for issues
TOTAL_ISSUES=0

# Function to print section headers
print_section() {
    echo ""
    echo "------------------------------------------------------"
    echo "$1"
    echo "------------------------------------------------------"
}

# Function to count and report findings
report_findings() {
    local count=$1
    local message=$2
    local severity=$3
    
    if [ "$count" -gt 0 ]; then
        if [ "$severity" = "HIGH" ]; then
            echo -e "${RED}✗ Found $count occurrences: $message${NC}"
            TOTAL_ISSUES=$((TOTAL_ISSUES + count))
        elif [ "$severity" = "MEDIUM" ]; then
            echo -e "${YELLOW}⚠ Found $count occurrences: $message${NC}"
            TOTAL_ISSUES=$((TOTAL_ISSUES + count))
        else
            echo -e "${GREEN}ℹ Found $count occurrences: $message${NC}"
        fi
    else
        echo -e "${GREEN}✓ No issues found: $message${NC}"
    fi
}

# ===================================================================
# 1. Check for const-casting (HIGH PRIORITY)
# ===================================================================
print_section "1. Checking for const-casting violations"

CONST_CASTS=$(rg 'cast\((const|immutable|string\[\]|Target|WorkspaceConfig)\)' source/ -t d --count-matches 2>/dev/null || true)
CONST_CAST_COUNT=$(echo "$CONST_CASTS" | awk -F: '{sum += $2} END {print sum+0}')
report_findings "$CONST_CAST_COUNT" "const-casting detected (violates type system)" "HIGH"

if [ "$CONST_CAST_COUNT" -gt 0 ]; then
    echo "  Files with const-casts:"
    echo "$CONST_CASTS" | head -10
fi

# ===================================================================
# 2. Check for @trusted without documentation (MEDIUM PRIORITY)
# ===================================================================
print_section "2. Checking for undocumented @trusted annotations"

# Find @trusted that are NOT preceded by safety documentation
UNDOC_TRUSTED=$(rg -U '@trusted(?!\n\s*(?:static|void|bool|string|ubyte|int|long|ulong|size_t|auto|const|immutable|ref|private|public|protected))' source/ -t d -c 2>/dev/null || echo "0")
UNDOC_COUNT=$(echo "$UNDOC_TRUSTED" | awk -F: '{sum += $2} END {print sum+0}')

# Get documented vs undocumented counts
TOTAL_TRUSTED=$(rg '@trusted' source/ -t d --count-matches 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
DOCUMENTED=$((TOTAL_TRUSTED - UNDOC_COUNT))

echo "  Total @trusted: $TOTAL_TRUSTED"
echo "  Documented: $DOCUMENTED"
echo "  Undocumented: $UNDOC_COUNT"

if [ "$UNDOC_COUNT" -gt 5 ]; then
    report_findings "$UNDOC_COUNT" "@trusted without safety documentation" "MEDIUM"
else
    echo -e "${GREEN}✓ Most @trusted annotations are documented${NC}"
fi

# ===================================================================
# 3. Check for manual pointer arithmetic (MEDIUM PRIORITY)
# ===================================================================
print_section "3. Checking for manual pointer arithmetic"

PTR_ARITH=$(rg 'ptr\s*[\+\-]\s*\d+|ptr\s*\+\+|ptr\s*--' source/ -t d --count-matches 2>/dev/null || true)
PTR_COUNT=$(echo "$PTR_ARITH" | awk -F: '{sum += $2} END {print sum+0}')

# Exclude utils/simd and utils/crypto (expected FFI)
PTR_ARITH_NON_FFI=$(rg 'ptr\s*[\+\-]\s*\d+|ptr\s*\+\+|ptr\s*--' source/ -t d --count-matches 2>/dev/null | grep -v 'utils/simd' | grep -v 'utils/crypto' | awk -F: '{sum += $2} END {print sum+0}' || echo "0")

report_findings "$PTR_ARITH_NON_FFI" "manual pointer arithmetic outside FFI" "MEDIUM"

# ===================================================================
# 4. Check for unsafe cast patterns (MEDIUM PRIORITY)
# ===================================================================
print_section "4. Checking for unsafe cast patterns"

# Casts from ubyte[] to string without validation
UBYTE_TO_STRING=$(rg 'cast\((?:immutable\(char\)\[\]|string)\)' source/ -t d --count-matches 2>/dev/null | grep -v 'utils/crypto' | grep -v 'test' | awk -F: '{sum += $2} END {print sum+0}' || echo "0")
report_findings "$UBYTE_TO_STRING" "ubyte[] to string casts (potential UTF-8 issues)" "MEDIUM"

# ===================================================================
# 5. Check for @system code (INFO)
# ===================================================================
print_section "5. Checking for @system code"

SYSTEM_COUNT=$(rg '@system' source/ -t d --count-matches 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
report_findings "$SYSTEM_COUNT" "@system annotations (expected for FFI)" "INFO"

# ===================================================================
# 6. Summary
# ===================================================================
print_section "Summary"

echo "Total potential issues found: $TOTAL_ISSUES"
echo ""

if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo -e "${GREEN}✓ Memory safety audit passed!${NC}"
    exit 0
elif [ "$TOTAL_ISSUES" -lt 10 ]; then
    echo -e "${YELLOW}⚠ Minor memory safety issues detected${NC}"
    exit 0
else
    echo -e "${RED}✗ Significant memory safety issues detected${NC}"
    exit 1
fi

