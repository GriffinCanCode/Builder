module core.distributed.memory;

/// Memory optimizations for distributed builds
/// 
/// Components:
/// - arena.d  - Arena allocator for batch allocations
/// - pool.d   - Object pooling for reuse
/// - buffer.d - Buffer management and ring buffers
/// 
/// Design Principles:
/// - Zero-copy where possible
/// - Minimize GC pressure
/// - Cache-friendly allocations
/// - Thread-safe pooling

public import core.distributed.memory.arena;
public import core.distributed.memory.pool;
public import core.distributed.memory.buffer;


