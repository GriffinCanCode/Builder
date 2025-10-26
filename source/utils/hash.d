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
    static string hashMetadata(string path)
    {
        if (!exists(path))
            return "";
        
        auto info = DirEntry(path);
        auto data = path ~ info.size.to!string ~ info.timeLastModified.toISOExtString();
        return hashString(data);
    }
}

