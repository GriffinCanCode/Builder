module infrastructure.telemetry.distributed;

/// Distributed tracing subsystem
/// 
/// This module provides OpenTelemetry-compatible distributed tracing for
/// parallel builds with span tracking and context propagation.
/// 
/// Components:
/// - Tracer: Global trace management
/// - Span: Individual traced operations
/// - SpanExporter: Export traces to various backends

public import infrastructure.telemetry.distributed.tracing;

