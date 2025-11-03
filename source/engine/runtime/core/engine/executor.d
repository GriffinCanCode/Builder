module engine.runtime.core.engine.executor;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime.stopwatch;
import engine.graph;
import infrastructure.config.schema.schema;
import languages.base.base;
import engine.runtime.services;
import frontend.cli.events.events;
import infrastructure.telemetry.distributed.tracing : Span, SpanKind, SpanStatus;
import infrastructure.utils.logging.logger;
import infrastructure.utils.simd.capabilities;
import infrastructure.errors;

/// Node build result
struct BuildResult
{
    string targetId;
    bool success;
    bool cached;
    string error;
}

/// Engine executor - handles individual target builds
struct EngineExecutor
{
    private ICacheService cache;
    private IObservabilityService observability;
    private IResilienceService resilience;
    private IHandlerRegistry handlers;
    private WorkspaceConfig config;
    private SIMDCapabilities simdCaps;
    
    /// Initialize executor with services
    void initialize(
        ICacheService cache,
        IObservabilityService observability,
        IResilienceService resilience,
        IHandlerRegistry handlers,
        WorkspaceConfig config,
        SIMDCapabilities simdCaps
    ) @trusted
    {
        this.cache = cache;
        this.observability = observability;
        this.resilience = resilience;
        this.handlers = handlers;
        this.config = config;
        this.simdCaps = simdCaps;
    }
    
    /// Build a single node
    BuildResult buildNode(BuildNode node) @trusted
    {
        auto targetSpan = observability.startSpan("build-target", SpanKind.Internal);
        scope(exit) observability.finishSpan(targetSpan);
        
        observability.setSpanAttribute(targetSpan, "target.id", node.idString);
        observability.setSpanAttribute(targetSpan, "target.language", node.target.language.to!string);
        observability.setSpanAttribute(targetSpan, "target.type", node.target.type.to!string);
        
        BuildResult result;
        result.targetId = node.id.toString();
        auto nodeTimer = StopWatch(AutoStart.yes);
        
        try
        {
            observability.logInfo("Building target", [
                "target.language": node.target.language.to!string,
                "target.type": node.target.type.to!string
            ]);
            publishTargetStarted(node, nodeTimer.peek());
            
            auto target = node.target;
            auto deps = node.dependencyIds;
            
            // Check cache
            auto cacheSpan = observability.startSpan("cache-check", SpanKind.Internal, targetSpan);
            bool isCached = cache.isCached(node.id.toString(), target.sources, deps.map!(d => d.toString()).array);
            observability.setSpanAttribute(cacheSpan, "cache.hit", isCached.to!string);
            observability.finishSpan(cacheSpan);
            
            if (isCached)
            {
                observability.setSpanAttribute(targetSpan, "build.cached", "true");
                observability.setSpanStatus(targetSpan, SpanStatus.Ok);
                
                result.success = true;
                result.cached = true;
                
                observability.publishEvent(new TargetCachedEvent(node.idString, nodeTimer.peek()));
                return result;
            }
            
            // Get language handler
            auto handler = handlers.get(target.language);
            if (handler is null)
            {
                result.error = "No language handler found for: " ~ target.language.to!string;
                observability.recordException(targetSpan, new Exception(result.error));
                observability.setSpanStatus(targetSpan, SpanStatus.Error, result.error);
                return result;
            }
            
            // Build with action-level caching
            auto compileSpan = observability.startSpan("compile", SpanKind.Internal, targetSpan);
            observability.setSpanAttribute(compileSpan, "target.sources_count", target.sources.length.to!string);
            
            // Create build context with action recorder, SIMD, and incremental support
            BuildContext buildContext;
            buildContext.target = target;
            buildContext.config = config;
            buildContext.simd = simdCaps;
            buildContext.incrementalEnabled = config.options.incremental;
            buildContext.recorder = (actionId, inputs, outputs, metadata, success) {
                cache.recordAction(actionId, inputs, outputs, metadata, success);
            };
            buildContext.depRecorder = (sourceFile, dependencies) {
                // Dependency recording handled by language handlers
                Logger.debugLog("Dependencies recorded for " ~ sourceFile);
            };
            
            // Execute with retry logic
            auto policy = resilience.policyFor(new BuildFailureError(node.idString, ""));
            auto buildResult = resilience.withRetryString(
                node.idString,
                () {
                    node.incrementRetries();
                    return handler.buildWithContext(buildContext);
                },
                policy
            );
            
            observability.finishSpan(compileSpan);
            
            if (buildResult.isOk)
            {
                auto outputHash = buildResult.unwrap();
                
                // Update cache
                auto cacheUpdateSpan = observability.startSpan("cache-update", SpanKind.Internal, targetSpan);
                cache.update(node.id.toString(), target.sources, deps.map!(d => d.toString()).array, outputHash);
                observability.finishSpan(cacheUpdateSpan);
                
                observability.setSpanStatus(targetSpan, SpanStatus.Ok);
                
                result.success = true;
                node.resetRetries();
                
                observability.publishEvent(new TargetCompletedEvent(node.idString, nodeTimer.peek(), 0, nodeTimer.peek()));
            }
            else
            {
                auto error = buildResult.unwrapErr();
                result.error = error.message();
                
                observability.recordException(targetSpan, new Exception(error.message()));
                observability.setSpanStatus(targetSpan, SpanStatus.Error, error.message());
                
                observability.publishEvent(new TargetFailedEvent(node.idString, error.message(), nodeTimer.peek(), nodeTimer.peek()));
            }
        }
        catch (Exception e)
        {
            result.error = "Build failed with exception: " ~ e.msg;
            observability.recordException(targetSpan, e);
            observability.setSpanStatus(targetSpan, SpanStatus.Error, e.msg);
            observability.logException(e, "Build failed with exception");
            
            observability.publishEvent(new TargetFailedEvent(node.idString, result.error, nodeTimer.peek(), nodeTimer.peek()));
        }
        
        return result;
    }
    
    /// Publish target started event
    private void publishTargetStarted(BuildNode node, Duration elapsed) @trusted
    {
        // Note: This requires access to the graph for topological sort
        // Will be provided by coordinator
        observability.publishEvent(new TargetStartedEvent(node.idString, 0, 0, elapsed));
    }
}

