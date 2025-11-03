module tests.unit.utils.simd_hash;

import tests.harness;
import infrastructure.utils.simd.hash;
import std.array : replicate;

/// Test standard SIMD-accelerated hash comparison
@("SIMDHash.equals - standard comparison")
unittest
{
    // Typical BLAKE3 hex hashes (64 chars)
    immutable a = "7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069";
    immutable b = "7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069";
    immutable c = "8f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069";
    
    assert(SIMDHash.equals(a, b), "Identical hashes should match");
    assert(!SIMDHash.equals(a, c), "Different hashes should not match");
    assert(SIMDHash.equals("", ""), "Empty strings should match");
    assert(!SIMDHash.equals("a", "b"), "Different single chars should not match");
    
    // Length mismatch
    assert(!SIMDHash.equals("short", "longer hash"), "Different lengths should not match");
    
    // Short strings (below SIMD threshold)
    assert(SIMDHash.equals("abc", "abc"), "Short identical strings should match");
    assert(!SIMDHash.equals("abc", "abd"), "Short different strings should not match");
}

/// Test constant-time comparison for security
@("SIMDHash.constantTimeEquals - timing-attack resistant")
unittest
{
    // Create 64-char hashes
    immutable hash1 = "deadbeef" ~ "0".replicate(56);
    immutable hash2 = "deadbeef" ~ "0".replicate(56);
    immutable hash3 = "deadbeef" ~ "1".replicate(56);
    immutable hash4 = "1eadbeef" ~ "0".replicate(56);  // First byte different
    
    assert(SIMDHash.constantTimeEquals(hash1, hash2), "Identical hashes should match");
    assert(!SIMDHash.constantTimeEquals(hash1, hash3), "Different hashes should not match");
    assert(!SIMDHash.constantTimeEquals(hash1, hash4), "First-byte difference should be detected");
    
    // Empty strings
    assert(SIMDHash.constantTimeEquals("", ""), "Empty strings should match");
    
    // Length mismatch (can short-circuit on length for constant-time)
    assert(!SIMDHash.constantTimeEquals("short", "longer"), "Length mismatch should fail");
}

/// Test batch hash validation
@("SIMDHash.batchEquals - parallel validation")
unittest
{
    string[] hashesA = [
        "aaaa0000" ~ "0".replicate(56),
        "bbbb1111" ~ "1".replicate(56),
        "cccc2222" ~ "2".replicate(56),
        "dddd3333" ~ "3".replicate(56),
        "eeee4444" ~ "4".replicate(56),
        "ffff5555" ~ "5".replicate(56),
        "0000aaaa" ~ "6".replicate(56),
        "1111bbbb" ~ "7".replicate(56)
    ];
    
    string[] hashesB = [
        "aaaa0000" ~ "0".replicate(56),  // match
        "bbbb0000" ~ "1".replicate(56),  // no match
        "cccc2222" ~ "2".replicate(56),  // match
        "ffff0000" ~ "3".replicate(56),  // no match
        "eeee4444" ~ "4".replicate(56),  // match
        "ffff5555" ~ "5".replicate(56),  // match
        "0000aaaa" ~ "6".replicate(56),  // match
        "different" ~ "7".replicate(55)  // no match
    ];
    
    auto results = SIMDHash.batchEquals(hashesA, hashesB);
    
    assert(results.length == 8, "Should have 8 results");
    assert(results[0] == true, "Index 0 should match");
    assert(results[1] == false, "Index 1 should not match");
    assert(results[2] == true, "Index 2 should match");
    assert(results[3] == false, "Index 3 should not match");
    assert(results[4] == true, "Index 4 should match");
    assert(results[5] == true, "Index 5 should match");
    assert(results[6] == true, "Index 6 should match");
    assert(results[7] == false, "Index 7 should not match");
}

/// Test batch equals with small batches (sequential path)
@("SIMDHash.batchEquals - small batch sequential")
unittest
{
    string[] hashesA = ["aaa", "bbb", "ccc"];
    string[] hashesB = ["aaa", "xxx", "ccc"];
    
    auto results = SIMDHash.batchEquals(hashesA, hashesB);
    
    assert(results.length == 3);
    assert(results[0] == true);
    assert(results[1] == false);
    assert(results[2] == true);
}

/// Test batch equals with empty arrays
@("SIMDHash.batchEquals - empty arrays")
unittest
{
    string[] empty;
    auto results = SIMDHash.batchEquals(empty, empty);
    assert(results.length == 0, "Empty input should produce empty output");
}

