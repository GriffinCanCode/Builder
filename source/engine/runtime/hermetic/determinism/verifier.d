module engine.runtime.hermetic.determinism.verifier;

import std.file : exists, read, getSize, dirEntries, SpanMode;
import std.path : buildPath, baseName, extension;
import std.algorithm : map, filter;
import std.array : array;
import std.conv : to;
import std.datetime : SysTime;
import infrastructure.utils.files.hash : FastHash;
import engine.runtime.hermetic.determinism.enforcer;
import infrastructure.errors;

/// Verification strategy for build outputs
enum VerificationStrategy
{
    ContentHash,      // Compare content hashes (default)
    BitwiseCompare,   // Bit-for-bit comparison
    Fuzzy,           // Ignore timestamps and metadata
    Structural       // Compare structure, not exact bytes
}

/// File comparison result
struct FileComparison
{
    string filePath;
    bool matches;
    string hash1;
    string hash2;
    string[] differences;  // Description of differences
}

/// Verification result for deterministic builds
struct VerificationResult
{
    bool isDeterministic;
    FileComparison[] comparisons;
    string[] violations;
    ulong totalFiles;
    ulong matchingFiles;
    double matchPercentage;
    
    /// Get summary string
    string summary() @safe const
    {
        import std.format : format;
        
        if (isDeterministic)
            return format("✓ Deterministic: %d/%d files match (%.1f%%)",
                matchingFiles, totalFiles, matchPercentage);
        else
            return format("✗ Non-deterministic: %d/%d files differ (%.1f%% match)",
                totalFiles - matchingFiles, totalFiles, matchPercentage);
    }
}

/// Verifier for deterministic build outputs
/// 
/// Compares build outputs across multiple runs to verify bit-for-bit
/// reproducibility. Supports multiple verification strategies and can
/// identify specific sources of non-determinism.
struct DeterminismVerifier
{
    private VerificationStrategy strategy;
    
    /// Create verifier with strategy
    static DeterminismVerifier create(
        VerificationStrategy strategy = VerificationStrategy.ContentHash
    ) @safe pure nothrow
    {
        DeterminismVerifier verifier;
        verifier.strategy = strategy;
        return verifier;
    }
    
    /// Verify outputs from two builds match
    Result!(VerificationResult, BuildError) verify(
        string[] outputPaths1,
        string[] outputPaths2
    ) @system
    {
        import std.algorithm : sort;
        
        // Normalize paths
        auto sorted1 = outputPaths1.dup.sort().array;
        auto sorted2 = outputPaths2.dup.sort().array;
        
        // Check same file count
        if (sorted1.length != sorted2.length)
        {
            return Err!(VerificationResult, BuildError)(
                new SystemError(
                    "Different number of output files: " ~ 
                    sorted1.length.to!string ~ " vs " ~ sorted2.length.to!string,
                    ErrorCode.ValidationFailed
                ));
        }
        
        VerificationResult result;
        result.totalFiles = sorted1.length;
        result.matchingFiles = 0;
        
        // Compare each file pair
        foreach (i, path1; sorted1)
        {
            auto path2 = sorted2[i];
            
            // Verify both files exist
            if (!exists(path1) || !exists(path2))
            {
                FileComparison comparison;
                comparison.filePath = baseName(path1);
                comparison.matches = false;
                comparison.differences = ["File missing"];
                result.comparisons ~= comparison;
                continue;
            }
            
            // Compare based on strategy
            auto comparison = compareFiles(path1, path2);
            result.comparisons ~= comparison;
            
            if (comparison.matches)
                result.matchingFiles++;
            else
                result.violations ~= comparison.filePath ~ ": " ~ 
                    comparison.differences.join(", ");
        }
        
        result.matchPercentage = (cast(double)result.matchingFiles / result.totalFiles) * 100.0;
        result.isDeterministic = (result.matchingFiles == result.totalFiles);
        
        return Ok!(VerificationResult, BuildError)(result);
    }
    
    /// Verify directory outputs match
    Result!(VerificationResult, BuildError) verifyDirectory(
        string dir1,
        string dir2
    ) @system
    {
        if (!exists(dir1) || !exists(dir2))
        {
            return Err!(VerificationResult, BuildError)(
                new SystemError("Directory not found", ErrorCode.IOError));
        }
        
        // Collect all files recursively
        auto files1 = collectFiles(dir1);
        auto files2 = collectFiles(dir2);
        
        return verify(files1, files2);
    }
    
