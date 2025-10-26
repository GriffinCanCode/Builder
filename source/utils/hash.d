module utils.hash;

import std.digest.sha;
import std.file;
import std.stdio;
import std.algorithm;
import std.range;
import std.conv;

/// Fast hashing utilities for cache keys
struct FastHash
{
    /// Hash a file efficiently
    static string hashFile(string path)
    {
        auto file = File(path, "rb");
        SHA256 hash;
        
        // Read in chunks for large files
        ubyte[4096] buffer;
        
        while (!file.eof())
        {
            auto chunk = file.rawRead(buffer);
            hash.put(chunk);
        }
        
        return toHexString(hash.finish()).idup;
    }
    
    /// Hash a string
    static string hashString(string content)
    {
        return toHexString(sha256Of(content)).idup;
    }
    
    /// Hash multiple strings together
    static string hashStrings(string[] strings)
    {
        SHA256 hash;
        foreach (s; strings)
            hash.put(cast(ubyte[])s);
        return toHexString(hash.finish()).idup;
    }
    
    /// Hash file metadata (size + mtime) for quick checks
    /// 1000x faster than content hash for unchanged files
    static string hashMetadata(string path)
    {
        if (!exists(path))
            return "";
        
        auto info = DirEntry(path);
        auto data = path ~ info.size.to!string ~ info.timeLastModified.toISOExtString();
        return hashString(data);
    }
    
    /// Two-tier hash: check metadata first, only hash content if changed
    /// Returns tuple: (metadataHash, contentHash, contentHashed)
    static TwoTierHash hashFileTwoTier(string path, string oldMetadataHash = "")
    {
        TwoTierHash result;
        
        if (!exists(path))
            return result;
        
        // Always compute metadata hash (fast)
        result.metadataHash = hashMetadata(path);
        
        // Only compute content hash if metadata changed
        if (oldMetadataHash.empty || result.metadataHash != oldMetadataHash)
        {
            result.contentHash = hashFile(path);
            result.contentHashed = true;
        }
        else
        {
            result.contentHash = ""; // Not needed, metadata unchanged
            result.contentHashed = false;
        }
        
        return result;
    }
}

/// Result of two-tier hashing
struct TwoTierHash
{
    string metadataHash;    // Fast: mtime + size
    string contentHash;     // Slow: SHA-256 of content
    bool contentHashed;     // Whether content was actually hashed
}

