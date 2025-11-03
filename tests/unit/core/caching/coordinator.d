module tests.unit.core.caching.coordinator;

import std.stdio;
import std.path;
import std.file;
import core.caching.coordinator;
import core.caching.events;
import core.caching.metrics;
import frontend.cli.events.events;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m CacheCoordinator - Basic target cache hit/miss");
    
    auto tempDir = scoped(new TempDir("coordinator-test"));
    auto cacheDir = buildPath(tempDir.getPath(), ".cache");
    
    auto coordinator = new CacheCoordinator(cacheDir);
    
    // Create test file
    tempDir.createFile("main.d", "void main() {}");
    auto sourcePath = buildPath(tempDir.getPath(), "main.d");
    
    string[] sources = [sourcePath];
    string[] deps = [];
    
    // Initial check - miss
    Assert.isFalse(coordinator.isCached("test-target", sources, deps));
    
    // Update cache
    coordinator.update("test-target", sources, deps, "hash123");
    
    // Second check - hit
    Assert.isTrue(coordinator.isCached("test-target", sources, deps));
    
    coordinator.close();
    writeln("\x1b[32m  ✓ Coordinator cache operations work\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m CacheCoordinator - Action cache integration");
    
    auto tempDir = scoped(new TempDir("coordinator-action-test"));
    auto cacheDir = buildPath(tempDir.getPath(), ".cache");
    
    auto coordinator = new CacheCoordinator(cacheDir);
    
    // Create source file
    tempDir.createFile("source.cpp", "int main() {}");
    auto sourcePath = buildPath(tempDir.getPath(), "source.cpp");
    
    // Create action
    import core.caching.actions.action : ActionId, ActionType;
    auto actionId = ActionId("my-target", ActionType.Compile, "hash123", "source.cpp");
    
    string[] inputs = [sourcePath];
    string[string] metadata;
    metadata["compiler"] = "g++";
    
    // Check cache - miss
    Assert.isFalse(coordinator.isActionCached(actionId, inputs, metadata));
    
    // Record action
    tempDir.createFile("source.o", "binary");
    auto outputPath = buildPath(tempDir.getPath(), "source.o");
    string[] outputs = [outputPath];
    
    coordinator.recordAction(actionId, inputs, outputs, metadata, true);
    
    // Check cache - hit
    Assert.isTrue(coordinator.isActionCached(actionId, inputs, metadata));
    
    coordinator.close();
    writeln("\x1b[32m  ✓ Action cache integration works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m CacheCoordinator - Event emission");
    
    auto tempDir = scoped(new TempDir("coordinator-events-test"));
    auto cacheDir = buildPath(tempDir.getPath(), ".cache");
    
    // Create event publisher
    auto publisher = new SimpleEventPublisher();
    
    // Subscribe metrics collector
    auto metricsCollector = new CacheMetricsCollector();
    publisher.subscribe(metricsCollector);
    
    // Create coordinator with publisher
    auto coordinator = new CacheCoordinator(cacheDir, publisher);
    
    // Create test file
    tempDir.createFile("test.d", "void test() {}");
    auto sourcePath = buildPath(tempDir.getPath(), "test.d");
    
    string[] sources = [sourcePath];
    string[] deps = [];
    
    // Trigger cache miss (emits event)
    coordinator.isCached("test-target", sources, deps);
    
    // Update (emits event)
    coordinator.update("test-target", sources, deps, "hash456");
    
    // Hit (emits event)
    coordinator.isCached("test-target", sources, deps);
    
    // Get metrics
    auto metrics = metricsCollector.getMetrics();
    Assert.isTrue(metrics.targetHits > 0, "Should have target hits");
    Assert.isTrue(metrics.targetMisses > 0, "Should have target misses");
    Assert.isTrue(metrics.updates > 0, "Should have updates");
    
    coordinator.close();
    writeln("\x1b[32m  ✓ Event emission and metrics collection work\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m CacheCoordinator - Statistics");
    
    auto tempDir = scoped(new TempDir("coordinator-stats-test"));
    auto cacheDir = buildPath(tempDir.getPath(), ".cache");
    
    auto coordinator = new CacheCoordinator(cacheDir);
    
    // Get initial stats
    auto stats = coordinator.getStats();
    Assert.equals(stats.targetCacheEntries, 0);
    
    // Add some cache entries
    tempDir.createFile("file1.d", "content1");
    tempDir.createFile("file2.d", "content2");
    
    auto file1 = buildPath(tempDir.getPath(), "file1.d");
    auto file2 = buildPath(tempDir.getPath(), "file2.d");
    
    coordinator.update("target1", [file1], [], "hash1");
    coordinator.update("target2", [file2], [], "hash2");
    
    // Get updated stats
    stats = coordinator.getStats();
    Assert.equals(stats.targetCacheEntries, 2);
    
    coordinator.close();
    writeln("\x1b[32m  ✓ Statistics reporting works\x1b[0m");
}

