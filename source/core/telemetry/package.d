module core.telemetry;

/// Build telemetry system for performance analysis and optimization
/// 
/// Architecture:
/// - Collector: Subscribes to build events, aggregates metrics in real-time
/// - Storage: Persists telemetry data in optimized binary format
/// - Analysis: Extracts insights, detects trends and regressions
/// - Export: Outputs data in multiple formats (JSON, CSV, summary)
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

public import core.telemetry.collector;
public import core.telemetry.storage;
public import core.telemetry.analysis;
public import core.telemetry.exporter;

