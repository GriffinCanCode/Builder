# Telemetry System

Comprehensive build telemetry and observability system for Builder.

## Overview

The telemetry system provides real-time metrics collection, performance analysis, distributed tracing, and debugging capabilities for build processes. It's designed for low-overhead operation with thread-safe components suitable for concurrent builds.

## Architecture

The system is organized into 8 specialized subsystems:

### 1. Collection (`collection/`)

Real-time metrics collection and environment tracking.

**Components:**
- `TelemetryCollector` - Event-driven metrics collection
- `BuildEnvironment` - Environment snapshot for reproducibility
- `BuildSession` - Complete build session metrics

**Features:**
- Subscribes to build events
- Aggregates metrics in real-time
- Captures environment for reproducibility
- Thread-safe with mutex protection

### 2. Persistence (`persistence/`)

High-performance binary storage with retention policies.

**Components:**
- `TelemetryStorage` - Binary storage with versioning
- `TelemetryConfig` - Retention and storage configuration

**Features:**
- Optimized binary format (4-5x faster than JSON)
- Automatic retention policy enforcement
- Thread-safe concurrent access
- Cross-platform compatibility

### 3. Analytics (`analytics/`)

Insights extraction, trends, and regression detection.

**Components:**
- `TelemetryAnalyzer` - Extract insights from build history
- `AnalyticsReport` - Comprehensive analytics reporting
- `TargetAnalytics` - Per-target performance analysis
- `Regression` - Performance regression detection

**Features:**
- Calculate averages, trends, and extremes
- Identify bottlenecks automatically
- Detect performance regressions
- Statistical analysis with std deviation

### 4. Export (`export/`)

Multi-format data export capabilities.

**Components:**
- `TelemetryExporter` - Multi-format data export

**Supported Formats:**
- JSON - Machine-readable structured data
- CSV - Spreadsheet-compatible format
- Summary - Human-readable reports

### 5. Monitoring (`monitoring/`)

Runtime health tracking and checkpoint management.

**Components:**
- `HealthMonitor` - Real-time health tracking
- `HealthCheckpoint` - Point-in-time system snapshot
- `HealthStatus` - System health enumeration

**Features:**
- Real-time health checkpoints
- Memory and worker utilization tracking
- Velocity and throughput metrics
- Build health trends

### 6. Distributed (`distributed/`)

OpenTelemetry-compatible distributed tracing.

**Components:**
- `Tracer` - Global trace management
- `Span` - Individual traced operations
- `TraceContext` - W3C Trace Context propagation
- `SpanExporter` - Export to Jaeger, Zipkin, OTLP

**Features:**
- 128-bit trace IDs
- W3C Trace Context format
- Span attributes and events
- Exception recording
- Multiple exporter backends

### 7. Visualization (`visualization/`)

Performance visualization with flamegraphs.

**Components:**
- `FlameGraphBuilder` - Construct performance flamegraphs
- `FlameNode` - Hierarchical node structure
- `SVGFlameGraphGenerator` - Interactive SVG output

**Features:**
- Hierarchical performance visualization
- SVG generation
- Compatible with flamegraph.pl
- Folded stack format support

### 8. Debugging (`debugging/`)

Build recording and replay for deterministic debugging.

**Components:**
- `BuildRecorder` - Record complete build state
- `ReplayEngine` - Replay recorded builds
- `BuildRecording` - Complete build state snapshot

**Features:**
- Record inputs, outputs, environment
- Deterministic replay
- Time-travel debugging
- Build comparison and diffing

## Usage Examples

### Basic Telemetry Collection

```d
import core.telemetry;

// Initialize
auto collector = new TelemetryCollector();
auto storage = new TelemetryStorage();

// Subscribe to events
eventPublisher.subscribe(collector);

// After build
auto sessionResult = collector.getSession();
if (sessionResult.isOk)
{
    storage.append(sessionResult.unwrap());
}
```

### Analytics and Reporting

