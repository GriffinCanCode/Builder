module infrastructure.telemetry;

/// Build telemetry system for performance analysis and optimization
/// 
/// Architecture:
/// - Collection: Real-time metrics collection and environment tracking
/// - Persistence: High-performance binary storage with retention policies
/// - Analytics: Insights extraction, trends, and regression detection
/// - Export: Multi-format data export (JSON, CSV, summaries)
/// - Monitoring: Runtime health tracking and checkpoint management
/// - Distributed: OpenTelemetry-compatible tracing for parallel builds
/// - Visualization: Flamegraph generation for performance profiling
/// - Debugging: Build recording/replay for deterministic debugging
/// 
/// Thread Safety:
/// - All components are thread-safe with mutex protection
/// - Safe for concurrent access from build executor
/// 
/// Performance:
/// - Binary storage format: 4-5x faster than JSON
/// - Efficient aggregation with minimal overhead
/// - Lazy persistence to avoid I/O bottlenecks
/// 
/// Usage Example:
/// ---
/// // Initialize telemetry
/// auto collector = new TelemetryCollector();
/// auto storage = new TelemetryStorage();
/// 
/// // Subscribe to build events
/// eventPublisher.subscribe(collector);
/// 
/// // After build completes
/// auto sessionResult = collector.getSession();
/// if (sessionResult.isOk)
/// {
///     auto session = sessionResult.unwrap();
///     storage.append(session);
///     
///     // Analyze recent builds
///     auto recentResult = storage.getRecent(10);
///     if (recentResult.isOk)
///     {
///         auto analyzer = TelemetryAnalyzer(recentResult.unwrap());
///         auto reportResult = analyzer.analyze();
///         
///         if (reportResult.isOk)
///         {
///             auto report = reportResult.unwrap();
///             writeln(TelemetryExporter.toSummary(report).unwrap());
///         }
///     }
/// }
/// ---

// Data Collection
public import infrastructure.telemetry.collection;

// Data Persistence
public import infrastructure.telemetry.persistence;

// Data Analytics
public import infrastructure.telemetry.analytics;

// Data Export
public import infrastructure.telemetry.exporting;

// Runtime Monitoring
public import infrastructure.telemetry.monitoring;

// Distributed Tracing
public import infrastructure.telemetry.distributed;

// Visualization
public import infrastructure.telemetry.visualization;

// Debugging
public import infrastructure.telemetry.debugging;