    /// Verify single file matches across runs
    Result!(bool, BuildError) verifyFile(string path1, string path2) @system
    {
        if (!exists(path1) || !exists(path2))
            return Err!(bool, BuildError)(
                ioError(path1, "File not found"));
        
        auto comparison = compareFiles(path1, path2);
        return Ok!(bool, BuildError)(comparison.matches);
    }
    
    /// Compute aggregate hash for all outputs
    static string computeOutputHash(string[] outputPaths) @system
    {
        import std.algorithm : sort;
        
        // Sort for deterministic ordering
        auto sorted = outputPaths.dup.sort().array;
        
        // Hash all files
        string combined;
        foreach (path; sorted)
        {
            if (exists(path))
                combined ~= FastHash.hashFile(path);
        }
        
        return FastHash.hashString(combined);
    }
    
    private:
    
    /// Compare two files based on verification strategy
    FileComparison compareFiles(string path1, string path2) @system
    {
        FileComparison comparison;
        comparison.filePath = baseName(path1);
        
        final switch (strategy)
        {
            case VerificationStrategy.ContentHash:
                return compareByHash(path1, path2);
            
            case VerificationStrategy.BitwiseCompare:
                return compareByBitwise(path1, path2);
            
            case VerificationStrategy.Fuzzy:
                return compareByFuzzy(path1, path2);
            
            case VerificationStrategy.Structural:
                return compareByStructure(path1, path2);
        }
    }
    
    /// Compare by content hash (fast)
    FileComparison compareByHash(string path1, string path2) @system
    {
        FileComparison comparison;
        comparison.filePath = baseName(path1);
        
        comparison.hash1 = FastHash.hashFile(path1);
        comparison.hash2 = FastHash.hashFile(path2);
        comparison.matches = (comparison.hash1 == comparison.hash2);
        
        if (!comparison.matches)
            comparison.differences = ["Content hash mismatch"];
        
        return comparison;
    }
    
    /// Compare bit-for-bit (thorough but slow)
    FileComparison compareByBitwise(string path1, string path2) @system
    {
        FileComparison comparison;
        comparison.filePath = baseName(path1);
        
        // Check sizes first
        auto size1 = getSize(path1);
        auto size2 = getSize(path2);
        
        if (size1 != size2)
        {
            comparison.matches = false;
            comparison.differences = ["Size mismatch: " ~ 
                size1.to!string ~ " vs " ~ size2.to!string];
            return comparison;
        }
        
        // Read and compare bytes
        auto bytes1 = cast(ubyte[])read(path1);
        auto bytes2 = cast(ubyte[])read(path2);
        
        comparison.matches = (bytes1 == bytes2);
        
        if (!comparison.matches)
        {
            // Find first difference
            foreach (i, b1; bytes1)
            {
                if (b1 != bytes2[i])
                {
                    comparison.differences = [
                        "First difference at byte " ~ i.to!string ~
                        ": 0x" ~ b1.to!string(16) ~ " vs 0x" ~ bytes2[i].to!string(16)
                    ];
                    break;
                }
            }
        }
        
        return comparison;
    }
    
    /// Compare ignoring timestamps and metadata (fuzzy)
    FileComparison compareByFuzzy(string path1, string path2) @system
    {
        FileComparison comparison;
        comparison.filePath = baseName(path1);
        
        // Read both files
        auto bytes1 = cast(ubyte[])read(path1);
        auto bytes2 = cast(ubyte[])read(path2);
        
        // Strip metadata based on file type
        auto stripped1 = stripMetadata(bytes1, path1);
        auto stripped2 = stripMetadata(bytes2, path2);
        
        // Hash stripped content
        comparison.hash1 = FastHash.hashBytes(stripped1);
        comparison.hash2 = FastHash.hashBytes(stripped2);
        comparison.matches = (comparison.hash1 == comparison.hash2);
        
        if (!comparison.matches)
            comparison.differences = ["Content differs after metadata stripping"];
        
        return comparison;
    }
    
    /// Compare by structure (for archives, ELF, etc.)
    FileComparison compareByStructure(string path1, string path2) @system
    {
        FileComparison comparison;
        comparison.filePath = baseName(path1);
        
        // Detect file type
        auto fileType = detectFileType(path1);
        
        final switch (fileType)
        {
            case FileType.ELF:
                comparison = compareELFStructure(path1, path2);
                break;
            case FileType.Archive:
                comparison = compareArchiveStructure(path1, path2);
                break;
            case FileType.Object:
                comparison = compareObjectStructure(path1, path2);
                break;
            case FileType.Unknown:
                // Fall back to fuzzy comparison
                comparison = compareByFuzzy(path1, path2);
                break;
        }
        
        return comparison;
    }
    
private:
    
    /// File type detection
    enum FileType { ELF, Archive, Object, Unknown }
    
