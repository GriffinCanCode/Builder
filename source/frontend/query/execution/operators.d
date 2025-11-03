module frontend.query.execution.operators;

import std.algorithm;
import std.array;
import engine.graph.graph;

/// Set operations on BuildNode collections
/// 
/// Implements efficient set algebra using D's associative arrays
/// for O(1) membership testing

/// Union: A ∪ B (all elements in A or B)
/// 
/// Complexity: O(|A| + |B|)
/// Memory: O(|A| + |B|) for result set
BuildNode[] union_(BuildNode[] a, BuildNode[] b) @system
{
    bool[BuildNode] set;
    
    foreach (node; a)
        if (node !is null)
            set[node] = true;
    
    foreach (node; b)
        if (node !is null)
            set[node] = true;
    
    return set.keys;
}

/// Intersection: A ∩ B (elements in both A and B)
/// 
/// Complexity: O(|A| + |B|)
/// Memory: O(min(|A|, |B|)) for result set
BuildNode[] intersect(BuildNode[] a, BuildNode[] b) @system
{
    // Optimization: build set from smaller array
    if (b.length < a.length)
    {
        auto temp = a;
        a = b;
        b = temp;
    }
    
    bool[BuildNode] setA;
    foreach (node; a)
        if (node !is null)
            setA[node] = true;
    
    BuildNode[] result;
    bool[BuildNode] seen;  // Prevent duplicates
    
    foreach (node; b)
    {
        if (node !is null && node in setA && node !in seen)
        {
            result ~= node;
            seen[node] = true;
        }
    }
    
    return result;
}

/// Difference: A \ B (elements in A but not in B)
/// 
/// Complexity: O(|A| + |B|)
/// Memory: O(|A|) for result set
BuildNode[] except(BuildNode[] a, BuildNode[] b) @system
{
    bool[BuildNode] setB;
    foreach (node; b)
        if (node !is null)
            setB[node] = true;
    
    BuildNode[] result;
    foreach (node; a)
        if (node !is null && node !in setB)
            result ~= node;
    
    return result;
}

/// Symmetric difference: A △ B (elements in A or B but not both)
/// 
/// Complexity: O(|A| + |B|)
/// Memory: O(|A| + |B|)
BuildNode[] symmetricDifference(BuildNode[] a, BuildNode[] b) @system
{
    bool[BuildNode] setA;
    bool[BuildNode] setB;
    
    foreach (node; a)
        if (node !is null)
            setA[node] = true;
    
    foreach (node; b)
        if (node !is null)
            setB[node] = true;
    
    BuildNode[] result;
    
    // Elements in A but not B
    foreach (node; a)
        if (node !is null && node !in setB)
            result ~= node;
    
    // Elements in B but not A
    foreach (node; b)
        if (node !is null && node !in setA)
            result ~= node;
    
    return result;
}

/// Remove duplicates from array
/// 
/// Complexity: O(n)
/// Memory: O(n)
BuildNode[] unique(BuildNode[] nodes) @system
{
    bool[BuildNode] seen;
    BuildNode[] result;
    
    foreach (node; nodes)
    {
        if (node !is null && node !in seen)
        {
            result ~= node;
            seen[node] = true;
        }
    }
    
    return result;
}

/// Check if two sets are equal
/// 
/// Complexity: O(|A| + |B|)
bool setEqual(BuildNode[] a, BuildNode[] b) @system
{
    if (a.length != b.length)
        return false;
    
    bool[BuildNode] setA;
    foreach (node; a)
        if (node !is null)
            setA[node] = true;
    
    foreach (node; b)
        if (node is null || node !in setA)
            return false;
    
    return true;
}

/// Check if A is a subset of B (A ⊆ B)
/// 
/// Complexity: O(|A| + |B|)
bool isSubset(BuildNode[] a, BuildNode[] b) @system
{
    bool[BuildNode] setB;
    foreach (node; b)
        if (node !is null)
            setB[node] = true;
    
    foreach (node; a)
        if (node is null || node !in setB)
            return false;
    
    return true;
}

/// Check if A is a superset of B (A ⊇ B)
/// 
/// Complexity: O(|A| + |B|)
bool isSuperset(BuildNode[] a, BuildNode[] b) @system
{
    return isSubset(b, a);
}

/// Check if two sets are disjoint (A ∩ B = ∅)
/// 
/// Complexity: O(|A| + |B|)
bool isDisjoint(BuildNode[] a, BuildNode[] b) @system
{
    // Optimization: build set from smaller array
    if (b.length < a.length)
    {
        auto temp = a;
        a = b;
        b = temp;
    }
    
    bool[BuildNode] setA;
    foreach (node; a)
        if (node !is null)
            setA[node] = true;
    
    foreach (node; b)
        if (node !is null && node in setA)
            return false;
    
    return true;
}

/// Cardinality (size) of set
/// 
/// Complexity: O(n)
size_t cardinality(BuildNode[] nodes) @system
{
    bool[BuildNode] set;
    foreach (node; nodes)
        if (node !is null)
            set[node] = true;
    return set.length;
}

