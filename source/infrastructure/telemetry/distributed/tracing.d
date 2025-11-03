module infrastructure.telemetry.distributed.tracing;

import std.datetime : SysTime, Clock, Duration, dur;
import std.conv : to;
import std.random : uniform;
import std.format : format;
import std.array : appender;
import std.json : JSONValue;
import core.sync.mutex : Mutex;
import core.thread : Thread;
import infrastructure.errors;

/// Distributed tracing system following OpenTelemetry patterns
/// Provides observability for parallel builds with span tracking and context propagation
/// 
/// Architecture:
/// - Span: Represents a single operation (target build, dependency resolution, etc.)
/// - TraceContext: Propagates trace identity across threads
/// - SpanExporter: Outputs traces to various backends (Jaeger, Zipkin, OTLP)
/// 
/// Thread Safety:
/// - All components use mutex protection for thread-safe operation
/// - Spans can be created and finished from different threads
/// - Context propagation is lock-free using thread-local storage

/// Unique identifier for traces (128-bit)
struct TraceId
{
    ulong high;
    ulong low;
    
    /// Generate random trace ID
    static TraceId generate() @system
    {
        TraceId id;
        id.high = uniform!ulong();
        id.low = uniform!ulong();
        return id;
    }
    
    /// Convert to hex string (32 characters)
    string toString() const pure @system
    {
        return format("%016x%016x", high, low);
    }
    
    /// Parse from hex string
    static Result!(TraceId, TraceError) parse(string str) pure @system
    {
        import std.conv : ConvException;
        import std.string : strip;
        import std.algorithm : startsWith;
        
        try
        {
            auto stripped = str.strip();
            if (stripped.length != 32)
                return Result!(TraceId, TraceError).err(
                    TraceError.invalidFormat("TraceId must be 32 hex characters"));
            
            TraceId id;
            import std.conv : parse;
            
            auto highStr = stripped[0..16];
            auto lowStr = stripped[16..32];
            
            id.high = parse!ulong(highStr, 16);
            id.low = parse!ulong(lowStr, 16);
            
            return Result!(TraceId, TraceError).ok(id);
        }
        catch (ConvException e)
        {
            return Result!(TraceId, TraceError).err(
                TraceError.invalidFormat("Invalid hex string: " ~ e.msg));
        }
    }
}

/// Unique identifier for spans (64-bit)
struct SpanId
{
    ulong value;
    
    /// Generate random span ID
    static SpanId generate() @system
    {
        SpanId id;
        id.value = uniform!ulong();
        return id;
    }
    
    /// Convert to hex string (16 characters)
    string toString() const pure @system
    {
        return format("%016x", value);
    }
    
    /// Parse from hex string
    static Result!(SpanId, TraceError) parse(string str) pure @system
    {
        import std.conv : ConvException, parse;
        import std.string : strip;
        
        try
        {
            auto stripped = str.strip();
            if (stripped.length != 16)
                return Result!(SpanId, TraceError).err(
                    TraceError.invalidFormat("SpanId must be 16 hex characters"));
            
            SpanId id;
            id.value = parse!ulong(stripped, 16);
            
            return Result!(SpanId, TraceError).ok(id);
        }
        catch (ConvException e)
        {
            return Result!(SpanId, TraceError).err(
                TraceError.invalidFormat("Invalid hex string: " ~ e.msg));
        }
    }
}

/// Span represents a single traced operation
final class Span
{
    private TraceId traceId;
    private SpanId spanId;
    private SpanId parentSpanId;
    private string name;
    private SpanKind kind;
    private SysTime startTime;
    private SysTime endTime;
    private Duration duration;
    private SpanStatus status;
    private string[string] attributes;
    private SpanEvent[] events;
    private bool finished;
    private Mutex spanMutex;
    
    this(TraceId traceId, SpanId spanId, SpanId parentSpanId, string name, SpanKind kind) @system
    {
        this.traceId = traceId;
        this.spanId = spanId;
        this.parentSpanId = parentSpanId;
        this.name = name;
        this.kind = kind;
        this.startTime = Clock.currTime();
        this.status = SpanStatus.Unset;
        this.finished = false;
        this.spanMutex = new Mutex();
    }
    
    /// Set attribute on span (key-value metadata)
    void setAttribute(string key, string value) @system
    {
        synchronized (spanMutex)
        {
            attributes[key] = value;
        }
    }
    
