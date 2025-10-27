module core.telemetry.exporter;

import std.array : appender, Appender, replicate;
import std.conv : to;
import std.datetime : SysTime;
import std.format : format;
import core.telemetry.collector;
import core.telemetry.analysis;
import errors;

/// Export telemetry data in various formats
struct TelemetryExporter
{
    /// Export sessions as JSON
    static Result!(string, TelemetryError) toJson(BuildSession[] sessions) @safe
    {
        try
        {
            auto buffer = appender!string;
            buffer ~= "{\n";
            buffer ~= format(`  "sessions": [%s`, "\n");
            
            foreach (i, ref session; sessions)
            {
                buffer ~= sessionToJson(session, 2);
                if (i < sessions.length - 1)
                    buffer ~= ",\n";
            }
            
            buffer ~= "\n  ]\n";
            buffer ~= "}";
            
            return Result!(string, TelemetryError).ok(buffer.data);
        }
        catch (Exception e)
        {
            return Result!(string, TelemetryError).err(
                TelemetryError.storageError("JSON export failed: " ~ e.msg)
            );
        }
    }
    
    /// Export analytics report as JSON
    static Result!(string, TelemetryError) reportToJson(AnalyticsReport report) pure @safe
    {
        try
        {
            auto buffer = appender!string;
            buffer ~= "{\n";
            buffer ~= format(`  "totalBuilds": %d,%s`, report.totalBuilds, "\n");
            buffer ~= format(`  "successfulBuilds": %d,%s`, report.successfulBuilds, "\n");
            buffer ~= format(`  "failedBuilds": %d,%s`, report.failedBuilds, "\n");
            buffer ~= format(`  "successRate": %.2f,%s`, report.successRate, "\n");
            buffer ~= format(`  "avgBuildTimeMs": %d,%s`, report.avgBuildTime.total!"msecs", "\n");
            buffer ~= format(`  "avgCacheHitRate": %.2f,%s`, report.avgCacheHitRate, "\n");
            buffer ~= format(`  "avgParallelism": %.2f,%s`, report.avgParallelism, "\n");
            buffer ~= format(`  "avgTargetsPerSecond": %.2f,%s`, report.avgTargetsPerSecond, "\n");
            buffer ~= format(`  "fastestBuildMs": %d,%s`, report.fastestBuild.total!"msecs", "\n");
            buffer ~= format(`  "slowestBuildMs": %d,%s`, report.slowestBuild.total!"msecs", "\n");
            
            buffer ~= `  "bottlenecks": [`;
            foreach (i, bottleneck; report.bottlenecks)
            {
                buffer ~= format(`"%s"`, bottleneck);
                if (i < report.bottlenecks.length - 1)
                    buffer ~= ", ";
            }
            buffer ~= "],\n";
            
            buffer ~= format(`  "buildTimeTrend": "%s",%s`, report.buildTimeTrend, "\n");
            buffer ~= format(`  "cacheEfficiencyTrend": "%s"%s`, report.cacheEfficiencyTrend, "\n");
            buffer ~= "}";
            
            return Result!(string, TelemetryError).ok(buffer.data);
        }
        catch (Exception e)
        {
            return Result!(string, TelemetryError).err(
                TelemetryError.storageError("JSON export failed: " ~ e.msg)
            );
        }
    }
    
    /// Export sessions as CSV
    static Result!(string, TelemetryError) toCsv(BuildSession[] sessions) @safe
    {
        try
        {
            auto buffer = appender!string;
            
            // Header
            buffer ~= "StartTime,Duration(ms),TotalTargets,Built,Cached,Failed,";
            buffer ~= "CacheHitRate,ParallelismUtilization,TargetsPerSecond,Succeeded\n";
            
            // Data rows
            foreach (ref session; sessions)
            {
                buffer ~= format("%s,%d,%d,%d,%d,%d,%.2f,%.2f,%.2f,%s\n",
                    session.startTime.toISOExtString(),
                    session.totalDuration.total!"msecs",
                    session.totalTargets,
                    session.built,
                    session.cached,
                    session.failed,
                    session.cacheHitRate,
                    session.parallelismUtilization,
                    session.targetsPerSecond,
                    session.succeeded ? "true" : "false"
                );
            }
            
            return Result!(string, TelemetryError).ok(buffer.data);
        }
        catch (Exception e)
        {
            return Result!(string, TelemetryError).err(
                TelemetryError.storageError("CSV export failed: " ~ e.msg)
            );
        }
    }
    
