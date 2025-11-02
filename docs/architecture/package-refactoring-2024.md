# Package Architecture Refactoring (November 2024)

## Overview

This document describes the major package architecture refactoring performed to split the monolithic `core/` package (158 files) into focused, cohesive packages.

## Motivation

The `core/` package had grown to 158 files covering disparate concerns:
- Execution runtime and services
- Caching infrastructure
- Distributed computing
- Build graph management
- Query language (bldrquery)
- Telemetry and observability
- Test execution framework

This violated the Single Responsibility Principle and made the codebase harder to navigate and maintain.

## Changes

### New Package Structure

The `core/` package has been eliminated and split into the following top-level packages:

#### 1. `runtime/` (formerly `core/execution/`)
**Purpose**: Execution engine, hermetic execution, and core services

**Contents**:
- `runtime/core/` - Core execution engine
- `runtime/hermetic/` - Hermetic/sandboxed execution
- `runtime/remote/` - Remote execution infrastructure
- `runtime/recovery/` - Execution recovery and retry
- `runtime/services/` - Service interfaces and container
- `runtime/shutdown/` - Graceful shutdown coordination
- `runtime/watchmode/` - Watch mode for incremental builds

**Key Types**: `ExecutionEngine`, `SecureExecutor`, `BuildServices`, `ISchedulingService`, `ICacheService`

#### 2. `caching/` (formerly `core/caching/`)
**Purpose**: All caching infrastructure

**Contents**:
- `caching/actions/` - Action-level caching
- `caching/coordinator/` - Cache coordination
- `caching/distributed/` - Distributed/remote caching
- `caching/storage/` - Content-addressable storage (CAS)
- `caching/targets/` - Target-level caching
- `caching/policies/` - Eviction and retention policies
- `caching/metrics/` - Cache metrics and statistics

**Key Types**: `BuildCache`, `CASStore`, `RemoteCacheClient`

#### 3. `distributed/` (formerly `core/distributed/`)
**Purpose**: Distributed computing and work-stealing

**Contents**:
- `distributed/coordinator/` - Distributed build coordination
- `distributed/worker/` - Worker nodes and execution
- `distributed/protocol/` - Communication protocol
- `distributed/storage/` - Distributed storage
- `distributed/memory/` - Shared memory management
- `distributed/metrics/` - Work-stealing metrics

**Key Types**: `DistributedCoordinator`, `Worker`, `WorkStealingScheduler`

#### 4. `graph/` (formerly `core/graph/`)
**Purpose**: Build dependency graph management

**Contents**:
- Build graph data structure
- Graph traversal and analysis
- Graph caching and persistence

**Key Types**: `BuildGraph`, `BuildNode`, `GraphCache`

#### 5. `query/` (formerly `core/query/`)
**Purpose**: Query language (bldrquery) for exploring build graphs

**Contents**:
- `query/ast.d` - Abstract syntax tree
- `query/lexer.d` - Lexical analysis
- `query/parser.d` - Query parser
- `query/evaluator.d` - Query evaluation
- `query/algorithms.d` - Graph algorithms (deps, rdeps, paths)
- `query/operators.d` - Set operations (union, intersect, except)
- `query/formatter.d` - Output formatting

**Key Functions**: `executeQuery()`, query operators

**Note**: The convenience function `query()` was removed due to a module name conflict. Use `executeQuery()` directly.

#### 6. `telemetry/` (formerly `core/telemetry/`)
**Purpose**: Observability, metrics, and telemetry

**Contents**:
- `telemetry/collection/` - Data collection
- `telemetry/analytics/` - Build analytics
- `telemetry/distributed/` - Distributed tracing
- `telemetry/monitoring/` - Health monitoring
- `telemetry/debugging/` - Debug and replay
- `telemetry/visualization/` - Flamegraphs and visualizations
- `telemetry/persistence/` - Telemetry storage

**Key Types**: `TelemetryCollector`, `Tracer`, `HealthMonitor`

#### 7. `testframework/` (formerly `core/testing/`)
**Purpose**: Test execution framework

**Contents**:
- `testframework/discovery.d` - Test discovery
- `testframework/execution/` - Test execution
- `testframework/reporter.d` - Test reporting
- `testframework/caching/` - Test result caching
- `testframework/sharding/` - Test sharding for parallel execution
- `testframework/flaky/` - Flaky test detection and retry
- `testframework/analytics/` - Test insights

**Key Types**: `TestExecutor`, `TestReporter`, `FlakyTestDetector`

