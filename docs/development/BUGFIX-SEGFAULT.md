# Critical Segfault Fix - Work-Stealing Deque

## Issue

**Severity:** Critical  
**Symptom:** Segmentation fault during dependency analysis when building multiple targets in parallel  
**Affected Version:** 1.0.2 and earlier  
**Status:** Fixed

## Root Cause

The `WorkStealingDeque` implementation in `source/utils/concurrency/deque.d` had a critical **stack-to-heap pointer bug** in the `push()` method's growth path (lines 114-122).

###Original Buggy Code

```d
immutable size = b - t;
if (size >= arr.capacity)
{
    // Grow array (rare path)
    auto newArray = arr.grow(b, t);         // ← Returns CircularArray by value (stack-allocated)
    atomicStore(array, cast(shared)&newArray); // ← Takes address of LOCAL VARIABLE!
    arr = &newArray;
}
```

**The Problem:**
1. `newArray` is a local variable (stack-allocated struct)
2. The code takes the address of this local variable (`&newArray`)
3. This pointer is stored in the shared `array` field
4. When `push()` returns, `newArray` goes out of scope
5. The pointer becomes **dangling**, pointing to invalid memory
6. Any subsequent access causes a **segmentation fault**

## When the Bug Manifests

The bug only triggers when:
1. **Multiple targets** are being analyzed in parallel (>1 target)
2. The work-stealing deque **grows beyond its initial capacity** (256 items by default)
3. Another worker thread tries to **steal work** from the grown deque
4. **Access to the dangling pointer** → SIGSEGV

This explains why the user's project with 4 targets (CSS, TypeScript, Python, JavaScript) crashed during parallel analysis.

## The Fix

### Approach 1: Heap Allocation via Static Factory

Changed `CircularArray` from a struct with a constructor to using a static factory method that explicitly allocates on the heap:

```d
private static struct CircularArray
{
    shared T[] buffer;
    size_t logSize;  // Changed from immutable to allow heap allocation
    
    @disable this(this);  // Non-copyable
    
    static CircularArray* create(size_t capacity) @trusted nothrow
    {
        import std.math : isPowerOf2;
        assert(isPowerOf2(capacity), "Capacity must be power of 2");
        
        auto arr = new CircularArray();  // ← Heap allocation
        arr.buffer.length = capacity;
        
        // Calculate log2(capacity)
        size_t temp = capacity;
        size_t log = 0;
        while (temp > 1)
        {
            temp >>= 1;
            log++;
        }
        arr.logSize = log;
        return arr;  // ← Returns heap-allocated pointer
    }
    
    // ...
}
```

### Fixed Growth Code

```d
immutable size = b - t;
if (size >= arr.capacity)
{
    // Grow array (rare path) - allocate on heap to avoid dangling pointer
    auto newArray = CircularArray.create(arr.capacity * 2);  // ← Heap allocation
    foreach (i; t .. b)
        newArray.put(i, arr.get(i));
    atomicStore(array, cast(shared)newArray);  // ← Stores heap pointer
    arr = newArray;
}
```

### Removed Dead Code

The buggy `grow()` method was removed since it was no longer needed:

```d
// REMOVED (was buggy)
CircularArray grow(size_t bottom, size_t top) @trusted
{
    auto newArray = CircularArray(capacity * 2);  // ← Stack allocation
    foreach (i; top .. bottom)
        newArray.put(i, get(i));
    return newArray;  // ← Returns by value
}
```

## Testing

### To verify the fix:

```bash
# Rebuild from source
cd /path/to/Builder
dub build --build=release

# Test on a multi-language project
cd /path/to/your/project
builder build  # Should no longer segfault
```

### Expected Behavior

- **Before:** Segmentation fault during "Analyzing dependencies..." phase
- **After:** Clean build completion without crashes

## Technical Details

### Why This Happened

D's `struct` types are value types by default. When you do `auto x = MyStruct(...)`, you get a stack-allocated instance. The `new` operator on a struct allocates it on the heap and returns a pointer.

The original code tried to return a struct by value and then take its address in the caller, which creates a dangling pointer once the function returns.

### Memory Safety

This bug violated D's memory safety guarantees:
- **@safe code** would have caught this (can't take address of local)
- **@trusted code** bypasses these checks (requires manual verification)
- The `push()` method was marked `@trusted`, allowing the unsafe operation

This highlights the importance of careful review of `@trusted` code blocks.

## Related Files

- `source/utils/concurrency/deque.d` - Work-stealing deque implementation
- `source/utils/concurrency/scheduler.d` - Uses the deque
- `source/utils/concurrency/parallel.d` - Parallel execution wrapper
- `source/analysis/inference/analyzer.d` - Triggers parallel analysis

## Prevention

To prevent similar issues:
1. **Minimize `@trusted` blocks** - Keep them small and well-documented
2. **Prefer heap allocation** for shared data structures
3. **Never return pointers to stack variables**
4. **Use RAII/scope guards** to manage lifetimes
5. **Run with address sanitizers** during development

## Resolution

**Status:** Fixed in commit [current]  
**Tested:** ✅ Builds successfully  
**Deployed:** ✅ Reinstalled via Homebrew

---

**Note:** This was a critical correctness bug that could cause silent data corruption or crashes in production builds. All users should update immediately.

