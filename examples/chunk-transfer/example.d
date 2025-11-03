#!/usr/bin/env dub
/+ dub.sdl:
    name "chunk-transfer-example"
    description "Demonstrates content-defined chunking for network transfer"
    dependency "builder" path="../../"
+/

import std.stdio;
import std.file;
import std.path;
import std.conv;
import infrastructure.utils.files.chunking;
import engine.caching.distributed.remote.client;
import engine.caching.distributed.remote.protocol;

void main()
{
    writeln("=== Content-Defined Chunking Example ===\n");
    
    // Example 1: Chunk a local file
    writeln("Example 1: Chunking a file");
    writeln("---------------------------");
    
    immutable testFile = "test_data.bin";
    
    // Create test file (simulate a binary)
    createTestFile(testFile, 5_000_000);  // 5 MB
    
    auto chunkResult = ContentChunker.chunkFile(testFile);
    
    writeln("File: ", testFile);
    writeln("Size: ", getSize(testFile), " bytes");
    writeln("Chunks: ", chunkResult.chunks.length);
    writeln("Combined hash: ", chunkResult.combinedHash);
    writeln("Average chunk size: ", 
            getSize(testFile) / chunkResult.chunks.length, " bytes");
    
    // Show first few chunks
    writeln("\nFirst 5 chunks:");
    foreach (i, chunk; chunkResult.chunks[0 .. min(5, chunkResult.chunks.length)])
    {
        writeln("  Chunk ", i, ": offset=", chunk.offset, 
                " length=", chunk.length, " hash=", chunk.hash[0 .. 16], "...");
    }
    
    // Example 2: Simulate incremental update
    writeln("\n\nExample 2: Incremental Update");
    writeln("------------------------------");
    
    // Modify the file (simulate code change)
    modifyTestFile(testFile);
    
    auto newChunkResult = ContentChunker.chunkFile(testFile);
    
    writeln("Modified file chunks: ", newChunkResult.chunks.length);
    writeln("New combined hash: ", newChunkResult.combinedHash);
    
    // Find changed chunks
    auto changedIndices = ContentChunker.findChangedChunks(
        chunkResult,
        newChunkResult
    );
    
    writeln("Changed chunks: ", changedIndices.length);
    writeln("Unchanged chunks: ", newChunkResult.chunks.length - changedIndices.length);
    
    immutable changePercent = (cast(double)changedIndices.length / 
                               cast(double)newChunkResult.chunks.length) * 100.0;
    writeln("Change rate: ", changePercent, "%");
    
    // Calculate bandwidth savings
    size_t changedBytes = 0;
    foreach (idx; changedIndices)
    {
        if (idx < newChunkResult.chunks.length)
            changedBytes += newChunkResult.chunks[idx].length;
    }
    
    immutable totalBytes = getSize(testFile);
    immutable savedBytes = totalBytes - changedBytes;
    immutable savingsPercent = (cast(double)savedBytes / cast(double)totalBytes) * 100.0;
    
    writeln("\nBandwidth Analysis:");
    writeln("  Full upload: ", totalBytes, " bytes");
    writeln("  Incremental upload: ", changedBytes, " bytes");
    writeln("  Bandwidth saved: ", savedBytes, " bytes (", savingsPercent, "%)");
    
    // Example 3: Chunk manifest
    writeln("\n\nExample 3: Chunk Manifest");
    writeln("-------------------------");
    
    ChunkManifest manifest;
    manifest.fileHash = newChunkResult.combinedHash;
    manifest.chunks = newChunkResult.chunks;
    manifest.totalSize = getSize(testFile);
    
    writeln("Manifest created:");
    writeln("  File hash: ", manifest.fileHash);
    writeln("  Total chunks: ", manifest.chunks.length);
    writeln("  Total size: ", manifest.totalSize, " bytes");
    
    // Simulate remote cache scenario
    writeln("\n\nExample 4: Simulated Remote Cache Transfer");
    writeln("------------------------------------------");
    
    // Simulate transfer statistics
    TransferStats stats;
    stats.totalChunks = newChunkResult.chunks.length;
    stats.changedChunks = changedIndices.length;
    stats.chunksTransferred = changedIndices.length;
    stats.bytesTransferred = changedBytes;
    stats.bytesSaved = savedBytes;
    
    writeln("Transfer Statistics:");
    writeln("  Total chunks: ", stats.totalChunks);
    writeln("  Changed chunks: ", stats.changedChunks);
    writeln("  Chunks transferred: ", stats.chunksTransferred);
    writeln("  Bytes transferred: ", stats.bytesTransferred);
    writeln("  Bytes saved: ", stats.bytesSaved);
    writeln("  Efficiency: ", stats.efficiency() * 100.0, "%");
    writeln("  Savings: ", stats.savingsPercent(), "%");
    
    // Cleanup
    remove(testFile);
    
    writeln("\n=== Example Complete ===");
}

/// Create a test file with semi-random data
void createTestFile(string path, size_t size)
{
    auto file = File(path, "wb");
    
    // Create structured data (simulates compiled binary)
    // Mix of repeated patterns and unique data
    ubyte[] buffer = new ubyte[4096];
    size_t written = 0;
    
    while (written < size)
    {
        // Pattern 1: Sequential bytes (simulates code)
        for (size_t i = 0; i < 1024 && written < size; i++, written++)
        {
            buffer[i % 4096] = cast(ubyte)((written + i) % 256);
        }
        
        // Pattern 2: Repeated data (simulates data section)
        for (size_t i = 0; i < 512 && written < size; i++, written++)
        {
            buffer[i % 4096] = cast(ubyte)(0xAB);
        }
        
        // Pattern 3: Pseudo-random (simulates mixed content)
        for (size_t i = 0; i < 2560 && written < size; i++, written++)
        {
            buffer[i % 4096] = cast(ubyte)((written * 31 + i * 17) % 256);
        }
        
        size_t toWrite = min(4096, size - (written - 4096));
        file.rawWrite(buffer[0 .. toWrite]);
    }
}

/// Modify test file to simulate code change
void modifyTestFile(string path)
{
    auto data = cast(ubyte[])read(path);
    
    // Modify 5% of the file in middle (simulates function change)
    immutable modifyStart = data.length / 2;
    immutable modifyLength = data.length / 20;  // 5%
    
    foreach (i; modifyStart .. modifyStart + modifyLength)
    {
        if (i < data.length)
            data[i] = cast(ubyte)((data[i] + 42) % 256);
    }
    
    write(path, data);
}

size_t min(T)(T a, T b)
{
    return a < b ? a : b;
}

