#!/usr/bin/env dub
/+ dub.sdl:
name "observability-example"
dependency "builder" path="../../"
+/

/// Example demonstrating Builder's observability features
/// 
/// This example shows how to use:
/// - Distributed tracing
/// - Structured logging
/// - Flamegraph generation
/// - Build replay
module observability_example;

import std.stdio;
import std.datetime.stopwatch;
import core.telemetry;
import utils.logging.structured;

void main()
{
    writeln("=== Builder Observability Example ===\n");
    
    // 1. Distributed Tracing Example
    distributedTracingExample();
    
    // 2. Structured Logging Example
    structuredLoggingExample();
    
    // 3. Flamegraph Example
    flamegraphExample();
    
    // 4. Build Replay Example
    replayExample();
    
    writeln("\n=== Example Complete ===");
}

/// Example 1: Distributed Tracing
void distributedTracingExample()
{
    writeln("1. Distributed Tracing Example");
    writeln("--------------------------------");
    
    // Get tracer
    auto tracer = getTracer();
    tracer.startTrace();
    
    // Create root span
    auto buildSpan = tracer.startSpan("example-build");
    buildSpan.setAttribute("project", "my-app");
    buildSpan.setAttribute("version", "1.0.0");
    
    // Simulate build phases
    {
        auto compileSpan = tracer.startSpan("compile", SpanKind.Internal, buildSpan);
        compileSpan.setAttribute("language", "D");
        
        writeln("  Compiling...");
        simulateWork(100); // 100ms
        
        compileSpan.addEvent("sources-compiled", ["count": "42"]);
        tracer.finishSpan(compileSpan);
    }
    
    {
        auto linkSpan = tracer.startSpan("link", SpanKind.Internal, buildSpan);
        
        writeln("  Linking...");
        simulateWork(50); // 50ms
        
        tracer.finishSpan(linkSpan);
    }
    
    buildSpan.setStatus(SpanStatus.Ok);
    tracer.finishSpan(buildSpan);
    
    // Get trace context
    auto ctxResult = tracer.currentContext();
    if (ctxResult.isOk)
    {
        auto ctx = ctxResult.unwrap();
        writefln("  Trace ID: %s", ctx.traceId.toString());
        writefln("  Traceparent: %s", ctx.toTraceparent());
    }
    
    writeln("  ✓ Traces exported to .builder-cache/traces/\n");
}

/// Example 2: Structured Logging
void structuredLoggingExample()
{
    writeln("2. Structured Logging Example");
    writeln("--------------------------------");
    
    auto logger = getStructuredLogger();
    
    // Set context for this thread
    LogContext ctx;
    ctx.targetId = "//example:app";
    ctx.correlationId = "build-12345";
    ctx.fields["worker"] = "main";
    setLogContext(ctx);
    
    // Log with structured fields
    logger.info("Build started");
    
    string[string] fields;
    fields["sources"] = "42";
    fields["language"] = "D";
    logger.info("Compiling sources", fields);
    
    // Simulate work with progress logging
    for (int i = 0; i < 3; i++)
    {
        fields["progress"] = (i * 33).to!string ~ "%";
        logger.debug_("Compilation progress", fields);
        simulateWork(30);
    }
    
    fields["duration_ms"] = "100";
    logger.info("Compilation complete", fields);
    
    // Use scoped context
    {
        auto scopedCtx = ScopedLogContext("//example:tests");
        logger.info("Running tests");
        logger.warning("Test flaky_test is unstable");
    }
    
    // Get statistics
    auto stats = logger.getStats();
    writefln("  Log statistics:");
    writefln("    Total entries: %d", stats.totalEntries);
    writefln("    Info: %d, Warning: %d, Error: %d", 
             stats.infoCount, stats.warningCount, stats.errorCount);
    writefln("    Targets logged: %d", stats.targetsLogged);
    
    writeln("  ✓ Logs buffered and ready for export\n");
}

