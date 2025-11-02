module caching.distributed.remote.metrics;

import std.array : Appender;
import std.conv : to;
import std.format : format;
import std.datetime : Clock, SysTime, Duration;
import core.atomic;
import core.sync.mutex : Mutex;
import caching.distributed.remote.protocol : RemoteCacheStats;

/// Prometheus metrics exporter for remote cache
/// Implements Prometheus text exposition format
final class MetricsExporter
{
    private ServerMetrics metrics;
    private Mutex mutex;
    
    /// Constructor
    this() @trusted
    {
        this.metrics = ServerMetrics.init;
        this.mutex = new Mutex();
    }
    
    /// Record request
    void recordRequest(string method, int statusCode, Duration latency) @trusted nothrow
    {
        try
        {
            atomicOp!"+="(metrics.requestsTotal, 1);
            
            // Increment method counter
            final switch (method)
            {
                case "GET":
                    atomicOp!"+="(metrics.getRequests, 1);
                    break;
                case "PUT":
                    atomicOp!"+="(metrics.putRequests, 1);
                    break;
                case "HEAD":
                    atomicOp!"+="(metrics.headRequests, 1);
                    break;
                case "DELETE":
                    atomicOp!"+="(metrics.deleteRequests, 1);
                    break;
            }
            
            // Record status
            if (statusCode >= 200 && statusCode < 300)
                atomicOp!"+="(metrics.successResponses, 1);
            else if (statusCode >= 400 && statusCode < 500)
                atomicOp!"+="(metrics.clientErrors, 1);
            else if (statusCode >= 500)
                atomicOp!"+="(metrics.serverErrors, 1);
            
            // Record latency in histogram
            recordLatency(latency);
        }
        catch (Exception) {}
    }
    
    /// Record cache hit
    void recordHit() @trusted nothrow @nogc
    {
        atomicOp!"+="(metrics.cacheHits, 1);
    }
    
    /// Record cache miss
    void recordMiss() @trusted nothrow @nogc
    {
        atomicOp!"+="(metrics.cacheMisses, 1);
    }
    
    /// Record bytes transferred
    void recordBytes(size_t uploaded, size_t downloaded) @trusted nothrow @nogc
    {
        if (uploaded > 0)
            atomicOp!"+="(metrics.bytesUploaded, uploaded);
        if (downloaded > 0)
            atomicOp!"+="(metrics.bytesDownloaded, downloaded);
    }
    
    /// Record storage metrics
    void recordStorage(size_t used, size_t total) @trusted nothrow @nogc
    {
        atomicStore(metrics.storageUsed, used);
        atomicStore(metrics.storageTotal, total);
    }
    
    /// Record eviction
    void recordEviction(size_t artifactsEvicted) @trusted nothrow @nogc
    {
        atomicOp!"+="(metrics.evictions, artifactsEvicted);
    }
    
    /// Export metrics in Prometheus text format
    string exportPrometheus() @trusted
    {
        Appender!string output;
        output.reserve(8192);
        
        immutable timestamp = Clock.currStdTime() / 10_000; // milliseconds
        
        // Request metrics
        appendMetric(output, "builder_cache_requests_total", 
            "Total number of requests", "counter",
            atomicLoad(metrics.requestsTotal), timestamp);
        
        appendMetricLabels(output, "builder_cache_requests_method_total",
            "Total requests by method", "counter", [
                MetricLabel("method", "GET", atomicLoad(metrics.getRequests)),
                MetricLabel("method", "PUT", atomicLoad(metrics.putRequests)),
                MetricLabel("method", "HEAD", atomicLoad(metrics.headRequests)),
                MetricLabel("method", "DELETE", atomicLoad(metrics.deleteRequests))
            ], timestamp);
        
        // Response metrics
        appendMetric(output, "builder_cache_responses_success_total",
            "Successful responses (2xx)", "counter",
            atomicLoad(metrics.successResponses), timestamp);
        
        appendMetric(output, "builder_cache_responses_client_error_total",
            "Client error responses (4xx)", "counter",
            atomicLoad(metrics.clientErrors), timestamp);
        
        appendMetric(output, "builder_cache_responses_server_error_total",
            "Server error responses (5xx)", "counter",
            atomicLoad(metrics.serverErrors), timestamp);
        
        // Cache metrics
        appendMetric(output, "builder_cache_hits_total",
            "Total cache hits", "counter",
            atomicLoad(metrics.cacheHits), timestamp);
        
        appendMetric(output, "builder_cache_misses_total",
            "Total cache misses", "counter",
            atomicLoad(metrics.cacheMisses), timestamp);
        
        // Compute hit rate
        immutable hits = atomicLoad(metrics.cacheHits);
        immutable misses = atomicLoad(metrics.cacheMisses);
        immutable total = hits + misses;
        immutable hitRate = total > 0 ? cast(float)hits / cast(float)total : 0.0;
        
        appendMetric(output, "builder_cache_hit_rate",
            "Cache hit rate (0.0-1.0)", "gauge",
            hitRate, timestamp);
        
        // Storage metrics
        appendMetric(output, "builder_cache_storage_bytes_used",
            "Storage space used (bytes)", "gauge",
            atomicLoad(metrics.storageUsed), timestamp);
        
        appendMetric(output, "builder_cache_storage_bytes_total",
            "Total storage capacity (bytes)", "gauge",
            atomicLoad(metrics.storageTotal), timestamp);
        
        // Compute utilization
        immutable used = atomicLoad(metrics.storageUsed);
        immutable storageTotal = atomicLoad(metrics.storageTotal);
        immutable utilization = storageTotal > 0 ? cast(float)used / cast(float)storageTotal : 0.0;
        
        appendMetric(output, "builder_cache_storage_utilization",
            "Storage utilization (0.0-1.0)", "gauge",
            utilization, timestamp);
        
        // Transfer metrics
        appendMetric(output, "builder_cache_bytes_uploaded_total",
            "Total bytes uploaded", "counter",
            atomicLoad(metrics.bytesUploaded), timestamp);
        
        appendMetric(output, "builder_cache_bytes_downloaded_total",
            "Total bytes downloaded", "counter",
            atomicLoad(metrics.bytesDownloaded), timestamp);
        
        // Eviction metrics
        appendMetric(output, "builder_cache_evictions_total",
            "Total artifacts evicted", "counter",
            atomicLoad(metrics.evictions), timestamp);
        
        // Latency histogram
        appendHistogram(output, timestamp);
        
        return output.data;
    }
    