**Note**: Renamed from `testing/` to `testframework/` to avoid confusion with the `tests/` directory.

### Unchanged Packages

The following packages were already well-scoped and remain unchanged:
- `analysis/` - Static analysis and language detection
- `cli/` - Command-line interface
- `config/` - Configuration parsing (Builderfile, Builderspace)
- `errors/` - Error handling and formatting
- `languages/` - Language-specific handlers
- `lsp/` - Language Server Protocol implementation
- `plugins/` - Plugin system
- `tools/` - Development tools
- `utils/` - Cross-cutting utilities

## Migration Guide

### For Developers

If you have code that imports from the old `core` package, update your imports:

```d
// OLD
import core.execution.core.engine;
import core.caching.storage.cas;
import core.graph.graph;
import core.query;
import core.telemetry;
import core.testing;
import core.services;
import core.shutdown;

// NEW
import runtime.core.engine;
import caching.storage.cas;
import graph.graph;
import query;
import telemetry;
import testframework;
import runtime.services;
import runtime.shutdown;
```

### Key Changes

1. **`query()` function removed**: Use `executeQuery()` directly from `query.evaluator`
   ```d
   // OLD
   import query : query;
   auto result = query(expr, graph);
   
   // NEW
   import query : executeQuery;
   auto result = executeQuery(expr, graph);
   ```

2. **Service interfaces**: Now explicitly exported from `runtime.services`
   ```d
   import runtime.services : ISchedulingService, ICacheService, IObservabilityService;
   ```

3. **InputSpec/OutputSpec**: Moved to `distributed.protocol.protocol`
   ```d
   import distributed.protocol.protocol : InputSpec, OutputSpec;
   ```

## Benefits

### 1. **Improved Modularity**
Each package now has a clear, single responsibility. Dependencies between packages are more explicit.

### 2. **Better Navigation**
Developers can quickly find code by domain:
- Need caching code? Look in `caching/`
- Working on distributed builds? Check `distributed/`
- Implementing telemetry? It's in `telemetry/`

### 3. **Clearer Dependencies**
Package dependencies are now more transparent:
- `runtime` depends on `caching`, `distributed`, `graph`, `telemetry`
- `testframework` depends on `runtime`, `caching`
- `query` depends on `graph`

### 4. **Easier Testing**
Smaller, focused packages are easier to unit test in isolation.

### 5. **Scalability**
As the codebase grows, each package can expand independently without bloating a monolithic `core/`.

## Implementation Details

### Refactoring Process

1. **Created new directories**: `runtime/`, `caching/`, `distributed/`, `graph/`, `query/`, `telemetry/`, `testframework/`

2. **Moved subdirectories**:
   - `core/execution/*` → `runtime/`
   - `core/caching/*` → `caching/`
   - `core/distributed/*` → `distributed/`
   - `core/graph/*` → `graph/`
   - `core/query/*` → `query/`
   - `core/telemetry/*` → `telemetry/`
   - `core/testing/*` → `testframework/`
   - `core/services/` → `runtime/services/`
   - `core/shutdown/` → `runtime/shutdown/`

3. **Updated all imports** using `sed`:
   ```bash
   find . -name "*.d" -exec sed -i '' 's/core\.execution\./runtime./g' {} +
   find . -name "*.d" -exec sed -i '' 's/core\.caching\./caching./g' {} +
   find . -name "*.d" -exec sed -i '' 's/core\.distributed\./distributed./g' {} +
   # ... (and so on for all packages)
   ```

4. **Updated module declarations** in moved files

5. **Fixed package.d files** to ensure proper re-exports

### Known Issues

The following pre-existing code issues were surfaced during compilation but are unrelated to the refactoring:
- `errors/formatting/suggestions.d` - Type mismatches in error suggestion generation
- `distributed/worker/sandbox.d` - ExecutionError constructor signature mismatches

These should be addressed in follow-up work.

## Statistics

- **Before**: 1 monolithic package (`core/`) with 158 files
- **After**: 7 focused packages with clear responsibilities
- **Files moved**: ~150 files
- **Imports updated**: ~500+ import statements
- **Module declarations updated**: ~150 module declarations

## Conclusion

This refactoring significantly improves the codebase architecture by replacing a monolithic `core/` package with focused, cohesive packages. The new structure makes the codebase easier to understand, navigate, and maintain.

---

**Date**: November 2, 2024  
**Author**: Architecture refactoring  
**Status**: Complete