    FileType detectFileType(string path) @system
    {
        import std.algorithm : startsWith;
        
        if (getSize(path) < 4)
            return FileType.Unknown;
        
        auto bytes = cast(ubyte[])read(path, 4);
        
        // ELF magic: 0x7F 'E' 'L' 'F'
        if (bytes.length >= 4 && bytes[0] == 0x7F && 
            bytes[1] == 'E' && bytes[2] == 'L' && bytes[3] == 'F')
            return FileType.ELF;
        
        // Archive magic: "!<arch>\n"
        if (bytes.length >= 4 && bytes[0] == '!' && bytes[1] == '<')
            return FileType.Archive;
        
        // Object file heuristics (various formats)
        auto ext = extension(path);
        if (ext == ".o" || ext == ".obj")
            return FileType.Object;
        
        return FileType.Unknown;
    }
    
    /// Strip metadata from file bytes
    ubyte[] stripMetadata(ubyte[] bytes, string path) @system
    {
        auto fileType = detectFileType(path);
        
        final switch (fileType)
        {
            case FileType.ELF:
                return stripELFMetadata(bytes);
            case FileType.Archive:
                return stripArchiveMetadata(bytes);
            case FileType.Object:
                return stripObjectMetadata(bytes);
            case FileType.Unknown:
                return bytes; // No stripping for unknown types
        }
    }
    
    /// Strip ELF metadata (timestamps, build IDs in notes section)
    ubyte[] stripELFMetadata(ubyte[] bytes) pure @system
    {
        if (bytes.length < 64)
            return bytes.dup;
        
        auto result = bytes.dup;
        
        // Check ELF magic number
        if (result[0] != 0x7F || result[1] != 'E' || result[2] != 'L' || result[3] != 'F')
            return result;
        
        ubyte elfClass = result[4]; // 1=32-bit, 2=64-bit
        ubyte elfData = result[5];  // 1=little-endian, 2=big-endian
        
        if (elfClass != 1 && elfClass != 2)
            return result;
        if (elfData != 1 && elfData != 2)
            return result;
        
        bool is64Bit = (elfClass == 2);
        bool isLittleEndian = (elfData == 1);
        
        // Parse ELF header to find section headers
        size_t shoff, shentsize, shnum, shstrndx;
        
        if (is64Bit)
        {
            if (bytes.length < 64)
                return result;
            
            shoff = readPointer64(result, 40, isLittleEndian);
            shentsize = readHalf(result, 58, isLittleEndian);
            shnum = readHalf(result, 60, isLittleEndian);
            shstrndx = readHalf(result, 62, isLittleEndian);
        }
        else
        {
            if (bytes.length < 52)
                return result;
            
            shoff = readWord(result, 32, isLittleEndian);
            shentsize = readHalf(result, 46, isLittleEndian);
            shnum = readHalf(result, 48, isLittleEndian);
            shstrndx = readHalf(result, 50, isLittleEndian);
        }
        
        // Verify section headers are within file
        if (shoff == 0 || shoff + (shnum * shentsize) > bytes.length)
            return result;
        
        // Process each section header
        for (size_t i = 0; i < shnum; i++)
        {
            size_t shdrOffset = shoff + (i * shentsize);
            if (shdrOffset + shentsize > bytes.length)
                break;
            
            uint shType;
            size_t shOffset, shSize;
            
            if (is64Bit)
            {
                shType = readWord(result, shdrOffset + 4, isLittleEndian);
                shOffset = readPointer64(result, shdrOffset + 24, isLittleEndian);
                shSize = readPointer64(result, shdrOffset + 32, isLittleEndian);
            }
            else
            {
                shType = readWord(result, shdrOffset + 4, isLittleEndian);
                shOffset = readWord(result, shdrOffset + 16, isLittleEndian);
                shSize = readWord(result, shdrOffset + 20, isLittleEndian);
            }
            
            // SHT_NOTE = 7 (note sections containing build IDs)
            if (shType == 7 && shOffset > 0 && shOffset + shSize <= bytes.length)
                stripNoteSection(result, shOffset, shSize, isLittleEndian);
        }
        
        return result;
    }
    
