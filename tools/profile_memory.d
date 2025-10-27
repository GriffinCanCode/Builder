#!/usr/bin/env dub
/+ dub.sdl:
    name "profile_memory"
    dependency "builder" path="../"
+/

/**
 * Memory profiling tool for Builder
 * 
 * Profiles memory usage during builds of various sizes to identify bottlenecks.
 * 
 * Usage:
 *   dub run --single tools/profile_memory.d -- [project_path]
 */

import std.stdio;
import std.datetime.stopwatch;
import std.file;
import std.path;
import std.process;
import std.algorithm;
import std.array;
import std.conv;
import core.memory : GC;

void main(string[] args)
{
    writeln("=== Builder Memory Profiler ===\n");
    
    if (args.length < 2)
    {
        writeln("Usage: dub run --single tools/profile_memory.d -- [project_path]");
        writeln("Example: dub run --single tools/profile_memory.d -- ./examples/simple");
        return;
    }
    
    string projectPath = args[1];
    
    if (!exists(projectPath))
    {
        writeln("Error: Project path does not exist: ", projectPath);
        return;
    }
    
    writeln("Profiling project: ", projectPath);
    writeln();
    
    // Profile 1: GC statistics before build
    auto statsBefore = GC.stats();
    writeln("GC Stats Before Build:");
    writeln("  Used memory: ", formatSize(statsBefore.usedSize));
    writeln("  Free memory: ", formatSize(statsBefore.freeSize));
    writeln("  Total allocated: ", formatSize(statsBefore.usedSize + statsBefore.freeSize));
    writeln();
    
    // Profile 2: Build with timing
    auto sw = StopWatch(AutoStart.yes);
    
    auto result = execute(["./builder", "build"], null, Config.none, size_t.max, projectPath);
    
    sw.stop();
    
    if (result.status != 0)
    {
        writeln("Build failed:");
        writeln(result.output);
        return;
    }
    
    // Profile 3: GC statistics after build
    auto statsAfter = GC.stats();
    writeln("GC Stats After Build:");
    writeln("  Used memory: ", formatSize(statsAfter.usedSize));
    writeln("  Free memory: ", formatSize(statsAfter.freeSize));
    writeln("  Total allocated: ", formatSize(statsAfter.usedSize + statsAfter.freeSize));
    writeln();
    
    // Profile 4: Memory growth
    writeln("Memory Growth:");
    writeln("  Used delta: ", formatSize(statsAfter.usedSize - statsBefore.usedSize));
    writeln("  Free delta: ", formatSize(cast(long)statsAfter.freeSize - cast(long)statsBefore.freeSize));
    writeln();
    
    // Profile 5: Build time
    writeln("Build Performance:");
    writeln("  Total time: ", sw.peek().total!"msecs", " ms");
    writeln();
    
    // Profile 6: Recommendations
    writeln("Recommendations:");
    if (statsAfter.usedSize > 100 * 1024 * 1024)
    {
        writeln("  ⚠ High memory usage detected (>100MB)");
        writeln("    Consider enabling GC control for this project size");
    }
    else if (statsAfter.usedSize > 50 * 1024 * 1024)
    {
        writeln("  ℹ Moderate memory usage (50-100MB)");
        writeln("    Memory management is reasonable");
    }
    else
    {
        writeln("  ✓ Low memory usage (<50MB)");
        writeln("    Excellent memory efficiency");
    }
    
    writeln("\n=== Profiling Complete ===");
}

/// Format bytes as human-readable size
string formatSize(size_t bytes)
{
    if (bytes < 1024)
        return bytes.to!string ~ " B";
    else if (bytes < 1024 * 1024)
        return (bytes / 1024).to!string ~ " KB";
    else if (bytes < 1024 * 1024 * 1024)
        return (bytes / (1024 * 1024)).to!string ~ " MB";
    else
        return (bytes / (1024 * 1024 * 1024)).to!string ~ " GB";
}