    /// Add event to span (timestamped log entry)
    void addEvent(string name, string[string] attrs = null) @system
    {
        synchronized (spanMutex)
        {
            SpanEvent event;
            event.name = name;
            event.timestamp = Clock.currTime();
            event.attributes = attrs;
            events ~= event;
        }
    }
    
    /// Set span status
    void setStatus(SpanStatus status, string description = "") @system
    {
        synchronized (spanMutex)
        {
            this.status = status;
            if (description.length > 0)
                this.attributes["status.description"] = description;
        }
    }
    
    /// Record exception in span
    void recordException(Exception e) @system
    {
        synchronized (spanMutex)
        {
            this.status = SpanStatus.Error;
            this.attributes["exception.type"] = typeid(e).toString();
            this.attributes["exception.message"] = e.msg;
            
            // Add exception event
            string[string] attrs;
            attrs["exception.type"] = typeid(e).toString();
            attrs["exception.message"] = e.msg;
            
            SpanEvent event;
            event.name = "exception";
            event.timestamp = Clock.currTime();
            event.attributes = attrs;
            events ~= event;
        }
    }
    
    /// Finish span (stops timing)
    void finish() @system
    {
        synchronized (spanMutex)
        {
            if (finished)
                return;
            
            this.endTime = Clock.currTime();
            this.duration = this.endTime - this.startTime;
            this.finished = true;
            
            // Auto-set status to OK if unset
            if (this.status == SpanStatus.Unset)
                this.status = SpanStatus.Ok;
        }
    }
    
    /// Get span data for export
    @property SpanData data() const @system
    {
        synchronized (cast(Mutex)spanMutex)
        {
            SpanData data;
            data.traceId = this.traceId;
            data.spanId = this.spanId;
            data.parentSpanId = this.parentSpanId;
            data.name = this.name;
            data.kind = this.kind;
            data.startTime = this.startTime;
            data.endTime = this.endTime;
            data.duration = this.duration;
            data.status = this.status;
            
            // Duplicate associative array
            foreach (key, value; this.attributes)
            {
                data.attributes[key] = value;
            }
            
            // Duplicate events array
            foreach (event; this.events)
            {
                SpanEvent newEvent;
                newEvent.name = event.name;
                newEvent.timestamp = event.timestamp;
                foreach (k, v; event.attributes)
                {
                    newEvent.attributes[k] = v;
                }
                data.events ~= newEvent;
            }
            data.finished = this.finished;
            return data;
        }
    }
    
    /// Accessors
    @property TraceId trace() const pure nothrow @system @nogc { return traceId; }
    @property SpanId id() const pure nothrow @system @nogc { return spanId; }
    @property SpanId parent() const pure nothrow @system @nogc { return parentSpanId; }
    @property bool isFinished() const @system
    {
        synchronized (cast(Mutex)spanMutex)
        {
            return finished;
        }
    }
}

/// Immutable span data for export
struct SpanData
{
    TraceId traceId;
    SpanId spanId;
    SpanId parentSpanId;
    string name;
    SpanKind kind;
    SysTime startTime;
    SysTime endTime;
    Duration duration;
    SpanStatus status;
    string[string] attributes;
    SpanEvent[] events;
    bool finished;
}

/// Span event (timestamped log entry within a span)
struct SpanEvent
{
    string name;
    SysTime timestamp;
    string[string] attributes;
}

/// Span kind (type of operation)
enum SpanKind
{
    Internal,    // Internal operation
    Server,      // Server request
    Client,      // Client request
    Producer,    // Message producer
    Consumer     // Message consumer
}

/// Span status
enum SpanStatus
{
    Unset,       // Not set
    Ok,          // Success
    Error        // Error occurred
}

/// Trace context for propagation across threads
struct TraceContext
{
    TraceId traceId;
    SpanId spanId;
    bool sampled;
    
    /// Serialize to W3C Trace Context format (traceparent header)
    string toTraceparent() const pure @system
    {
        immutable sampledFlag = sampled ? "01" : "00";
        return format("00-%s-%s-%s", traceId.toString(), spanId.toString(), sampledFlag);
    }
    