    /// Strip note section (zero out GNU build IDs)
    private void stripNoteSection(ubyte[] bytes, size_t offset, size_t size, bool isLittleEndian) pure @system
    {
        size_t pos = offset;
        size_t end = offset + size;
        
        while (pos + 12 <= end)
        {
            uint nameSize = readWord(bytes, pos, isLittleEndian);
            uint descSize = readWord(bytes, pos + 4, isLittleEndian);
            uint noteType = readWord(bytes, pos + 8, isLittleEndian);
            
            pos += 12;
            
            // Align name size to 4 bytes
            uint alignedNameSize = (nameSize + 3) & ~3;
            uint alignedDescSize = (descSize + 3) & ~3;
            
            if (pos + alignedNameSize + alignedDescSize > end)
                break;
            
            // Check if this is a GNU build-id note (type 3)
            if (noteType == 3 && nameSize >= 3)
            {
                // Check if name is "GNU"
                if (pos < bytes.length && bytes[pos] == 'G' && 
                    pos + 1 < bytes.length && bytes[pos + 1] == 'N' &&
                    pos + 2 < bytes.length && bytes[pos + 2] == 'U')
                {
                    // Zero out the descriptor (build ID)
                    size_t descOffset = pos + alignedNameSize;
                    for (size_t j = 0; j < descSize && descOffset + j < bytes.length; j++)
                        bytes[descOffset + j] = 0;
                }
            }
            
            pos += alignedNameSize + alignedDescSize;
        }
    }
    
    /// Read 16-bit half-word
    private ushort readHalf(ubyte[] bytes, size_t offset, bool isLittleEndian) pure @system
    {
        if (offset + 2 > bytes.length)
            return 0;
        
        if (isLittleEndian)
            return cast(ushort)(bytes[offset] | (bytes[offset + 1] << 8));
        else
            return cast(ushort)((bytes[offset] << 8) | bytes[offset + 1]);
    }
    