```d
import core.telemetry;

auto storage = new TelemetryStorage();
auto sessionsResult = storage.getRecent(10);

if (sessionsResult.isOk)
{
    auto analyzer = TelemetryAnalyzer(sessionsResult.unwrap());
    auto reportResult = analyzer.analyze();
    
    if (reportResult.isOk)
    {
        auto report = reportResult.unwrap();
        writeln("Success Rate: ", report.successRate, "%");
        writeln("Avg Build Time: ", report.avgBuildTime);
        writeln("Cache Hit Rate: ", report.avgCacheHitRate, "%");
    }
}
```

### Distributed Tracing

```d
import core.telemetry;

auto tracer = getTracer();
tracer.startTrace();

auto span = tracer.startSpan("build-target", SpanKind.Internal);
span.setAttribute("target.name", "myapp");

try
{
    // Perform build work
    span.setStatus(SpanStatus.Ok);
}
catch (Exception e)
{
    span.recordException(e);
    span.setStatus(SpanStatus.Error);
}
finally
{
    tracer.finishSpan(span);
}
```

### Health Monitoring

```d
import core.telemetry;

auto monitor = new HealthMonitor(5000); // 5 second intervals
monitor.start();

// During build
monitor.checkpoint(
    completedTasks: 10,
    failedTasks: 0,
    activeTasks: 3,
    pendingTasks: 15,
    workerCount: 4,
    activeWorkers: 3
);

// After build
auto finalCheckpoint = monitor.stop();
writeln(finalCheckpoint.toString());
```

### Flamegraph Generation

```d
import core.telemetry;

auto builder = new FlameGraphBuilder();

// Add build sessions
foreach (session; sessions)
{
    builder.addSession(session);
}

// Generate SVG
auto svgResult = builder.toSVG(1200, 800);
if (svgResult.isOk)
{
    write("flamegraph.svg", svgResult.unwrap());
}
```

### Build Recording and Replay

```d
import core.telemetry;

auto recorder = new BuildRecorder();

// Start recording
recorder.startRecording(args);

// During build
recorder.recordInput("source.d");
recorder.recordOutput("app");

// End recording
auto recordingIdResult = recorder.stopRecording();

// Later: replay
auto engine = new ReplayEngine();
auto replayResult = engine.replay(recordingIdResult.unwrap());
```

## Configuration

### Environment Variables

- `BUILDER_TELEMETRY_ENABLED` - Enable/disable telemetry (default: true)
- `BUILDER_TELEMETRY_MAX_SESSIONS` - Maximum sessions to retain (default: 1000)
- `BUILDER_TELEMETRY_RETENTION_DAYS` - Days to keep data (default: 90)

### Storage Location

By default, telemetry data is stored in:
- `.builder-cache/telemetry/` - Binary telemetry data
- `.builder-cache/traces/` - Distributed traces
- `.builder-cache/recordings/` - Build recordings

## Performance

- **Collection Overhead**: < 1% build time
- **Storage Format**: Binary, 4-5x faster than JSON
- **Memory Usage**: ~10MB per 1000 build sessions
- **Thread Safety**: Lock-free reads, mutex-protected writes

## Thread Safety

All components are designed for thread-safe operation:
- Mutex protection for shared state
- Lock-free context propagation
- Safe concurrent access patterns
- No race conditions in normal operation

## Integration Points

The telemetry system integrates with:
- **Event System** (`cli.events`) - Real-time event subscription
- **Error Handling** (`errors`) - Standardized error types
- **Cache System** (`core.caching`) - Cache hit rate tracking
- **Executor** (`core.execution`) - Build metrics collection
- **File System** (`utils.files`) - File hashing and snapshots

## See Also

- [Implementation Guide](../../docs/implementation/TELEMETRY.md)
- [Observability Overview](../../docs/implementation/OBSERVABILITY.md)
- [Performance Guide](../../docs/implementation/PERFORMANCE.md)