    /// Parse from W3C Trace Context format
    static Result!(TraceContext, TraceError) fromTraceparent(string header) pure @system
    {
        import std.string : split, strip;
        
        auto parts = header.strip().split("-");
        if (parts.length != 4)
            return Result!(TraceContext, TraceError).err(
                TraceError.invalidFormat("Invalid traceparent format"));
        
        if (parts[0] != "00")
            return Result!(TraceContext, TraceError).err(
                TraceError.invalidFormat("Unsupported trace version: " ~ parts[0]));
        
        auto traceResult = TraceId.parse(parts[1]);
        if (traceResult.isErr)
        {
            auto err = traceResult.unwrapErr();
            return Result!(TraceContext, TraceError).err(err);
        }
        
        auto spanResult = SpanId.parse(parts[2]);
        if (spanResult.isErr)
        {
            auto err = spanResult.unwrapErr();
            return Result!(TraceContext, TraceError).err(err);
        }
        
        TraceContext ctx;
        ctx.traceId = traceResult.unwrap();
        ctx.spanId = spanResult.unwrap();
        ctx.sampled = parts[3] == "01";
        
        return Result!(TraceContext, TraceError).ok(ctx);
    }
}

/// Global tracer instance
final class Tracer
{
    private TraceId currentTraceId;
    private Span[] activeSpans;
    private SpanData[] completedSpans;
    private Mutex tracerMutex;
    private SpanExporter exporter;
    private bool enabled;
    
    this(SpanExporter exporter = null) @system
    {
        this.tracerMutex = new Mutex();
        this.exporter = exporter;
        this.enabled = true;
    }
    
    /// Start new trace
    void startTrace() @system
    {
        synchronized (tracerMutex)
        {
            this.currentTraceId = TraceId.generate();
        }
    }
    
    /// Start a new span
    Span startSpan(string name, SpanKind kind = SpanKind.Internal, Span parent = null) @system
    {
        if (!enabled)
            return null;
        
        synchronized (tracerMutex)
        {
            immutable traceId = parent !is null ? parent.trace : currentTraceId;
            immutable parentId = parent !is null ? parent.id : SpanId(0);
            immutable spanId = SpanId.generate();
            
            auto span = new Span(traceId, spanId, parentId, name, kind);
            activeSpans ~= span;
            
            return span;
        }
    }
    
    /// Finish a span and export it
    void finishSpan(Span span) @system
    {
        if (span is null || !enabled)
            return;
        
        span.finish();
        
        synchronized (tracerMutex)
        {
            // Move to completed
            import std.algorithm : remove;
            import std.array : array;
            
            activeSpans = activeSpans.remove!(s => s is span).array;
            completedSpans ~= span.data;
            
            // Export if exporter configured
            if (exporter !is null)
            {
                exporter.exportSpan(span.data);
            }
        }
    }
    
    /// Get current trace context
    Result!(TraceContext, TraceError) currentContext() @system
    {
        synchronized (tracerMutex)
        {
            if (activeSpans.length == 0)
                return Result!(TraceContext, TraceError).err(
                    TraceError.noActiveSpan());
            
            auto span = activeSpans[$ - 1];
            TraceContext ctx;
            ctx.traceId = span.trace;
            ctx.spanId = span.id;
            ctx.sampled = true;
            
            return Result!(TraceContext, TraceError).ok(ctx);
        }
    }
    
    /// Flush all completed spans
    void flush() @system
    {
        synchronized (tracerMutex)
        {
            if (exporter !is null)
            {
                exporter.flush(completedSpans);
            }
            completedSpans = [];
        }
    }
    
    /// Enable/disable tracing
    void setEnabled(bool enabled) @system
    {
        synchronized (tracerMutex)
        {
            this.enabled = enabled;
        }
    }
    
    /// Get all completed spans
    SpanData[] getCompletedSpans() const @system
    {
        synchronized (cast(Mutex)tracerMutex)
        {
            // Manually copy to avoid const issues
            import std.array : appender;
            auto result = appender!(SpanData[]);
            result.reserve(completedSpans.length);
            foreach (span; completedSpans)
            {
                result ~= span;
            }
            return result.data;
        }
    }
}

/// Span exporter interface
interface SpanExporter
{
    void exportSpan(SpanData span);
    void flush(SpanData[] spans);
}

