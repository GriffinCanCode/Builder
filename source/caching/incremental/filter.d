module caching.incremental.filter;

import std.algorithm;
import std.array;
import std.conv;
import caching.incremental.dependency;
import caching.actions.action;
import utils.logging.logger;

/// Smart file filter for operations (lint, format, analyze)
/// Reuses incremental infrastructure to skip unchanged files
struct IncrementalFilter
{
    private DependencyCache depCache;
    private ActionCache actionCache;
    
    /// Initialize with caches
    static IncrementalFilter create(DependencyCache depCache, ActionCache actionCache) @safe
    {
        IncrementalFilter filter;
        filter.depCache = depCache;
        filter.actionCache = actionCache;
        return filter;
    }
    
    /// Filter files for operation based on changes
    /// Returns: files that actually need processing
    string[] filterFiles(
        string[] allFiles,
        string[] changedFiles,
        ActionType operationType,
        string[string] metadata
    ) @system
    {
        if (changedFiles.empty || depCache is null)
            return allFiles;  // No filter info, process all
        
        // Get affected files from dependency analysis
        auto changes = depCache.analyzeChanges(changedFiles);
        auto affectedFiles = changes.filesToRebuild;
        
        bool[string] needsProcessing;
        
        foreach (file; allFiles)
        {
            // Check if file affected by changes
            if (affectedFiles.canFind(file))
            {
                needsProcessing[file] = true;
                continue;
            }
            
            // Check action cache if available
            if (actionCache !is null)
            {
                ActionId actionId;
                actionId.targetId = "filter";
                actionId.type = operationType;
                actionId.subId = file;
                
                import utils.files.hash;
                actionId.inputHash = FastHash.hashFile(file);
                
                if (!actionCache.isCached(actionId, [file], metadata))
                {
                    needsProcessing[file] = true;
                }
            }
            else
            {
                // No action cache, must process
                needsProcessing[file] = true;
            }
        }
        
        auto result = needsProcessing.keys;
        
        if (result.length < allFiles.length)
        {
            Logger.info("Incremental filter: " ~ result.length.to!string ~ 
                       "/" ~ allFiles.length.to!string ~ " files need processing");
        }
        
        return result;
    }
}