    /// Read 32-bit word
    private uint readWord(ubyte[] bytes, size_t offset, bool isLittleEndian) pure @system
    {
        if (offset + 4 > bytes.length)
            return 0;
        
        if (isLittleEndian)
            return bytes[offset] | (bytes[offset + 1] << 8) | 
                   (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
        else
            return (bytes[offset] << 24) | (bytes[offset + 1] << 16) | 
                   (bytes[offset + 2] << 8) | bytes[offset + 3];
    }
    
    /// Read 64-bit pointer
    private ulong readPointer64(ubyte[] bytes, size_t offset, bool isLittleEndian) pure @system
    {
        if (offset + 8 > bytes.length)
            return 0;
        
        if (isLittleEndian)
        {
            return cast(ulong)bytes[offset] |
                   (cast(ulong)bytes[offset + 1] << 8) |
                   (cast(ulong)bytes[offset + 2] << 16) |
                   (cast(ulong)bytes[offset + 3] << 24) |
                   (cast(ulong)bytes[offset + 4] << 32) |
                   (cast(ulong)bytes[offset + 5] << 40) |
                   (cast(ulong)bytes[offset + 6] << 48) |
                   (cast(ulong)bytes[offset + 7] << 56);
        }
        else
        {
            return (cast(ulong)bytes[offset] << 56) |
                   (cast(ulong)bytes[offset + 1] << 48) |
                   (cast(ulong)bytes[offset + 2] << 40) |
                   (cast(ulong)bytes[offset + 3] << 32) |
                   (cast(ulong)bytes[offset + 4] << 24) |
                   (cast(ulong)bytes[offset + 5] << 16) |
                   (cast(ulong)bytes[offset + 6] << 8) |
                   cast(ulong)bytes[offset + 7];
        }
    }
    
    /// Strip archive metadata (timestamps, UIDs, GIDs)
    ubyte[] stripArchiveMetadata(ubyte[] bytes) @system
    {
        if (bytes.length < 8)
            return bytes.dup;
        
        // Check for archive magic
        if (bytes[0] != '!' || bytes[1] != '<' || bytes[2] != 'a' || 
            bytes[3] != 'r' || bytes[4] != 'c' || bytes[5] != 'h' || 
            bytes[6] != '>' || bytes[7] != '\n')
            return bytes.dup;
        
        auto result = bytes.dup;
        size_t offset = 8; // Skip magic
        
        // Process each archive member
        while (offset + 60 <= result.length)
        {
            // Archive member header is 60 bytes:
            // 0-15:  File name
            // 16-27: Timestamp (12 bytes) - ZERO THIS
            // 28-33: UID (6 bytes) - ZERO THIS
            // 34-39: GID (6 bytes) - ZERO THIS
            // 40-47: File mode
            // 48-57: File size
            // 58-59: Magic ("`\n")
            
            // Zero out timestamp (bytes 16-27)
            foreach (i; 16..28)
                result[offset + i] = ' ';
            
            // Zero out UID (bytes 28-33)
            foreach (i; 28..34)
                result[offset + i] = ' ';
            
            // Zero out GID (bytes 34-39)
            foreach (i; 34..40)
                result[offset + i] = ' ';
            
            // Get file size and skip to next member
            import std.string : strip;
            import std.conv : parse;
            
            try
            {
                auto sizeStr = cast(string)result[offset+48..offset+58].strip();
                auto fileSize = parse!size_t(sizeStr);
                offset += 60 + fileSize;
                
                // Archive members are 2-byte aligned
                if (offset % 2 == 1)
                    offset++;
            }
            catch (Exception)
            {
                break; // Malformed archive
            }
        }
        
        return result;
    }
    
    /// Strip object file metadata
    ubyte[] stripObjectMetadata(ubyte[] bytes) pure @system
    {
        // Object files vary by platform (ELF, Mach-O, COFF)
        // For now, just return a copy
        // Full implementation would parse object format and strip:
        // - Timestamps in headers
        // - Debug info timestamps
        // - Source file paths (optionally)
        return bytes.dup;
    }
    
    /// Compare ELF files structurally
    FileComparison compareELFStructure(string path1, string path2) @system
    {
        FileComparison comparison;
        comparison.filePath = baseName(path1);
        
        // Simplified: Compare after stripping metadata
        auto bytes1 = cast(ubyte[])read(path1);
        auto bytes2 = cast(ubyte[])read(path2);
        
        auto stripped1 = stripELFMetadata(bytes1);
        auto stripped2 = stripELFMetadata(bytes2);
        
        comparison.hash1 = FastHash.hashBytes(stripped1);
        comparison.hash2 = FastHash.hashBytes(stripped2);
        comparison.matches = (comparison.hash1 == comparison.hash2);
        
        if (!comparison.matches)
            comparison.differences = ["ELF structures differ"];
        
        return comparison;
    }
    
    /// Compare archive files structurally
    FileComparison compareArchiveStructure(string path1, string path2) @system
    {
        FileComparison comparison;
        comparison.filePath = baseName(path1);
        
        // Compare after stripping archive metadata
        auto bytes1 = cast(ubyte[])read(path1);
        auto bytes2 = cast(ubyte[])read(path2);
        
        auto stripped1 = stripArchiveMetadata(bytes1);
        auto stripped2 = stripArchiveMetadata(bytes2);
        
        comparison.hash1 = FastHash.hashBytes(stripped1);
        comparison.hash2 = FastHash.hashBytes(stripped2);
        comparison.matches = (comparison.hash1 == comparison.hash2);
        
        if (!comparison.matches)
            comparison.differences = ["Archive contents differ"];
        
        return comparison;
    }
    
    /// Compare object files structurally
    FileComparison compareObjectStructure(string path1, string path2) @system
    {
        FileComparison comparison;
        comparison.filePath = baseName(path1);
        
        // Compare after stripping metadata
        auto bytes1 = cast(ubyte[])read(path1);
        auto bytes2 = cast(ubyte[])read(path2);
        
        auto stripped1 = stripObjectMetadata(bytes1);
        auto stripped2 = stripObjectMetadata(bytes2);
        
        comparison.hash1 = FastHash.hashBytes(stripped1);
        comparison.hash2 = FastHash.hashBytes(stripped2);
        comparison.matches = (comparison.hash1 == comparison.hash2);
        
        if (!comparison.matches)
            comparison.differences = ["Object structures differ"];
        
        return comparison;
    }
    
    /// Collect all files in directory recursively
    string[] collectFiles(string dir) @system
    {
        import std.file : isFile;
        
        return dirEntries(dir, SpanMode.breadth)
            .filter!(e => e.isFile)
            .map!(e => e.name)
            .array;
    }
}

@system unittest
{
    import std.stdio : writeln, File;
    import std.file : mkdirRecurse, rmdirRecurse, write;
    
    writeln("Testing determinism verifier...");
    
    // Create test files
    immutable testDir = "/tmp/builder-verifier-test";
    mkdirRecurse(testDir);
    scope(exit) rmdirRecurse(testDir);
    
    auto file1 = buildPath(testDir, "test1.txt");
    auto file2 = buildPath(testDir, "test2.txt");
    auto file3 = buildPath(testDir, "test3.txt");
    
    // Write identical content
    write(file1, "deterministic content");
    write(file2, "deterministic content");
    write(file3, "different content");
    
    auto verifier = DeterminismVerifier.create();
    
    // Test matching files
    auto result1 = verifier.verifyFile(file1, file2);
    assert(result1.isOk);
    assert(result1.unwrap());
    
    // Test non-matching files
    auto result2 = verifier.verifyFile(file1, file3);
    assert(result2.isOk);
    assert(!result2.unwrap());
    
    writeln("✓ Determinism verifier tests passed");
}

