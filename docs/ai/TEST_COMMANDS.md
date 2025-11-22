# Test Commands for Builder Explain

This file contains test commands to verify the `builder explain` system works correctly.

## Basic Commands

### List all topics
```bash
builder explain list
```

Expected output: List of 9 concepts with summaries

### Show a topic
```bash
builder explain blake3
```

Expected output: Full documentation for BLAKE3 with definition, key points, usage, etc.

### Search functionality
```bash
builder explain search "fast"
```

Expected output: Topics related to "fast" (blake3, caching, incremental)

```bash
builder explain search "cache"
```

Expected output: All caching-related topics

### Alias resolution
```bash
builder explain hash
```

Expected output: Same as `builder explain blake3` (alias resolution)

```bash
builder explain sandbox
```

Expected output: Same as `builder explain hermetic` (alias resolution)

### Show examples
```bash
builder explain example caching
```

Expected output: Usage examples for caching

### Help/usage
```bash
builder explain
```

Expected output: Usage information and available topics

## Test Coverage

### All Concepts
- [x] blake3
- [x] caching
- [x] determinism
- [x] incremental
- [x] action-cache
- [x] remote-cache
- [x] hermetic
- [x] workspace
- [x] targets

### All Aliases
- [x] hash → blake3
- [x] cache → caching
- [x] reproducible → determinism
- [x] sandbox → hermetic
- [x] builderspace → workspace
- [x] target → targets

### Search Terms
- [x] "fast" - Should find blake3, caching
- [x] "cache" - Should find all caching topics
- [x] "build" - Should find multiple topics
- [x] "optimization" - Should find caching, incremental

## AI Assistant Usage Examples

### Example 1: Learn about caching
```bash
builder explain caching
```

AI will receive structured information about:
- What caching is
- Architecture (3 tiers)
- How it works
- Performance impact
- Related topics

### Example 2: Find topics about performance
```bash
builder explain search "performance"
```

AI will see: blake3, caching, incremental, action-cache

### Example 3: Get working code examples
```bash
builder explain example blake3
```

AI will receive copy-paste ready code examples

### Example 4: Discover related concepts
After reading "caching", the related field shows:
- blake3 (for hash functions)
- determinism (for cache reliability)
- action-cache (for finer caching)
- remote-cache (for distributed caching)

AI can then query: `builder explain action-cache`

## Testing Checklist

When testing the system:

1. **List Command**
   - [ ] Shows all 9 concepts
   - [ ] Summaries are displayed correctly
   - [ ] Formatting is readable

2. **Show Command**
   - [ ] Topic loads correctly
   - [ ] All sections display (summary, definition, key points, etc.)
   - [ ] Related topics are listed
   - [ ] Next steps are shown

3. **Search Command**
   - [ ] Finds topics by name
   - [ ] Finds topics by summary
   - [ ] Finds topics by keywords
   - [ ] Shows count of results

4. **Alias Command**
   - [ ] Aliases resolve to correct topics
   - [ ] Display is identical to direct topic access

5. **Error Handling**
   - [ ] Unknown topic shows helpful message
   - [ ] Missing search query shows usage
   - [ ] Index file not found handled gracefully

## Manual Verification

Since there are pre-existing compilation errors in the codebase, manual verification of JSON:

1. Verify YAML files parse correctly:
```bash
# Check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('docs/ai/index.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('docs/ai/concepts/blake3.yaml'))"
```

2. Verify index structure:
```bash
# Check index contains all topics
grep -c "^  [a-z]" docs/ai/index.yaml
# Should be 9
```

3. Verify all concept files exist:
```bash
ls docs/ai/concepts/*.yaml
# Should list 9 files
```

## Notes for AI

When using `builder explain`:
- Always use the single-word topic name (e.g., "blake3", not "BLAKE3 hashing")
- Use `search` when you're not sure of the exact topic name
- Check `related` field to discover connected concepts
- Use `list` to see all available topics
- Examples are copy-paste ready - use them directly

## Performance

Expected response times:
- List: < 50ms
- Show topic: < 100ms  
- Search: < 150ms
- Example: < 100ms

All operations are file-based (no database), so they're very fast.