    /// Get current metrics snapshot
    ServerMetrics getMetrics() @trusted
    {
        ServerMetrics snapshot;
        snapshot.requestsTotal = atomicLoad(metrics.requestsTotal);
        snapshot.getRequests = atomicLoad(metrics.getRequests);
        snapshot.putRequests = atomicLoad(metrics.putRequests);
        snapshot.headRequests = atomicLoad(metrics.headRequests);
        snapshot.deleteRequests = atomicLoad(metrics.deleteRequests);
        snapshot.successResponses = atomicLoad(metrics.successResponses);
        snapshot.clientErrors = atomicLoad(metrics.clientErrors);
        snapshot.serverErrors = atomicLoad(metrics.serverErrors);
        snapshot.cacheHits = atomicLoad(metrics.cacheHits);
        snapshot.cacheMisses = atomicLoad(metrics.cacheMisses);
        snapshot.bytesUploaded = atomicLoad(metrics.bytesUploaded);
        snapshot.bytesDownloaded = atomicLoad(metrics.bytesDownloaded);
        snapshot.storageUsed = atomicLoad(metrics.storageUsed);
        snapshot.storageTotal = atomicLoad(metrics.storageTotal);
        snapshot.evictions = atomicLoad(metrics.evictions);
        
        foreach (i, bucket; metrics.latencyBuckets)
            snapshot.latencyBuckets[i] = atomicLoad(bucket);
        
        return snapshot;
    }
    
    private void recordLatency(Duration latency) @trusted nothrow
    {
        try
        {
            immutable ms = latency.total!"msecs";
            
            // Find appropriate bucket
            foreach (i, bound; latencyBounds)
            {
                if (ms <= bound)
                {
                    atomicOp!"+="(metrics.latencyBuckets[i], 1);
                    break;
                }
            }
        }
        catch (Exception) {}
    }
    
    private void appendMetric(T)(
        ref Appender!string output,
        string name,
        string help,
        string type,
        T value,
        long timestamp
    ) @trusted
    {
        output ~= "# HELP " ~ name ~ " " ~ help ~ "\n";
        output ~= "# TYPE " ~ name ~ " " ~ type ~ "\n";
        output ~= name ~ " " ~ to!string(value) ~ " " ~ to!string(timestamp) ~ "\n\n";
    }
    
    private struct MetricLabel
    {
        string key;
        string value;
        long count;
    }
    
    private void appendMetricLabels(
        ref Appender!string output,
        string name,
        string help,
        string type,
        MetricLabel[] labels,
        long timestamp
    ) @trusted
    {
        output ~= "# HELP " ~ name ~ " " ~ help ~ "\n";
        output ~= "# TYPE " ~ name ~ " " ~ type ~ "\n";
        
        foreach (label; labels)
        {
            output ~= name ~ "{" ~ label.key ~ "=\"" ~ label.value ~ "\"} ";
            output ~= to!string(label.count) ~ " " ~ to!string(timestamp) ~ "\n";
        }
        
        output ~= "\n";
    }
    
    private void appendHistogram(ref Appender!string output, long timestamp) @trusted
    {
        output ~= "# HELP builder_cache_request_duration_milliseconds Request latency histogram\n";
        output ~= "# TYPE builder_cache_request_duration_milliseconds histogram\n";
        
        size_t cumulative = 0;
        foreach (i, bound; latencyBounds)
        {
            immutable count = atomicLoad(metrics.latencyBuckets[i]);
            cumulative += count;
            
            output ~= "builder_cache_request_duration_milliseconds_bucket{le=\"";
            output ~= to!string(bound);
            output ~= "\"} ";
            output ~= to!string(cumulative);
            output ~= " ";
            output ~= to!string(timestamp);
            output ~= "\n";
        }
        
        // +Inf bucket
        output ~= "builder_cache_request_duration_milliseconds_bucket{le=\"+Inf\"} ";
        output ~= to!string(cumulative);
        output ~= " ";
        output ~= to!string(timestamp);
        output ~= "\n";
        
        // Sum and count
        output ~= "builder_cache_request_duration_milliseconds_count ";
        output ~= to!string(cumulative);
        output ~= " ";
        output ~= to!string(timestamp);
        output ~= "\n\n";
    }
    
    // Latency histogram bounds (milliseconds)
    private static immutable long[] latencyBounds = [
        1, 5, 10, 25, 50, 100, 250, 500, 1000, 5000
    ];
}

/// Server metrics structure
private struct ServerMetrics
{
    shared long requestsTotal;
    shared long getRequests;
    shared long putRequests;
    shared long headRequests;
    shared long deleteRequests;
    shared long successResponses;
    shared long clientErrors;
    shared long serverErrors;
    shared long cacheHits;
    shared long cacheMisses;
    shared long bytesUploaded;
    shared long bytesDownloaded;
    shared long storageUsed;
    shared long storageTotal;
    shared long evictions;
    shared long[10] latencyBuckets;
}