/// Console exporter for debugging
final class ConsoleSpanExporter : SpanExporter
{
    void exportSpan(SpanData span) @system
    {
        import std.stdio : writeln;
        
        writeln("TRACE: ", span.traceId.toString());
        writeln("  Span: ", span.name, " [", span.spanId.toString(), "]");
        if (span.parentSpanId.value != 0)
            writeln("  Parent: ", span.parentSpanId.toString());
        writeln("  Duration: ", span.duration.total!"msecs", "ms");
        writeln("  Status: ", span.status);
        
        if (span.attributes.length > 0)
        {
            writeln("  Attributes:");
            foreach (key, value; span.attributes)
            {
                writeln("    ", key, ": ", value);
            }
        }
        
        if (span.events.length > 0)
        {
            writeln("  Events:");
            foreach (event; span.events)
            {
                writeln("    [", event.timestamp.toISOExtString(), "] ", event.name);
            }
        }
    }
    
    void flush(SpanData[] spans) @system
    {
        import std.stdio : writeln;
        writeln("Flushing ", spans.length, " spans");
    }
}

/// Jaeger JSON exporter
final class JaegerSpanExporter : SpanExporter
{
    private string outputFile;
    private Mutex exportMutex;
    
    this(string outputFile = ".builder-cache/traces/jaeger.json") @system
    {
        this.outputFile = outputFile;
        this.exportMutex = new Mutex();
        
        // Ensure directory exists
        import std.file : exists, mkdirRecurse;
        import std.path : dirName;
        
        auto dir = dirName(outputFile);
        if (!exists(dir))
            mkdirRecurse(dir);
    }
    
    void exportSpan(SpanData span) @system
    {
        synchronized (exportMutex)
        {
            // Append to file
            import std.stdio : File;
            import std.json : JSONValue;
            
            auto json = spanToJaegerJson(span);
            
            auto file = File(outputFile, "a");
            file.writeln(json.toString());
            file.close();
        }
    }
    
    void flush(SpanData[] spans) @system
    {
        // Jaeger format flushes immediately
    }
    
    private JSONValue spanToJaegerJson(SpanData span) const @system
    {
        JSONValue json;
        json["traceID"] = span.traceId.toString();
        json["spanID"] = span.spanId.toString();
        json["operationName"] = span.name;
        json["startTime"] = span.startTime.stdTime / 10; // microseconds
        json["duration"] = span.duration.total!"usecs";
        
        if (span.parentSpanId.value != 0)
        {
            JSONValue[] refs;
            JSONValue ref_;
            ref_["refType"] = "CHILD_OF";
            ref_["traceID"] = span.traceId.toString();
            ref_["spanID"] = span.parentSpanId.toString();
            refs ~= ref_;
            json["references"] = refs;
        }
        
        // Attributes as tags
        JSONValue[] tags;
        foreach (key, value; span.attributes)
        {
            JSONValue tag;
            tag["key"] = key;
            tag["value"] = value;
            tag["type"] = "string";
            tags ~= tag;
        }
        json["tags"] = tags;
        
        // Events as logs
        JSONValue[] logs;
        foreach (event; span.events)
        {
            JSONValue log;
            log["timestamp"] = event.timestamp.stdTime / 10; // microseconds
            
            JSONValue[] fields;
            JSONValue eventField;
            eventField["key"] = "event";
            eventField["value"] = event.name;
            fields ~= eventField;
            
            foreach (key, value; event.attributes)
            {
                JSONValue field;
                field["key"] = key;
                field["value"] = value;
                fields ~= field;
            }
            
            log["fields"] = fields;
            logs ~= log;
        }
        json["logs"] = logs;
        
        return json;
    }
}

/// Trace-specific errors
struct TraceError
{
    string message;
    ErrorCode code;
    
    static TraceError invalidFormat(string details) pure @system
    {
        return TraceError("Invalid format: " ~ details, ErrorCode.TraceInvalidFormat);
    }
    
    static TraceError noActiveSpan() pure @system
    {
        return TraceError("No active span", ErrorCode.TraceNoActiveSpan);
    }
    
    static TraceError exportFailed(string details) pure @system
    {
        return TraceError("Export failed: " ~ details, ErrorCode.TraceExportFailed);
    }
    
    string toString() const pure nothrow @system
    {
        return message;
    }
}

/// Global tracer instance
private Tracer globalTracer;

/// Get global tracer
Tracer getTracer() @system
{
    if (globalTracer is null)
    {
        // Initialize with Jaeger exporter by default
        auto exporter = new JaegerSpanExporter();
        globalTracer = new Tracer(exporter);
    }
    return globalTracer;
}

/// Set custom tracer
void setTracer(Tracer tracer) @system
{
    globalTracer = tracer;
}

