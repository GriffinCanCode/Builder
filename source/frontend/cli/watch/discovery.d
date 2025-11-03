module frontend.cli.watch.discovery;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import engine.graph.graph;
import engine.graph.dynamic;
import engine.graph.discovery;
import infrastructure.config.schema.schema;
import infrastructure.utils.logging.logger;
import infrastructure.errors;

/// Watch mode discovery tracker
/// Tracks file changes that may trigger discovery re-execution
final class WatchDiscoveryTracker
{
    private DynamicBuildGraph dynamicGraph;
    private string[string] discoveredFileOrigins; // file -> originTarget
    private string[][string] targetInputs;  // targetId -> input files
    
    this(DynamicBuildGraph dynamicGraph) @system
    {
        this.dynamicGraph = dynamicGraph;
    }
    
    /// Register a discovery result for watching
    void registerDiscovery(DiscoveryMetadata discovery) @system
    {
        auto originKey = discovery.originTarget.toString();
        
        // Track which target discovered which files
        foreach (output; discovery.discoveredOutputs)
        {
            discoveredFileOrigins[output] = originKey;
        }
        
        Logger.debugLog("Registered discovery: " ~ originKey ~ " -> " ~ 
                       discovery.discoveredOutputs.length.to!string ~ " files");
    }
    
    /// Check if a changed file requires re-discovery
    /// Returns the origin target that needs to re-run discovery
    Result!(string[], string) checkForRediscovery(string[] changedFiles) @system
    {
        bool[string] targetsNeedingRediscovery;
        
        foreach (file; changedFiles)
        {
            // Check if this is an input to a discoverable target
            foreach (targetId, inputs; targetInputs)
            {
                if (inputs.canFind(file))
                {
                    if (dynamicGraph.isDiscoverable(TargetId(targetId)))
                    {
                        targetsNeedingRediscovery[targetId] = true;
                        Logger.info("File change triggers re-discovery: " ~ file ~ " -> " ~ targetId);
                    }
                }
            }
            
            // Check if this is a discovered file (might need to invalidate)
            if (file in discoveredFileOrigins)
            {
                auto originTarget = discoveredFileOrigins[file];
                Logger.warning("Discovered file changed: " ~ file ~ 
                             " (originally from " ~ originTarget ~ ")");
                // This is unusual - user modified a generated file
                // We should re-run discovery to regenerate
                targetsNeedingRediscovery[originTarget] = true;
            }
        }
        
        return Result!(string[], string).ok(targetsNeedingRediscovery.keys);
    }
    
    /// Track input files for a target
    void trackTargetInputs(string targetId, string[] inputs) @system
    {
        targetInputs[targetId] = inputs;
    }
    
    /// Clear all tracking data
    void clear() @system
    {
        discoveredFileOrigins.clear();
        targetInputs.clear();
    }
    
    /// Get statistics
    struct Stats
    {
        size_t trackedFiles;
        size_t trackedTargets;
    }
    
    Stats getStats() const @system
    {
        Stats stats;
        stats.trackedFiles = discoveredFileOrigins.length;
        stats.trackedTargets = targetInputs.length;
        return stats;
    }
}

/// Watch mode with discovery support
/// Extends watch mode to handle dynamic dependency changes
class WatchModeWithDiscovery
{
    private DynamicBuildGraph dynamicGraph;
    private WatchDiscoveryTracker tracker;
    private BuildGraph baseGraph;
    
    this(BuildGraph baseGraph) @system
    {
        this.baseGraph = baseGraph;
        this.dynamicGraph = new DynamicBuildGraph(baseGraph);
        this.tracker = new WatchDiscoveryTracker(dynamicGraph);
        
        // Mark discoverable targets
        import engine.runtime.core.engine.discovery;
        DiscoveryMarker.markCodeGenTargets(dynamicGraph);
    }
    
    /// Handle file changes in watch mode
    void onFilesChanged(string[] changedFiles) @system
    {
        Logger.info("Files changed: " ~ changedFiles.length.to!string);
        
        // Check if any changes require re-discovery
        auto rediscoveryResult = tracker.checkForRediscovery(changedFiles);
        if (rediscoveryResult.isErr)
        {
            Logger.error("Failed to check for re-discovery: " ~ rediscoveryResult.unwrapErr());
            return;
        }
        
        auto targetsNeedingRediscovery = rediscoveryResult.unwrap();
        
        if (!targetsNeedingRediscovery.empty)
        {
            Logger.info("Re-discovery needed for " ~ targetsNeedingRediscovery.length.to!string ~ " targets");
            
            // Trigger rebuild with discovery
            foreach (targetId; targetsNeedingRediscovery)
            {
                Logger.info("  • " ~ targetId);
            }
            
            // In a full implementation, this would:
            // 1. Clear old discoveries for these targets
            // 2. Re-run discovery phase
            // 3. Update graph with new discoveries
            // 4. Rebuild affected targets
        }
    }
    
    /// Register a discovery result
    void onDiscoveryComplete(DiscoveryMetadata discovery) @system
    {
        tracker.registerDiscovery(discovery);
        dynamicGraph.recordDiscovery(discovery);
    }
    
    /// Get tracker statistics
    auto getStats() const @system
    {
        return tracker.getStats();
    }
}