    /// Export human-readable summary
    static Result!(string, TelemetryError) toSummary(AnalyticsReport report) pure @safe
    {
        try
        {
            auto buffer = appender!string;
            
            buffer ~= "=== Build Telemetry Summary ===\n\n";
            
            buffer ~= format("Total Builds: %d\n", report.totalBuilds);
            buffer ~= format("Successful: %d (%.1f%%)\n", 
                report.successfulBuilds, report.successRate);
            buffer ~= format("Failed: %d\n\n", report.failedBuilds);
            
            buffer ~= "Performance Metrics:\n";
            buffer ~= format("  Average Build Time: %d ms\n", 
                report.avgBuildTime.total!"msecs");
            buffer ~= format("  Fastest Build: %d ms\n", 
                report.fastestBuild.total!"msecs");
            buffer ~= format("  Slowest Build: %d ms\n\n", 
                report.slowestBuild.total!"msecs");
            
            buffer ~= "Cache Efficiency:\n";
            buffer ~= format("  Average Hit Rate: %.1f%%\n", 
                report.avgCacheHitRate);
            buffer ~= format("  Trend: %s\n\n", 
                report.cacheEfficiencyTrend);
            
            buffer ~= "Parallelism:\n";
            buffer ~= format("  Average Utilization: %.1f%%\n", 
                report.avgParallelism);
            buffer ~= format("  Targets/Second: %.2f\n\n", 
                report.avgTargetsPerSecond);
            
            if (report.bottlenecks.length > 0)
            {
                buffer ~= "Top Bottlenecks:\n";
                foreach (i, bottleneck; report.bottlenecks)
                {
                    buffer ~= format("  %d. %s\n", i + 1, bottleneck);
                }
                buffer ~= "\n";
            }
            
            buffer ~= format("Build Time Trend: %s\n", report.buildTimeTrend);
            
            return Result!(string, TelemetryError).ok(buffer.data);
        }
        catch (Exception e)
        {
            return Result!(string, TelemetryError).err(
                TelemetryError.storageError("Summary export failed: " ~ e.msg)
            );
        }
    }
    
    private static string sessionToJson(ref const BuildSession session, int indent) @safe
    {
        auto buffer = appender!string;
        immutable spaces = " ".replicate(indent);
        
        buffer ~= spaces ~ "{\n";
        buffer ~= format(`%s  "startTime": "%s",%s`, spaces, session.startTime.toISOExtString(), "\n");
        buffer ~= format(`%s  "durationMs": %d,%s`, spaces, session.totalDuration.total!"msecs", "\n");
        buffer ~= format(`%s  "totalTargets": %d,%s`, spaces, session.totalTargets, "\n");
        buffer ~= format(`%s  "built": %d,%s`, spaces, session.built, "\n");
        buffer ~= format(`%s  "cached": %d,%s`, spaces, session.cached, "\n");
        buffer ~= format(`%s  "failed": %d,%s`, spaces, session.failed, "\n");
        buffer ~= format(`%s  "cacheHitRate": %.2f,%s`, spaces, session.cacheHitRate, "\n");
        buffer ~= format(`%s  "parallelismUtilization": %.2f,%s`, spaces, session.parallelismUtilization, "\n");
        buffer ~= format(`%s  "targetsPerSecond": %.2f,%s`, spaces, session.targetsPerSecond, "\n");
        buffer ~= format(`%s  "succeeded": %s%s`, spaces, session.succeeded ? "true" : "false", "\n");
        buffer ~= spaces ~ "}";
        
        return buffer.data;
    }
}


