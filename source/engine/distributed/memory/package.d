module engine.distributed.memory;

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

public import engine.distributed.memory.arena;
public import engine.distributed.memory.pool;
public import engine.distributed.memory.buffer;


