module engine.runtime.services.observability;

import frontend.cli.events.events;
import infrastructure.telemetry.distributed.tracing : Tracer, Span, SpanKind, SpanStatus, getTracer, setTracer;
import infrastructure.utils.logging.structured : StructuredLogger, LogLevel, getStructuredLogger, setStructuredLogger;
import infrastructure.errors;

/// Observability service interface
/// Unifies events, tracing, and structured logging behind single interface
interface IObservabilityService
{
    /// Publish a build event
    void publishEvent(BuildEvent event);
    
    /// Start a new span for distributed tracing
    Span startSpan(string name, SpanKind kind, Span parent = null);
    
    /// Finish a span
    void finishSpan(Span span);
    
    /// Log info message with optional structured fields
    void logInfo(string message, string[string] fields = null);
    
    /// Log debug message
    void logDebug(string message, string[string] fields = null);
    
    /// Log error message
    void logError(string message, string[string] fields = null);
    
    /// Log exception
    void logException(Exception e, string message = "");
    
    /// Flush all observability outputs
    void flush();
    
    /// Start a new distributed trace
    void startTrace();
    
    /// Set span status
    void setSpanStatus(Span span, SpanStatus status, string description = "");
    
    /// Record exception on span
    void recordException(Span span, Exception e);
    
    /// Add event to span
    void addSpanEvent(Span span, string name, string[string] attributes = null);
    
    /// Set span attribute
    void setSpanAttribute(Span span, string key, string value);
}

/// Concrete observability service implementation
final class ObservabilityService : IObservabilityService
{
    private EventPublisher eventPublisher;
    private Tracer tracer;
    private StructuredLogger structuredLogger;
    
    this(EventPublisher eventPublisher = null, 
         Tracer tracer = null,
         StructuredLogger structuredLogger = null)
    {
        // Use provided or get globals
        this.eventPublisher = eventPublisher;
        this.tracer = tracer is null ? getTracer() : tracer;
        this.structuredLogger = structuredLogger is null ? getStructuredLogger() : structuredLogger;
        
        // Set as globals if provided
        if (tracer !is null)
            setTracer(tracer);
        if (structuredLogger !is null)
            setStructuredLogger(structuredLogger);
    }
    
    void publishEvent(BuildEvent event) @trusted
    {
        if (eventPublisher !is null)
        {
            eventPublisher.publish(event);
        }
    }
    
    Span startSpan(string name, SpanKind kind, Span parent = null) @trusted
    {
        return tracer.startSpan(name, kind, parent);
    }
    
    void finishSpan(Span span) @trusted
    {
        tracer.finishSpan(span);
    }
    
    void logInfo(string message, string[string] fields = null) @trusted
    {
        if (fields !is null)
            structuredLogger.info(message, fields);
        else
        {
            string[string] empty;
            structuredLogger.info(message, empty);
        }
    }
    
    void logDebug(string message, string[string] fields = null) @trusted
    {
        if (fields !is null)
            structuredLogger.debug_(message, fields);
        else
        {
            string[string] empty;
            structuredLogger.debug_(message, empty);
        }
    }
    
    void logError(string message, string[string] fields = null) @trusted
    {
        if (fields !is null)
            structuredLogger.error(message, fields);
        else
        {
            string[string] empty;
            structuredLogger.error(message, empty);
        }
    }
    
    void logException(Exception e, string message = "") @trusted
    {
        structuredLogger.exception(e, message);
    }
    
    void flush() @trusted
    {
        tracer.flush();
    }
    
    void startTrace() @trusted
    {
        tracer.startTrace();
    }
    
    void setSpanStatus(Span span, SpanStatus status, string description = "") @trusted
    {
        span.setStatus(status, description);
    }
    
    void recordException(Span span, Exception e) @trusted
    {
        span.recordException(e);
    }
    
    void addSpanEvent(Span span, string name, string[string] attributes = null) @trusted
    {
        if (attributes !is null)
            span.addEvent(name, attributes);
        else
            span.addEvent(name);
    }
    
    void setSpanAttribute(Span span, string key, string value) @trusted
    {
        span.setAttribute(key, value);
    }
}

/// Null observability service for testing/disabled observability
final class NullObservabilityService : IObservabilityService
{
    private static Span nullSpan;
    
    shared static this()
    {
        import telemetry.distributed.tracing : TraceId, SpanId;
        // Create a null span that does nothing
        nullSpan = new Span(TraceId(), SpanId(), SpanId(), "null", SpanKind.Internal);
    }
    
    void publishEvent(BuildEvent event) @trusted { }
    Span startSpan(string name, SpanKind kind, Span parent = null) @trusted { return nullSpan; }
    void finishSpan(Span span) @trusted { }
    void logInfo(string message, string[string] fields = null) @trusted { }
    void logDebug(string message, string[string] fields = null) @trusted { }
    void logError(string message, string[string] fields = null) @trusted { }
    void logException(Exception e, string message = "") @trusted { }
    void flush() @trusted { }
    void startTrace() @trusted { }
    void setSpanStatus(Span span, SpanStatus status, string description = "") @trusted { }
    void recordException(Span span, Exception e) @trusted { }
    void addSpanEvent(Span span, string name, string[string] attributes = null) @trusted { }
    void setSpanAttribute(Span span, string key, string value) @trusted { }
}

