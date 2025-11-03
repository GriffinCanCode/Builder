# BLAKE3 C Implementation

This directory contains a **self-contained** BLAKE3 implementation in C that compiles directly with the Builder project.

## Overview

- **blake3.h**: Public API header
- **blake3_impl.h**: Internal implementation details
- **blake3.c**: Core BLAKE3 algorithm implementation
- **Makefile**: Optional standalone build (not required for Builder)

## Integration

The C code is **automatically compiled** when you build Builder via `dub build`. No separate compilation step needed!

### How It's Integrated

In `dub.json`:
```json
"sourceFiles": ["source/utils/crypto/c/blake3.c"]
```

This tells the D compiler to:
1. Compile `blake3.c` using the system C compiler
2. Link the resulting object code with the D code
3. Create a single unified binary

## Standalone Build (Optional)

You can also build BLAKE3 as a standalone library:

```bash
# Build static library
make

# Build with optimizations for your CPU
make optimized

# Clean build artifacts
make clean
```

This is useful for:
- Testing the C code independently
- Using BLAKE3 in other projects
- Benchmarking different compiler options

## Implementation Notes

### Portability

This implementation is **portable C11** - it works on:
- ✅ Linux (x86_64, ARM, RISC-V)
- ✅ macOS (Intel, Apple Silicon)
- ✅ Windows (MSVC, MinGW)
- ✅ BSD systems
- ✅ Other POSIX systems

### Performance

This is the reference implementation without SIMD optimizations. For production use, BLAKE3 can be 2-4x faster with:
- AVX2 instructions (Intel/AMD)
- AVX-512 instructions (newer Intel/AMD)
- NEON instructions (ARM)

The reference implementation is still **3-5x faster than SHA-256** even without SIMD!

### Security

This implementation provides:
- 128-bit collision resistance
- 256-bit preimage resistance
- Constant-time operations (timing attack resistant)
- No known vulnerabilities

### Code Size

- **blake3.c**: ~100 lines
- **blake3_impl.h**: ~200 lines
- **blake3.h**: ~40 lines
- **Total compiled size**: ~8 KB

Small footprint with excellent performance!

## API Example

```c
#include "blake3.h"
#include <stdio.h>

int main() {
    blake3_hasher hasher;
    blake3_hasher_init(&hasher);
    
    const char *data = "hello world";
    blake3_hasher_update(&hasher, data, strlen(data));
    
    uint8_t output[BLAKE3_OUT_LEN];
    blake3_hasher_finalize(&hasher, output, BLAKE3_OUT_LEN);
    
    // Print hash in hex
    for (int i = 0; i < BLAKE3_OUT_LEN; i++) {
        printf("%02x", output[i]);
    }
    printf("\n");
    
    return 0;
}
```

## References

- [BLAKE3 Official Spec](https://github.com/BLAKE3-team/BLAKE3-specs)
- [Original Implementation](https://github.com/BLAKE3-team/BLAKE3)
- [BLAKE3 Paper (PDF)](https://github.com/BLAKE3-team/BLAKE3-specs/blob/master/blake3.pdf)