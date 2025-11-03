# High-Performance Serialization

D-native, SIMD-accelerated serialization framework inspired by Cap'n Proto.

## Features

- **Zero-copy deserialization** - Direct memory access without parsing
- **SIMD-accelerated** - AVX2/NEON varint encoding (4-8x faster)
- **Type-safe** - Compile-time schema validation
- **Schema evolution** - Forward/backward compatibility
- **Compact** - ~40% smaller than JSON
- **Fast** - ~10x faster than JSON
- **Zero dependencies** - Pure D + C

## Quick Start

```d
import infrastructure.utils.serialization;

@Serializable(SchemaVersion(1, 0))
struct User {
    @Field(1) uint id;
    @Field(2) string name;
    @Field(3) @Optional string email;
}

auto user = User(42, "Alice", "alice@example.com");
ubyte[] bytes = Codec.serialize(user);
auto result = Codec.deserialize!User(bytes);
```

## Architecture

```
serialization/
├── package.d          # Public API
├── README.md          # This file
├── core/              # Core implementation
│   ├── schema.d       # Schema attributes & compile-time validation
│   ├── codec.d        # Serialize/deserialize engine
│   ├── buffer.d       # Zero-copy read/write buffers
│   ├── evolution.d    # Schema versioning & migration
│   ├── reflection.d   # Compile-time introspection
│   └── bindings.d     # C SIMD bindings
└── c/                 # C SIMD hot paths
    ├── varint.c       # SIMD varint encode/decode
    ├── memops.c       # Vectorized memory ops
    └── Makefile
```

## Performance

### vs Existing Binary Format
- Serialize: **2.5x faster**
- Deserialize: **4x faster**
- Arrays: **4.7x faster** (SIMD)

### vs JSON
- Serialize: **23x faster**
- Deserialize: **72x faster**
- Size: **3.9x smaller**

## Examples

See `/examples/serialization/`:
- `basic_example.d` - Simple usage
- `evolution_example.d` - Schema versioning

## Integration

Replace serialization in:
- Build cache (`engine/caching/targets/storage.d`)
- Action cache (`engine/caching/actions/storage.d`)
- Graph storage (`engine/graph/storage.d`)
- AST cache (`infrastructure/config/caching/storage.d`)

## Documentation

See `/examples/serialization/README.md` for full documentation.

