module infrastructure.errors.utils.fuzzy;

import std.algorithm : min, max, map, filter, sort;
import std.array : array, empty;
import std.string : toLower;
import std.conv : to;
import std.range : take;

/// Calculate Levenshtein distance between two strings
/// Used for finding similar strings in error suggestions
size_t levenshteinDistance(string s1, string s2) pure nothrow @safe
{
    if (s1.empty)
        return s2.length;
    if (s2.empty)
        return s1.length;
    
    // Use dynamic programming approach
    auto len1 = s1.length;
    auto len2 = s2.length;
    
    // Create distance matrix
    size_t[] prevRow = new size_t[len2 + 1];
    size_t[] currRow = new size_t[len2 + 1];
    
    // Initialize first row
    foreach (j; 0 .. len2 + 1)
        prevRow[j] = j;
    
    // Calculate distances
    foreach (i; 1 .. len1 + 1)
    {
        currRow[0] = i;
        
        foreach (j; 1 .. len2 + 1)
        {
            size_t cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
            
            currRow[j] = min(
                prevRow[j] + 1,      // deletion
                currRow[j - 1] + 1,  // insertion
                prevRow[j - 1] + cost // substitution
            );
        }
        
        // Swap rows
        auto temp = prevRow;
        prevRow = currRow;
        currRow = temp;
    }
    
    return prevRow[len2];
}

/// Calculate similarity score (0.0 to 1.0)
double similarityScore(string s1, string s2) pure nothrow @safe
{
    if (s1.empty && s2.empty)
        return 1.0;
    if (s1.empty || s2.empty)
        return 0.0;
    
    auto distance = levenshteinDistance(s1.toLower(), s2.toLower());
    auto maxLen = max(s1.length, s2.length);
    
    return 1.0 - (cast(double)distance / cast(double)maxLen);
}

/// Find similar strings from candidates
/// Returns up to maxResults matches with similarity >= threshold
string[] findSimilar(string target, const(string)[] candidates, double threshold = 0.6, size_t maxResults = 3) nothrow
{
    try
    {
        if (target.empty || candidates.empty)
            return [];
        
        struct Match
        {
            string text;
            double score;
        }
        
        Match[] matches;
        matches.reserve(candidates.length);
        
        foreach (candidate; candidates)
        {
            auto score = similarityScore(target, candidate);
            if (score >= threshold)
                matches ~= Match(candidate, score);
        }
        
        // Sort by score descending
        matches.sort!((a, b) => a.score > b.score);
        
        // Return top matches
        size_t count = min(maxResults, matches.length);
        string[] result = new string[count];
        
        foreach (i; 0 .. count)
            result[i] = matches[i].text;
        
        return result;
    }
    catch (Exception e)
    {
        return [];
    }
}

/// Create "did you mean?" suggestion message
string didYouMean(string target, const(string)[] candidates, size_t maxSuggestions = 3) nothrow
{
    auto similar = findSimilar(target, candidates, 0.6, maxSuggestions);
    
    if (similar.empty)
        return "";
    
    if (similar.length == 1)
        return "Did you mean '" ~ similar[0] ~ "'?";
    
    string result = "Did you mean one of these?\n";
    foreach (i, suggestion; similar)
    {
        result ~= "  - " ~ suggestion;
        if (i < similar.length - 1)
            result ~= "\n";
    }
    
    return result;
}

/// Check if string matches case-insensitively
bool matchesIgnoreCase(string s1, string s2) pure nothrow @safe
{
    try
    {
        return s1.toLower() == s2.toLower();
    }
    catch (Exception e)
    {
        return false;
    }
}

/// Find exact match ignoring case
string findCaseInsensitiveMatch(string target, const(string)[] candidates) nothrow
{
    foreach (candidate; candidates)
    {
        if (matchesIgnoreCase(target, candidate))
            return candidate;
    }
    return "";
}

