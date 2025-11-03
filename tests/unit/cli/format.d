module tests.unit.cli.format;

import tests.harness;
import frontend.cli.display.format;
import frontend.cli.control.terminal;
import frontend.cli.events.events;
import std.datetime : dur;
import std.algorithm : canFind;

/// Test formatter initialization
void testFormatterInit()
{
    auto caps = Capabilities.detect();
    auto formatter = Formatter(caps);
    
    // Should initialize without crashing
    Assert.isTrue(true, "Formatter should initialize");
}

/// Test build message formatting
void testFormatBuildMessages()
{
    auto caps = Capabilities.detect();
    auto formatter = Formatter(caps);
    
    auto started = formatter.formatBuildStarted(10, 4);
    Assert.isTrue(started.length > 0, "Should format build started");
    Assert.isTrue(started.canFind("10"), "Should contain target count");
    
    auto completed = formatter.formatBuildCompleted(8, 2, dur!"seconds"(5));
    Assert.isTrue(completed.length > 0, "Should format build completed");
    Assert.isTrue(completed.canFind("8"), "Should contain built count");
    
    auto failed = formatter.formatBuildFailed(2, dur!"seconds"(3));
    Assert.isTrue(failed.length > 0, "Should format build failed");
    Assert.isTrue(failed.canFind("2"), "Should contain failed count");
}

/// Test target message formatting
void testFormatTargetMessages()
{
    auto caps = Capabilities.detect();
    auto formatter = Formatter(caps);
    
    auto started = formatter.formatTargetStarted("//src:lib", 5, 10);
    Assert.isTrue(started.length > 0, "Should format target started");
    
    auto completed = formatter.formatTargetCompleted("//src:lib", dur!"msecs"(123));
    Assert.isTrue(completed.length > 0, "Should format target completed");
    
    auto cached = formatter.formatTargetCached("//src:lib");
    Assert.isTrue(cached.length > 0, "Should format target cached");
    Assert.isTrue(cached.canFind("cached"), "Should mention cache");
    
    auto failed = formatter.formatTargetFailed("//src:lib", "compilation error");
    Assert.isTrue(failed.length > 0, "Should format target failed");
    Assert.isTrue(failed.canFind("Error"), "Should mention error");
}

/// Test severity-based message formatting
void testFormatMessageBySeverity()
{
    auto caps = Capabilities.detect();
    auto formatter = Formatter(caps);
    
    auto info = formatter.formatInfo("Info message");
    Assert.isTrue(info.length > 0, "Should format info");
    
    auto warning = formatter.formatWarning("Warning message");
    Assert.isTrue(warning.length > 0, "Should format warning");
    
    auto error = formatter.formatError("Error message");
    Assert.isTrue(error.length > 0, "Should format error");
    
    auto debug_ = formatter.formatDebug("Debug message");
    Assert.isTrue(debug_.length > 0, "Should format debug");
}

/// Test statistics formatting
void testFormatStatistics()
{
    auto caps = Capabilities.detect();
    auto formatter = Formatter(caps);
    
    CacheStats cacheStats;
    cacheStats.hits = 50;
    cacheStats.misses = 10;
    cacheStats.totalEntries = 100;
    cacheStats.totalSize = 1024 * 1024;
    cacheStats.hitRate = 83.3;
    
    auto result = formatter.formatCacheStats(cacheStats);
    Assert.isTrue(result.length > 0, "Should format cache stats");
    Assert.isTrue(result.canFind("50"), "Should contain hit count");
    
    BuildStats buildStats;
    buildStats.totalTargets = 100;
    buildStats.completedTargets = 85;
    buildStats.cachedTargets = 10;
    buildStats.failedTargets = 5;
    buildStats.elapsed = dur!"seconds"(30);
    buildStats.targetsPerSecond = 3.3;
    
    result = formatter.formatBuildStats(buildStats);
    Assert.isTrue(result.length > 0, "Should format build stats");
    Assert.isTrue(result.canFind("100"), "Should contain total");
}

/// Test duration formatting
void testFormatDuration()
{
    auto ms = formatDuration(dur!"msecs"(500));
    Assert.equal(ms, "500ms");
    
    auto sec = formatDuration(dur!"seconds"(5));
    Assert.isTrue(sec.canFind("5"), "Should format seconds");
    
    auto min = formatDuration(dur!"seconds"(125));
    Assert.isTrue(min.canFind("2m"), "Should format minutes");
}

/// Test size formatting
void testFormatSize()
{
    auto bytes = formatSize(512);
    Assert.equal(bytes, "512 B");
    
    auto kb = formatSize(2048);
    Assert.isTrue(kb.canFind("KB"), "Should format KB");
    
    auto mb = formatSize(5 * 1024 * 1024);
    Assert.isTrue(mb.canFind("MB"), "Should format MB");
}

/// Test text truncation
void testTruncate()
{
    auto short_ = truncate("Hello", 10);
    Assert.equal(short_, "Hello");
    
    auto long_ = truncate("Hello World This Is Long", 10);
    Assert.equal(long_.length, 10);
    Assert.isTrue(long_.canFind("..."), "Should contain ellipsis");
}

/// Test separator formatting
void testFormatSeparator()
{
    auto caps = Capabilities.detect();
    auto formatter = Formatter(caps);
    
    auto sep = formatter.formatSeparator('=', 40);
    Assert.equal(sep.length, 40);
    
    // Check all characters are correct
    foreach (c; sep)
        Assert.equal(c, '=');
}