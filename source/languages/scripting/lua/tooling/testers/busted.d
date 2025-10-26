module languages.scripting.lua.tooling.testers.busted;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.regex;
import std.conv;
import languages.scripting.lua.tooling.testers.base;
import languages.scripting.lua.tooling.detection;
import languages.scripting.lua.core.config;
import config.schema.schema;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// Busted test framework - elegant BDD-style testing
class BustedTester : Tester
{
    override TestResult runTests(
        string[] sources,
        LuaConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        TestResult result;
        
        if (!isAvailable())
        {
            result.error = "Busted is not installed";
            return result;
        }
        
        string[] cmd = ["busted"];
        
        // Verbose flag
        if (config.test.verbose)
        {
            cmd ~= "--verbose";
        }
        
        // Output format
        if (!config.test.busted.format.empty)
        {
            cmd ~= "--output";
            cmd ~= config.test.busted.format;
        }
        else if (!config.test.outputFormat.empty)
        {
            cmd ~= "--output";
            cmd ~= config.test.outputFormat;
        }
        
        // Coverage
        if (config.test.coverage)
        {
            cmd ~= "--coverage";
            
            if (!config.test.coverageFile.empty)
            {
                cmd ~= "--coverage-file";
                cmd ~= config.test.coverageFile;
            }
        }
        
        // Tags
        if (!config.test.busted.tags.empty)
        {
            foreach (tag; config.test.busted.tags)
            {
                cmd ~= "--tags";
                cmd ~= tag;
            }
        }
        
        if (!config.test.busted.excludeTags.empty)
        {
            foreach (tag; config.test.busted.excludeTags)
            {
                cmd ~= "--exclude-tags";
                cmd ~= tag;
            }
        }
        
        // Shuffle tests
        if (config.test.busted.shuffle)
        {
            cmd ~= "--shuffle";
            
            if (config.test.busted.seed > 0)
            {
                cmd ~= "--seed";
                cmd ~= config.test.busted.seed.to!string;
            }
        }
        
        // Fail fast
        if (config.test.busted.failFast)
        {
            cmd ~= "--lazy";
        }
        
        // Lazy loading
        if (config.test.busted.lazyLoad)
        {
            cmd ~= "--lazy";
        }
        
        // Add test paths
        if (!config.test.testPaths.empty)
        {
            cmd ~= config.test.testPaths;
        }
        else
        {
            // Use sources as test files
            cmd ~= sources;
        }
        
        Logger.debug_("Running Busted: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        // Parse Busted output
        parseOutput(res.output, result);
        
        if (res.status != 0)
        {
            result.success = false;
            if (result.error.empty)
            {
                result.error = "Tests failed";
            }
        }
        else
        {
            result.success = true;
        }
        
        // Check coverage threshold
        if (config.test.failUnderCoverage && result.coveragePercent < config.test.minCoverage)
        {
            result.success = false;
            result.error = "Coverage " ~ result.coveragePercent.to!string ~ 
                          "% is below minimum " ~ config.test.minCoverage.to!string ~ "%";
        }
        
        result.outputHash = FastHash.hashStrings(sources);
        
        return result;
    }
    
    override bool isAvailable()
    {
        return isBustedAvailable();
    }
    
    override string name() const
    {
        return "Busted";
    }
    
    override string getVersion()
    {
        try
        {
            auto res = execute(["busted", "--version"]);
            if (res.status == 0)
            {
                auto output = res.output.strip;
                auto match = matchFirst(output, regex(r"(\d+\.\d+\.\d+)"));
                if (!match.empty)
                {
                    return match[1];
                }
            }
        }
        catch (Exception) {}
        
        return "unknown";
    }
    
    private void parseOutput(string output, ref TestResult result)
    {
        // Parse Busted output for test results
        // Example: "123 successes / 5 failures / 0 errors / 2 pending : 0.123456 seconds"
        
        auto successMatch = matchFirst(output, regex(r"(\d+)\s+success"));
        if (!successMatch.empty)
        {
            result.testsPassed = successMatch[1].to!int;
        }
        
        auto failureMatch = matchFirst(output, regex(r"(\d+)\s+failure"));
        if (!failureMatch.empty)
        {
            result.testsFailed = failureMatch[1].to!int;
        }
        
        auto pendingMatch = matchFirst(output, regex(r"(\d+)\s+pending"));
        if (!pendingMatch.empty)
        {
            result.testsSkipped = pendingMatch[1].to!int;
        }
        
        // Parse coverage if present
        auto coverageMatch = matchFirst(output, regex(r"(\d+\.\d+)%\s+coverage"));
        if (!coverageMatch.empty)
        {
            result.coveragePercent = coverageMatch[1].to!float;
        }
        
        // Extract error messages
        if (result.testsFailed > 0)
        {
            auto errorMatches = matchAll(output, regex(r"Failure\s*→\s*(.+)"));
            string[] errors;
            foreach (match; errorMatches)
            {
                errors ~= match[1];
            }
            if (!errors.empty)
            {
                result.error = errors.join("\n");
            }
        }
    }
}

