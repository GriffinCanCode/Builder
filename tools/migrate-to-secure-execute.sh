#!/bin/bash
# Migration script to update all execute() calls to use secure version
# 
# Usage: ./tools/migrate-to-secure-execute.sh [--dry-run]
#
# This script:
# 1. Finds all files using std.process : execute
# 2. Updates imports to use utils.security : execute
# 3. Adds std.process : Config where needed
# 4. Creates backup files (.bak)

set -e

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "DRY RUN MODE - No files will be modified"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Builder Security Migration Tool ==="
echo "Repository: $REPO_ROOT"
echo ""

# Find all D files importing std.process
FILES=$(find source -name "*.d" -type f | xargs grep -l "import std.process" || true)

if [ -z "$FILES" ]; then
    echo "No files found to migrate"
    exit 0
fi

FILE_COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
echo "Found $FILE_COUNT files to migrate"
echo ""

MIGRATED=0
SKIPPED=0

for FILE in $FILES; do
    # Check if already migrated
    if grep -q "import utils.security : execute" "$FILE"; then
        echo "SKIP: $FILE (already migrated)"
        ((SKIPPED++))
        continue
    fi
    
    # Check if file actually uses execute()
    if ! grep -q "execute(" "$FILE"; then
        echo "SKIP: $FILE (doesn't use execute)"
        ((SKIPPED++))
        continue
    fi
    
    echo "MIGRATE: $FILE"
    
    if [ "$DRY_RUN" = false ]; then
        # Create backup
        cp "$FILE" "$FILE.bak"
        
        # Replace import std.process; with secure imports
        # This is a simple replacement - manual review recommended
        sed -i.tmp 's/^import std\.process;$/import std.process : Config;\nimport utils.security : execute;  \/\/ SECURITY: Auto-migrated/g' "$FILE"
        
        # If sed created .tmp file, remove it
        rm -f "$FILE.tmp"
        
        echo "  ✓ Migrated (backup: $FILE.bak)"
    else
        echo "  Would migrate (dry run)"
    fi
    
    ((MIGRATED++))
done

echo ""
echo "=== Migration Summary ==="
echo "Files migrated: $MIGRATED"
echo "Files skipped:  $SKIPPED"
echo "Total files:    $FILE_COUNT"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "Run without --dry-run to apply changes"
    echo "Review changes carefully before committing!"
fi

if [ $MIGRATED -gt 0 ] && [ "$DRY_RUN" = false ]; then
    echo ""
    echo "IMPORTANT: Manual review required!"
    echo "1. Check that Config is imported correctly"
    echo "2. Verify execute() calls work as expected"
    echo "3. Run tests: dub test"
    echo "4. Review backups: find source -name '*.bak'"
    echo ""
    echo "To restore backups:"
    echo "  find source -name '*.bak' -exec sh -c 'mv \"\$1\" \"\${1%.bak}\"' _ {} \\;"
fi

