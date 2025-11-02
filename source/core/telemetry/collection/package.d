module core.telemetry.collection;

/// Data collection subsystem
/// 
/// This module provides real-time collection of build metrics and environment
/// information for reproducibility and performance analysis.
/// 
/// Components:
/// - TelemetryCollector: Event-driven metrics collection
/// - BuildEnvironment: Environment snapshot for reproducibility

public import core.telemetry.collection.collector;
public import core.telemetry.collection.environment;

