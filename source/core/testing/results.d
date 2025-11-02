module core.testing.results;

import std.datetime : Duration, dur;
import std.algorithm : map, filter, sum;
import std.array : array;
import std.range : empty;
import std.conv : to;

/// Result of a single test case execution
struct TestCase
{
    string name;             /// Test case name
    bool passed;             /// Whether test passed
    Duration duration;       /// Execution time
    string failureMessage;   /// Error message if failed
    string stdout;           /// Captured stdout
    string stderr;           /// Captured stderr
    
    /// Create passing test case
    static TestCase pass(string name, Duration duration) pure nothrow @system
    {
        TestCase tc;
        tc.name = name;
        tc.passed = true;
        tc.duration = duration;
        return tc;
    }
    
    /// Create failing test case
    static TestCase fail(string name, Duration duration, string message) pure nothrow @system
    {
        TestCase tc;
        tc.name = name;
        tc.passed = false;
        tc.duration = duration;
        tc.failureMessage = message;
        return tc;
    }
}

/// Result of executing a test target
struct TestResult
{
    string targetId;         /// Fully qualified target ID
    bool passed;             /// Overall pass/fail
    Duration duration;       /// Total execution time
    string stdout;           /// Captured stdout
    string stderr;           /// Captured stderr
    TestCase[] cases;        /// Individual test cases (if parseable)
    string errorMessage;     /// Error message if target execution failed
    bool cached;             /// Whether result was from cache
    
    /// Get number of passed test cases
    @property size_t passedCount() const pure nothrow @system
    {
        return cases.filter!(c => c.passed).array.length;
    }
    
    /// Get number of failed test cases
    @property size_t failedCount() const pure nothrow @system
    {
        return cases.filter!(c => !c.passed).array.length;
    }
    
    /// Get total number of test cases
    @property size_t totalCount() const pure nothrow @system
    {
        return cases.length;
    }
    
    /// Get total duration of all test cases
    @property Duration totalDuration() const pure nothrow @system
    {
        if (cases.empty)
            return duration;
        
        Duration total;
        foreach (tc; cases)
            total += tc.duration;
        return total;
    }
    
    /// Create passing test result
    static TestResult pass(string targetId, Duration duration) pure nothrow @system
    {
        TestResult tr;
        tr.targetId = targetId;
        tr.passed = true;
        tr.duration = duration;
        return tr;
    }
    
    /// Create failing test result
    static TestResult fail(string targetId, Duration duration, string error) pure nothrow @system
    {
        TestResult tr;
        tr.targetId = targetId;
        tr.passed = false;
        tr.duration = duration;
        tr.errorMessage = error;
        return tr;
    }
}

/// Aggregated statistics for test execution
struct TestStats
{
    size_t totalTargets;     /// Total test targets executed
    size_t passedTargets;    /// Test targets that passed
    size_t failedTargets;    /// Test targets that failed
    size_t totalCases;       /// Total individual test cases
    size_t passedCases;      /// Individual test cases that passed
    size_t failedCases;      /// Individual test cases that failed
    size_t cachedTargets;    /// Test targets from cache
    Duration totalDuration;  /// Total execution time
    
    /// Compute statistics from test results
    static TestStats compute(const TestResult[] results) pure nothrow @system
    {
        TestStats stats;
        stats.totalTargets = results.length;
        
        foreach (result; results)
        {
            if (result.passed)
                stats.passedTargets++;
            else
                stats.failedTargets++;
            
            if (result.cached)
                stats.cachedTargets++;
            
            stats.totalCases += result.totalCount;
            stats.passedCases += result.passedCount;
            stats.failedCases += result.failedCount;
            stats.totalDuration += result.duration;
        }
        
        return stats;
    }
    
    /// Check if all tests passed
    @property bool allPassed() const pure nothrow @nogc
    {
        return failedTargets == 0 && failedCases == 0;
    }
    
    /// Get target pass rate
    @property double targetPassRate() const pure nothrow @nogc
    {
        if (totalTargets == 0)
            return 0.0;
        return cast(double)passedTargets / totalTargets;
    }
    
    /// Get case pass rate
    @property double casePassRate() const pure nothrow @nogc
    {
        if (totalCases == 0)
            return 0.0;
        return cast(double)passedCases / totalCases;
    }
}

/// Test execution configuration
struct TestConfig
{
    bool verbose;            /// Show detailed output
    bool quiet;              /// Minimal output
    bool showPassed;         /// Show passed tests
    bool failFast;           /// Stop on first failure
    string filter;           /// Target filter pattern
    string coverageFormat;   /// Coverage output format (future)
    bool generateJUnit;      /// Generate JUnit XML output
    string junitPath;        /// Path for JUnit XML output
}

