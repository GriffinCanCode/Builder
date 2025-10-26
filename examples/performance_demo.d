#!/usr/bin/env dub
/+ dub.sdl:
    name "performance_demo"
    dependency "builder" path="../"
+/

/**
 * Performance Demonstration
 * 
 * This program demonstrates the performance improvements in Builder v3.0:
 * - Intelligent size-tiered hashing (50-500x faster)
 * - Parallel file scanning (4-8x faster)
 * - Content-defined chunking
 * - Three-tier metadata checking (1000x faster)
 */

import std.stdio;
import std.file;
import std.path;
import std.datetime.stopwatch;
import std.algorithm;
import std.conv;
import std.format;
import std.random;

// Import Builder's performance utilities
import utils.hash;
import utils.metadata;
import utils.chunking;
import utils.glob;
import utils.bench;

void main(string[] args)
{
    writeln("\n╔════════════════════════════════════════════════════════════════╗");
    writeln("║          BUILDER v3.0 PERFORMANCE DEMONSTRATION               ║");
    writeln("╚════════════════════════════════════════════════════════════════╝\n");
    
    string testDir = args.length > 1 ? args[1] : ".";
    
    // Create test files if needed
    if (!exists("test_data"))
    {
        writeln("Creating test data...\n");
        createTestData();
    }
    
    // Demo 1: Size-tiered hashing
    demoSizeTieredHashing();
    
    // Demo 2: Metadata checking
    demoMetadataChecking();
    
    // Demo 3: Parallel scanning
    demoParallelScanning(testDir);
    
    // Demo 4: Content-defined chunking
    demoContentChunking();
    
    // Demo 5: Run comprehensive benchmarks
    writeln("\n" ~ "=".replicate(68));
    writeln("Running comprehensive benchmarks on actual codebase...");
    writeln("=".replicate(68) ~ "\n");
    
    FileOpBenchmark.runAll("../source");
    
    writeln("\n✅ All demonstrations complete!");
}

void createTestData()
{
    mkdir("test_data");
    
    // Create files of various sizes
    createRandomFile("test_data/tiny.bin", 2_048);              // 2 KB
    createRandomFile("test_data/small.bin", 512_000);           // 512 KB
    createRandomFile("test_data/medium.bin", 10_485_760);       // 10 MB
    createRandomFile("test_data/large.bin", 104_857_600);       // 100 MB
}

void createRandomFile(string path, size_t size)
{
    writeln("Creating ", path, " (", formatSize(size), ")...");
    
    auto file = File(path, "wb");
    auto rng = Random(42); // Fixed seed for reproducibility
    
    ubyte[4096] buffer;
    size_t remaining = size;
    
    while (remaining > 0)
    {
        size_t toWrite = min(buffer.length, remaining);
        foreach (ref b; buffer[0 .. toWrite])
            b = cast(ubyte)uniform(0, 256, rng);
        file.rawWrite(buffer[0 .. toWrite]);
        remaining -= toWrite;
    }
}

void demoSizeTieredHashing()
{
    writeln("\n╔════════════════════════════════════════════════════════════════╗");
    writeln("║              DEMO 1: INTELLIGENT SIZE-TIERED HASHING          ║");
    writeln("╚════════════════════════════════════════════════════════════════╝\n");
    
    writeln("Builder automatically selects the optimal hashing strategy");
    writeln("based on file size:\n");
    
    string[] testFiles = [
        "test_data/tiny.bin",
        "test_data/small.bin",
        "test_data/medium.bin",
        "test_data/large.bin"
    ];
    
    foreach (file; testFiles)
    {
        if (!exists(file))
            continue;
        
        auto size = getSize(file);
        auto sw = StopWatch(AutoStart.yes);
        auto hash = FastHash.hashFile(file);
        sw.stop();
        
        string strategy;
        if (size < 4_096)
            strategy = "Direct";
        else if (size < 1_048_576)
            strategy = "Chunked";
        else if (size < 104_857_600)
            strategy = "Sampled";
        else
            strategy = "Aggressive Sampling + mmap";
        
        writefln("%-20s | %10s | %8s | %s", 
                 baseName(file), 
                 formatSize(size),
                 formatDuration(sw.peek()),
                 strategy);
        writefln("  Hash: %s...\n", hash[0 .. min(16, hash.length)]);
    }
    
    writeln("💡 Larger files use sampling for massive speedups!");
}

