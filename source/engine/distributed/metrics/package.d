module engine.distributed.metrics;

/// Metrics and telemetry for distributed builds
/// 
/// Components:
/// - steal.d - Work-stealing metrics
/// 
/// Design:
/// - Low-overhead collection
/// - Thread-safe aggregation
/// - Real-time observability
/// - Histogram-based latencies

public import engine.distributed.metrics.steal;


