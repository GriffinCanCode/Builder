module tests.adapters.cache_adapter;

/// Adapter to make cache property tests work with actual cache API
/// Provides simplified interface for testing cache key generation

import std.digest.sha : sha256Of, toHexString;
import std.string : representation;
import std.array;
import std.algorithm;

/// Simplified cache key generator for property tests
struct CacheKeyGenerator
{
    /// Generate cache key from string
    static string fromString(string input) pure @safe
    {
        return sha256Of(input.representation).toHexString().idup;
    }
    
    /// Generate cache key from multiple parts
    static string fromParts(string[] parts) pure @safe
    {
        // Concatenate parts with separator to ensure order matters
        auto combined = parts.join("\x00");
        return sha256Of(combined.representation).toHexString().idup;
    }
}

/// Simplified content hasher for property tests
struct ContentHasher
{
    /// Hash string content
    static string hashString(string content) pure @safe
    {
        return sha256Of(content.representation).toHexString().idup;
    }
}