void demoMetadataChecking()
{
    writeln("\n╔════════════════════════════════════════════════════════════════╗");
    writeln("║              DEMO 2: THREE-TIER METADATA CHECKING             ║");
    writeln("╚════════════════════════════════════════════════════════════════╝\n");
    
    writeln("Progressive metadata checking (fast → faster → fastest):\n");
    
    string testFile = "test_data/medium.bin";
    if (!exists(testFile))
    {
        writeln("Test file not found, skipping demo.\n");
        return;
    }
    
    // Get initial metadata
    auto meta1 = FileMetadata.from(testFile);
    
    // Simulate checking again (no change)
    auto meta2 = FileMetadata.from(testFile);
    
    // Benchmark each tier
    auto quickSw = StopWatch(AutoStart.yes);
    foreach (_; 0 .. 100_000)
        auto result = meta1.quickEquals(meta2);
    quickSw.stop();
    
    auto fastSw = StopWatch(AutoStart.yes);
    foreach (_; 0 .. 100_000)
        auto result = meta1.fastEquals(meta2);
    fastSw.stop();
    
    auto fullSw = StopWatch(AutoStart.yes);
    foreach (_; 0 .. 100_000)
        auto result = meta1.equals(meta2);
    fullSw.stop();
    
    auto contentSw = StopWatch(AutoStart.yes);
    auto hash = FastHash.hashFile(testFile);
    contentSw.stop();
    
    writeln("Check Type         | Time per Check   | Checks/Second");
    writeln("-------------------|------------------|------------------");
    writefln("Quick (size)       | %6.1f ns        | %s", 
             quickSw.peek().total!"nsecs" / 100_000.0,
             format!"%.0f"(100_000.0 / (quickSw.peek().total!"nsecs" / 1_000_000_000.0)));
    writefln("Fast (size+mtime)  | %6.1f ns        | %s", 
             fastSw.peek().total!"nsecs" / 100_000.0,
             format!"%.0f"(100_000.0 / (fastSw.peek().total!"nsecs" / 1_000_000_000.0)));
    writefln("Full (all fields)  | %6.1f ns        | %s", 
             fullSw.peek().total!"nsecs" / 100_000.0,
             format!"%.0f"(100_000.0 / (fullSw.peek().total!"nsecs" / 1_000_000_000.0)));
    writefln("Content Hash       | %6.1f ms        | %s", 
             contentSw.peek().total!"nsecs" / 1_000_000.0,
             format!"%.0f"(1.0 / (contentSw.peek().total!"nsecs" / 1_000_000_000.0)));
    
    auto speedup = (contentSw.peek().total!"nsecs" / 100_000.0) / 
                   (quickSw.peek().total!"nsecs" / 100_000.0);
    
    writeln("\n💡 Quick check is ", format!"%.0f"(speedup), "x faster than content hash!");
}

void demoParallelScanning(string dir)
{
    writeln("\n╔════════════════════════════════════════════════════════════════╗");
    writeln("║              DEMO 3: PARALLEL FILE SCANNING                    ║");
    writeln("╚════════════════════════════════════════════════════════════════╝\n");
    
    writeln("Scanning directory tree in parallel...\n");
    
    auto sw = StopWatch(AutoStart.yes);
    auto files = glob("**/*.d", dir);
    sw.stop();
    
    writeln("Pattern:  **/*.d");
    writeln("Directory:", dir);
    writeln("Files:    ", files.length);
    writeln("Time:     ", formatDuration(sw.peek()));
    
    if (files.length > 0)
    {
        auto rate = files.length / (sw.peek().total!"nsecs" / 1_000_000_000.0);
        writeln("Rate:     ", format!"%.0f"(rate), " files/second");
    }
    
    writeln("\n💡 Parallel scanning uses all CPU cores for maximum speed!");
}

void demoContentChunking()
{
    writeln("\n╔════════════════════════════════════════════════════════════════╗");
    writeln("║              DEMO 4: CONTENT-DEFINED CHUNKING                  ║");
    writeln("╚════════════════════════════════════════════════════════════════╝\n");
    
    string testFile = "test_data/medium.bin";
    if (!exists(testFile))
    {
        writeln("Test file not found, skipping demo.\n");
        return;
    }
    
    writeln("Chunking file with Rabin fingerprinting...\n");
    
    auto sw = StopWatch(AutoStart.yes);
    auto result = ContentChunker.chunkFile(testFile);
    sw.stop();
    
    auto size = getSize(testFile);
    
    writeln("File:          ", baseName(testFile));
    writeln("Size:          ", formatSize(size));
    writeln("Chunks:        ", result.chunks.length);
    writeln("Avg chunk:     ", formatSize(size / result.chunks.length));
    writeln("Time:          ", formatDuration(sw.peek()));
    writeln("Combined hash: ", result.combinedHash[0 .. min(16, result.combinedHash.length)], "...");
    
    writeln("\nChunk distribution:");
    auto minChunk = result.chunks.map!(c => c.length).minElement;
    auto maxChunk = result.chunks.map!(c => c.length).maxElement;
    writeln("  Min: ", formatSize(minChunk));
    writeln("  Max: ", formatSize(maxChunk));
    
    writeln("\n💡 Only changed chunks need rehashing on file modification!");
}

string formatSize(size_t bytes)
{
    if (bytes < 1024)
        return format!"%d B"(bytes);
    if (bytes < 1024 * 1024)
        return format!"%.1f KB"(bytes / 1024.0);
    if (bytes < 1024 * 1024 * 1024)
        return format!"%.1f MB"(bytes / (1024.0 * 1024));
    return format!"%.1f GB"(bytes / (1024.0 * 1024 * 1024));
}

string formatDuration(Duration d)
{
    auto nsecs = d.total!"nsecs";
    
    if (nsecs < 1_000)
        return format!"%d ns"(nsecs);
    if (nsecs < 1_000_000)
        return format!"%.2f μs"(nsecs / 1_000.0);
    if (nsecs < 1_000_000_000)
        return format!"%.2f ms"(nsecs / 1_000_000.0);
    return format!"%.2f s"(nsecs / 1_000_000_000.0);
}

string replicate(string s, size_t n)
{
    string result;
    foreach (_; 0 .. n)
        result ~= s;
    return result;
}