/// Example 3: Flamegraph Generation
void flamegraphExample()
{
    writeln("3. Flamegraph Generation Example");
    writeln("--------------------------------");
    
    import std.datetime : dur;
    
    // Create sample build data
    auto builder = new FlameGraphBuilder();
    
    // Add stack samples (simulating build hierarchy)
    builder.addStackSample("build;frontend;compile;typescript", dur!"msecs"(1200));
    builder.addStackSample("build;frontend;compile;jsx", dur!"msecs"(800));
    builder.addStackSample("build;frontend;bundle;webpack", dur!"msecs"(2500));
    
    builder.addStackSample("build;backend;compile;rust", dur!"msecs"(3200));
    builder.addStackSample("build;backend;link", dur!"msecs"(450));
    builder.addStackSample("build;backend;test", dur!"msecs"(1100));
    
    builder.addStackSample("build;shared;proto;generate", dur!"msecs"(600));
    
    // Get statistics
    auto stats = builder.getStats();
    writefln("  Flamegraph statistics:");
    writefln("    Total samples: %d", stats.totalSamples);
    writefln("    Total duration: %d ms", stats.totalDuration.total!"msecs");
    writefln("    Unique frames: %d", stats.uniqueFrames);
    writefln("    Max depth: %d", stats.maxDepth);
    
    // Export as folded stacks
    auto stacksResult = builder.toFoldedStacks();
    if (stacksResult.isOk)
    {
        writeln("\n  Folded stacks format:");
        writeln("  " ~ stacksResult.unwrap().split("\n")[0..3].join("\n  "));
    }
    
    // Generate SVG
    auto svgResult = builder.toSVG(800, 600);
    if (svgResult.isOk)
    {
        import std.file : write, exists, mkdirRecurse;
        
        if (!exists(".builder-cache/examples"))
            mkdirRecurse(".builder-cache/examples");
        
        write(".builder-cache/examples/flamegraph.svg", svgResult.unwrap());
        writeln("\n  ✓ Flamegraph saved to .builder-cache/examples/flamegraph.svg");
        writeln("    Open in browser to view interactive visualization\n");
    }
}

/// Example 4: Build Replay
void replayExample()
{
    writeln("4. Build Replay Example");
    writeln("--------------------------------");
    
    import std.file : exists, mkdirRecurse;
    
    // Ensure directory exists
    if (!exists(".builder-cache/recordings"))
        mkdirRecurse(".builder-cache/recordings");
    
    auto recorder = getRecorder();
    
    // Start recording
    recorder.startRecording(["example", "app"]);
    
    writeln("  Recording build...");
    
    // Simulate recording inputs
    recorder.addMetadata("project", "example-app");
    recorder.addMetadata("commit", "abc123");
    recorder.addMetadata("branch", "main");
    
    // Simulate build work
    simulateWork(200);
    
    // Stop and save recording
    auto idResult = recorder.stopRecording();
    if (idResult.isOk)
    {
        auto recordingId = idResult.unwrap();
        writefln("  ✓ Recording saved: %s", recordingId);
        
        // List recordings
        auto engine = new ReplayEngine();
        auto listResult = engine.listRecordings();
        
        if (listResult.isOk)
        {
            auto recordings = listResult.unwrap();
            writefln("\n  Available recordings: %d", recordings.length);
            
            foreach (info; recordings)
            {
                writefln("    - %s [%s]", 
                         info.recordingId,
                         info.timestamp.toISOExtString()[0..19]);
            }
        }
        
        // Replay the recording
        writeln("\n  Replaying build...");
        auto replayResult = engine.replay(recordingId);
        
        if (replayResult.isOk)
        {
            auto replay = replayResult.unwrap();
            
            if (replay.success)
            {
                writeln("  ✓ Replay successful!");
            }
            else
            {
                writeln("  ⚠ Replay completed with differences:");
                foreach (diff; replay.differences)
                {
                    writefln("    - %s: %s", diff.type, diff.description);
                }
            }
        }
    }
    
    writeln();
}

/// Simulate work for examples
void simulateWork(int milliseconds)
{
    import core.thread : Thread;
    import core.time : msecs;
    
    Thread.sleep(milliseconds.msecs);
}

