# Utils Package

The utils package provides common utilities for file handling, parallelization, hashing, and benchmarking used throughout the Builder system.

## Core Modules

### File Operations
- **glob.d** - Glob pattern matching for file selection
- **hash.d** - Fast file hashing with BLAKE3
- **chunking.d** - File chunking for parallel processing
- **metadata.d** - File metadata and timestamps
- **ignore.d** - Ignore patterns for dependency and build directories

### Concurrency (Basic)
- **pool.d** - Persistent thread pool implementation
- **simd.d** - SIMD-aware parallel operations
- **lockfree.d** - Lock-free queue and hash cache

### Concurrency (Advanced)
- **parallel.d** - Enhanced parallel execution with multiple strategies
- **deque.d** - Lock-free work-stealing deque (Chase-Lev algorithm)
- **scheduler.d** - Work-stealing scheduler with priority support
- **balancer.d** - Dynamic load balancing with adaptive strategies
- **priority.d** - Priority queues and critical path scheduling

### Memory Optimization
- **intern.d** - String interning for memory deduplication (60-80% savings)

### Other
- **logger.d** - Structured logging infrastructure
- **bench.d** - Performance benchmarking utilities
- **pycheck.d** - Python environment validation
- **pywrap.d** - Python integration wrapper
- **validation.d** - Security validation for paths and arguments
- **process.d** - Process and tool availability checking

## Usage Examples

### String Interning (Memory Optimization)
```d
import utils;

// Basic interning with thread-local pool
auto s1 = intern("common/path");
auto s2 = intern("common/path");
assert(s1 == s2);  // O(1) pointer equality!

// Custom pool for fine-grained control
auto pool = new StringPool();
auto interned = pool.intern("/usr/local/bin");

// Domain-specific pools (recommended for large systems)
DomainPools pools = DomainPools(0);
auto path = pools.internPath("/src/main.d");
auto target = pools.internTarget("mylib");
auto import = pools.internImport("std.stdio");

// Get statistics
auto stats = pools.getCombinedStats();
writeln("Deduplication rate: ", stats.deduplicationRate, "%");
writeln("Memory saved: ", stats.savedBytes / 1024, " KB");
```

**Benefits:**
- **60-80% memory reduction** - Eliminates duplicate strings
- **O(1) equality** - Pointer comparison instead of content comparison
- **O(1) hashing** - Pre-computed hashes cached
- **Thread-safe** - Lock-free reads, synchronized writes
- **Cache-friendly** - Fewer allocations, better locality

**When to use:**
- File paths (highly duplicated in build systems)
- Target names (referenced many times)
- Import statements (repeated across analysis)
- Any frequently repeated strings

### Basic Parallel Execution (Backward Compatible)
```d
import utils;

// Simple parallel execution
auto results = ParallelExecutor.execute(items, func, 4);

// Auto-detect CPU count
auto results = ParallelExecutor.executeAuto(items, func);
```

### Advanced Work-Stealing Scheduler
```d
import utils;

// Work-stealing with automatic load balancing
auto results = ParallelExecutor.mapWorkStealing(items, func);

// With custom parallelism
auto results = ParallelExecutor.mapWorkStealing(items, func, 8);
```

### Priority-Based Scheduling
```d
import utils;

// High-priority execution for critical path
auto results = ParallelExecutor.mapPriority(items, func, Priority.Critical);

// Dynamic load balancing
auto results = ParallelExecutor.mapLoadBalanced(items, func);
```

### Advanced Configuration
```d
import utils;

ParallelConfig config;
config.mode = ExecutionMode.WorkStealing;
config.basePriority = Priority.High;
config.balanceStrategy = BalanceStrategy.Adaptive;
config.maxParallelism = 8;

auto results = ParallelExecutor.executeAdvanced(items, func, config);
```

### Statistics Collection
```d
import utils;

ParallelConfig config;
config.mode = ExecutionMode.WorkStealing;
config.enableStatistics = true;

ExecutionStats stats;
auto results = ParallelExecutor.executeWithStats(items, func, results, config);

writeln("Total stolen: ", stats.totalStolen);
writeln("Steal success rate: ", stats.stealSuccessRate);
writeln("Load imbalance: ", stats.loadImbalance);
```

### Direct Scheduler Usage
```d
import utils;

auto scheduler = new WorkStealingScheduler!Task(
    4,  // worker count
    (Task t) { /* execute task */ }
);

// Submit with priorities
scheduler.submit(task1, Priority.Critical, 1000, 1, 5);
scheduler.submit(task2, Priority.Normal);

scheduler.waitAll();
auto stats = scheduler.getStats();
scheduler.shutdown();
```

### Load Balancer
```d
import utils;

auto balancer = new LoadBalancer(4, BalanceStrategy.Adaptive);

// Select worker for task assignment
auto workerId = balancer.selectWorker();

// Select victim for work stealing
auto victimId = balancer.selectVictim(thiefId);

// Check if rebalancing needed
if (balancer.needsRebalancing()) {
    // Trigger rebalancing logic
}
```

## Key Features

### Performance
- **Lock-free data structures** - Chase-Lev deque for minimal contention
- **Work-stealing** - Automatic load balancing across workers
- **Priority scheduling** - Critical path optimization
- **Dynamic load balancing** - Adaptive strategies based on runtime metrics
- **SIMD acceleration** - Data-parallel operations where applicable
- **BLAKE3 hashing** - 3-5x faster than SHA-256 with SIMD

### Scheduling Strategies
- **Simple** - Basic std.parallelism (backward compatible)
- **WorkStealing** - Distributed deques with stealing on demand
- **LoadBalanced** - Dynamic distribution based on worker load
- **Priority** - Critical path tasks scheduled first
- **Adaptive** - Dynamically adjusts based on system metrics

### Design Principles
- **Backward compatible** - Existing code continues to work
- **Zero-cost abstraction** - Advanced features only when used
- **Type-safe** - Strong typing reduces runtime errors
- **Well-tested** - Comprehensive unit tests for all components
- **Documented** - Extensive inline documentation and examples

## Architecture

The concurrency system is layered:

1. **Foundation** - Lock-free deque (deque.d) for low-level task storage
2. **Prioritization** - Priority queues (priority.d) for task ordering
3. **Scheduling** - Work-stealing scheduler (scheduler.d) coordinates workers
4. **Balancing** - Load balancer (balancer.d) optimizes distribution
5. **Interface** - ParallelExecutor (parallel.d) provides high-level API

Each layer is independently testable and can be used standalone or composed.