/// Test hash prefix matching
@("SIMDHash.hasPrefix - prefix detection")
unittest
{
    immutable hash = "7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069";
    
    assert(SIMDHash.hasPrefix(hash, "7f83"), "Should match 4-char prefix");
    assert(SIMDHash.hasPrefix(hash, "7f83b165"), "Should match 8-char prefix");
    assert(SIMDHash.hasPrefix(hash, "7f83b1657ff1fc53b92dc181"), "Should match long prefix");
    assert(SIMDHash.hasPrefix(hash, ""), "Empty prefix should match");
    assert(SIMDHash.hasPrefix(hash, hash), "Full hash as prefix should match");
    
    assert(!SIMDHash.hasPrefix(hash, "8f83"), "Wrong prefix should not match");
    assert(!SIMDHash.hasPrefix(hash, "7f84"), "Close prefix should not match");
    
    // Prefix longer than hash
    immutable tooLong = hash ~ "extra";
    assert(!SIMDHash.hasPrefix(hash, tooLong), "Prefix longer than hash should not match");
}

/// Test batch prefix search
@("SIMDHash.findWithPrefix - batch prefix matching")
unittest
{
    string[] hashes = [
        "7f83b1657ff1fc53",  // matches
        "8a92c4571ab2de89",
        "7f83d8721bb3ef12",  // matches
        "9f12e4567cc2ab34",
        "7f83aaaabbbbcccc",  // matches
        "7f84000000000000",  // doesn't match (7f84 not 7f83)
    ];
    
    auto matches = SIMDHash.findWithPrefix(hashes, "7f83");
    
    assert(matches.length == 3, "Should find 3 matches");
    assert(matches[0] == 0, "First match at index 0");
    assert(matches[1] == 2, "Second match at index 2");
    assert(matches[2] == 4, "Third match at index 4");
}

/// Test prefix search with empty prefix
@("SIMDHash.findWithPrefix - empty prefix")
unittest
{
    string[] hashes = ["aaa", "bbb", "ccc"];
    auto matches = SIMDHash.findWithPrefix(hashes, "");
    assert(matches.length == 0, "Empty prefix should return no matches");
}

/// Test prefix search with no matches
@("SIMDHash.findWithPrefix - no matches")
unittest
{
    string[] hashes = ["aaa111", "bbb222", "ccc333"];
    auto matches = SIMDHash.findWithPrefix(hashes, "zzz");
    assert(matches.length == 0, "No matching prefix should return empty array");
}

/// Test counting matching bytes
@("SIMDHash.countMatches - byte similarity")
unittest
{
    immutable a = "7f83b165";
    immutable b = "7f83c165";
    
    auto matches = SIMDHash.countMatches(a, b);
    assert(matches == 7, "7 out of 8 bytes should match");
    
    // All match
    immutable c = "12345678";
    immutable d = "12345678";
    matches = SIMDHash.countMatches(c, d);
    assert(matches == 8, "All bytes should match");
    
    // None match
    immutable e = "aaaaaaaa";
    immutable f = "bbbbbbbb";
    matches = SIMDHash.countMatches(e, f);
    assert(matches == 0, "No bytes should match");
    
    // Empty strings
    matches = SIMDHash.countMatches("", "");
    assert(matches == 0, "Empty strings have 0 matching bytes");
}

/// Test counting matches with different lengths
@("SIMDHash.countMatches - different lengths")
unittest
{
    immutable a = "12345678";
    immutable b = "1234";  // Shorter
    
    auto matches = SIMDHash.countMatches(a, b);
    assert(matches == 4, "Should compare only min length");
    
    matches = SIMDHash.countMatches(b, a);
    assert(matches == 4, "Order shouldn't matter");
}

/// Performance comparison test (informational)
@("SIMDHash.equals - performance threshold behavior")
unittest
{
    // Below threshold (32 bytes) - should use scalar
    immutable short1 = "0123456789abcdef0123456789abcd";  // 30 chars
    immutable short2 = "0123456789abcdef0123456789abcd";
    assert(SIMDHash.equals(short1, short2), "Below threshold should work");
    
    // At threshold (32 bytes) - should use SIMD
    immutable exact = "0123456789abcdef0123456789abcdef";  // 32 chars
    immutable exact2 = "0123456789abcdef0123456789abcdef";
    assert(SIMDHash.equals(exact, exact2), "At threshold should work");
    
    // Above threshold (64 bytes) - definitely SIMD
    immutable long1 = "0".replicate(64);
    immutable long2 = "0".replicate(64);
    assert(SIMDHash.equals(long1, long2), "Above threshold should work");
}

/// Test edge cases and boundary conditions
@("SIMDHash - edge cases")
unittest
{
    // Single character
    assert(SIMDHash.equals("a", "a"));
    assert(!SIMDHash.equals("a", "b"));
    
    // Very long hashes
    immutable veryLong1 = "a".replicate(1024);
    immutable veryLong2 = "a".replicate(1024);
    immutable veryLong3 = "a".replicate(1023) ~ "b";
    
    assert(SIMDHash.equals(veryLong1, veryLong2), "Very long identical should match");
    assert(!SIMDHash.equals(veryLong1, veryLong3), "Very long with last byte different");
    
    // Null-like behavior (empty strings)
    assert(SIMDHash.equals("", ""));
    assert(SIMDHash.constantTimeEquals("", ""));
    assert(SIMDHash.hasPrefix("anything", ""));
}


