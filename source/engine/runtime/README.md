# Execution System

The execution system provides the complete build execution infrastructure for Builder.

## Architecture

The execution system is organized into modular subdirectories, each with a specific responsibility:

### `core/`
Main execution engine that orchestrates the build process.

- **engine.d**: `ExecutionEngine` - Main orchestrator that composes services to execute build graphs
  - Coordinates parallel task execution
  - Manages build lifecycle
  - Integrates with all service layers

### `services/`
Modular service architecture with well-defined interfaces.

- **scheduling.d**: Task scheduling and parallelism (thread pool, work-stealing)
- **cache.d**: Unified caching layer (build cache, action cache, remote cache)
- **observability.d**: Events, tracing, and structured logging
- **resilience.d**: Retry logic and checkpoint/resume coordination
- **registry.d**: Language handler registry and lifecycle management
- **package.d**: Exports all service interfaces

### `watchmode/`
Continuous file watching and incremental builds.

- **watch.d**: `WatchModeService` - File watching and automatic rebuild orchestration
  - Debounced file change detection
  - Incremental rebuild triggering
  - Build statistics tracking

### `recovery/`
Build checkpoint/resume and retry logic for resilient builds.

- **checkpoint.d**: `CheckpointManager`, `Checkpoint` - Persists build state to disk
- **resume.d**: `ResumePlanner`, `ResumePlan` - Smart resume strategies
- **retry.d**: `RetryOrchestrator`, `RetryPolicy` - Configurable retry with exponential backoff

## Design Principles

### 1. Separation of Concerns
Each subdirectory has a single, well-defined responsibility. The execution engine coordinates but delegates all work to specialized services.

### 2. Interface-Based Design
All services implement clean interfaces (`ISchedulingService`, `ICacheService`, etc.) enabling:
- Easy testing with mock implementations
- Alternative implementations
- Clear contracts

### 3. Composability
Services are independent and composable. The engine wires them together at construction time.

### 4. Zero Global State
No global singletons or mutable state. All state is explicit and passed through interfaces.

## Usage

### Basic Build Execution

```d
import core.execution;

// Create services
auto scheduling = new SchedulingService();
auto cache = new CacheService();
auto observability = new ObservabilityService();
auto resilience = new ResilienceService();
auto handlers = new HandlerRegistry();

// Create and execute engine
auto engine = new ExecutionEngine(
    graph, config,
    scheduling, cache, observability, resilience, handlers
);

bool success = engine.execute();
engine.shutdown();
```

### Watch Mode

```d
import core.execution.watchmode;

auto config = WatchModeConfig();
config.debounceDelay = 300.msecs;
config.clearScreen = true;

auto watcher = new WatchModeService(workspaceRoot, config);
watcher.start(); // Blocks until interrupted
```

### Checkpoint/Resume

```d
import core.execution.recovery;

// Save checkpoint
auto manager = new CheckpointManager(workspaceRoot);
auto checkpoint = manager.capture(graph);
manager.save(checkpoint);

// Resume from checkpoint
auto planner = new ResumePlanner();
auto loadResult = manager.load();
if (loadResult.isOk)
{
    auto checkpoint = loadResult.unwrap();
    auto planResult = planner.plan(checkpoint, graph);
    // Execute based on plan...
}
```

### Retry with Custom Policy

```d
import core.execution.recovery;

auto orchestrator = new RetryOrchestrator();

// Register custom policy for specific error
orchestrator.registerPolicy(
    ErrorCode.ProcessTimeout,
    RetryPolicy(5, 200.msecs, 60.seconds, 2.0, 0.15, true)
);

// Execute with retry
auto result = orchestrator.withRetry(
    "target-id",
    () => performBuild(),
    policy
);
```

## Module Organization

```
core/execution/
├── package.d              # Root exports
├── README.md              # This file
├── core/                  # Main engine
│   ├── package.d
│   └── engine.d
├── services/              # Service layer
│   ├── package.d
│   ├── scheduling.d
│   ├── cache.d
│   ├── observability.d
│   ├── resilience.d
│   └── registry.d
├── watchmode/             # File watching
│   ├── package.d
│   └── watch.d
└── recovery/              # Checkpoint/resume
    ├── package.d
    ├── checkpoint.d
    ├── resume.d
    └── retry.d
```

## Testing

Each subdirectory can be tested independently:

- **Core**: Test engine coordination logic with mock services
- **Services**: Test each service implementation in isolation
- **Watch Mode**: Test file change detection and rebuild triggering
- **Recovery**: Test checkpoint persistence and resume planning

## Future Enhancements

- Distributed builds (remote execution)
- Advanced scheduling strategies (critical path, resource-aware)
- Predictive caching (ML-based)
- Cloud checkpoint storage
- Real-time build analytics

