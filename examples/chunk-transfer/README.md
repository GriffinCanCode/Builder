# Content-Defined Chunking Example

This example demonstrates Builder's content-defined chunking feature for efficient network transfer of large files.

## What It Does

The example shows:

1. **File Chunking**: Breaking a file into content-defined chunks using Rabin fingerprinting
2. **Incremental Updates**: Detecting which chunks changed after a file modification
3. **Bandwidth Savings**: Calculating network bandwidth saved by only transferring changed chunks
4. **Chunk Manifests**: Creating and managing chunk metadata for remote cache

## Running the Example

```bash
cd examples/chunk-transfer
dub run
```

Or build first:

```bash
dub build
./chunk-transfer-example
```

## Expected Output

```
=== Content-Defined Chunking Example ===

Example 1: Chunking a file
---------------------------
File: test_data.bin
Size: 5000000 bytes
Chunks: 305
Combined hash: a1b2c3d4e5f6...
Average chunk size: 16393 bytes

First 5 chunks:
  Chunk 0: offset=0 length=18234 hash=f4e3d2c1b0a9...
  Chunk 1: offset=18234 length=14567 hash=e5f6a7b8c9d0...
  Chunk 2: offset=32801 length=16384 hash=d6e7f8a9b0c1...
  ...

Example 2: Incremental Update
------------------------------
Modified file chunks: 308
New combined hash: b2c3d4e5f6a7...
Changed chunks: 15
Unchanged chunks: 293
Change rate: 4.9%

Bandwidth Analysis:
  Full upload: 5000000 bytes
  Incremental upload: 245123 bytes
  Bandwidth saved: 4754877 bytes (95.1%)

Example 3: Chunk Manifest
-------------------------
Manifest created:
  File hash: b2c3d4e5f6a7...
  Total chunks: 308
  Total size: 5000000 bytes

Example 4: Simulated Remote Cache Transfer
------------------------------------------
Transfer Statistics:
  Total chunks: 308
  Changed chunks: 15
  Chunks transferred: 15
  Bytes transferred: 245123
  Bytes saved: 4754877
  Efficiency: 95.1%
  Savings: 95.1%

=== Example Complete ===
```

## How It Works

### 1. Content-Defined Chunking

The example creates a 5 MB test file and chunks it using Rabin fingerprinting:

```d
auto chunkResult = ContentChunker.chunkFile(testFile);
```

Chunks have variable sizes (2-64 KB, averaging 16 KB) with boundaries determined by content, not fixed positions.

### 2. Incremental Update

The file is modified (simulating a code change), and the new chunk structure is compared:

```d
auto changedIndices = ContentChunker.findChangedChunks(
    chunkResult,
    newChunkResult
);
```

Only chunks that changed (typically 5-10% for small code changes) need to be uploaded.

### 3. Bandwidth Savings

The example calculates how much bandwidth would be saved:

- **Without chunking**: Upload entire 5 MB file
- **With chunking**: Upload only ~250 KB of changed chunks
- **Savings**: ~95% bandwidth reduction

## Real-World Use Cases

This technique is used in Builder for:

1. **Artifact Store Uploads**: Large compiled binaries (10-100 MB+)
2. **Distributed Cache**: CI/CD pipelines sharing build artifacts
3. **Remote Execution**: Sending inputs to remote workers

## Key Benefits

- **95% bandwidth savings** for typical code changes (5% of file modified)
- **Content-aware**: Boundaries shift naturally with content changes
- **SIMD-accelerated**: Fast chunking with minimal CPU overhead
- **Reliable**: Chunk verification ensures data integrity

## Configuration

Chunk sizes can be tuned in `source/utils/files/chunking.d`:

```d
private enum size_t MIN_CHUNK = 2_048;      // 2 KB minimum
private enum size_t AVG_CHUNK = 16_384;     // 16 KB average
private enum size_t MAX_CHUNK = 65_536;     // 64 KB maximum
```

## Learn More

- [Chunk Transfer Documentation](../../docs/features/chunk-transfer.md)
- [Rabin Fingerprinting](https://en.wikipedia.org/wiki/Rabin_fingerprint)
- [Content-Defined Chunking](https://moinakg.wordpress.com/2013/06/22/high-performance-content-defined-chunking/)

