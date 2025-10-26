module languages.compiled.d.tooling.tools;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import utils.logging.logger;

/// D formatter (dfmt) integration
class DFormatter
{
    /// Check if dfmt is available
    static bool isAvailable()
    {
        try
        {
            auto res = execute(["dfmt", "--version"]);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Get dfmt version
    static string getVersion()
    {
        try
        {
            auto res = execute(["dfmt", "--version"]);
            if (res.status == 0)
            {
                return res.output.strip();
            }
        }
        catch (Exception e)
        {
        }
        return "unknown";
    }
    
    /// Format D source files
    static auto format(string[] sources, string configFile = "", bool checkOnly = false)
    {
        string[] cmd = ["dfmt"];
        
        // Check only mode
        if (checkOnly)
        {
            cmd ~= "--check";
        }
        else
        {
            cmd ~= "--inplace";
        }
        
        // Config file
        if (!configFile.empty && exists(configFile))
        {
            cmd ~= "--config=" ~ configFile;
        }
        
        // Add source files
        cmd ~= sources;
        
        return execute(cmd);
    }
    
    /// Format a single file
    static auto formatFile(string source, string configFile = "", bool checkOnly = false)
    {
        return format([source], configFile, checkOnly);
    }
    
    /// Format directory recursively
    static auto formatDirectory(string dir, string configFile = "", bool checkOnly = false)
    {
        string[] sources;
        
        // Collect all .d files
        foreach (entry; dirEntries(dir, "*.d", SpanMode.breadth))
        {
            if (isFile(entry))
            {
                sources ~= entry.name;
            }
        }
        
        if (sources.empty)
        {
            auto result = execute(["echo", "No .d files found in directory"]);
            return result;
        }
        
        return format(sources, configFile, checkOnly);
    }
}

/// D static analyzer (dscanner) integration
class DScanner
{
    /// Check if dscanner is available
    static bool isAvailable()
    {
        try
        {
            auto res = execute(["dscanner", "--version"]);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Get dscanner version
    static string getVersion()
    {
        try
        {
            auto res = execute(["dscanner", "--version"]);
            if (res.status == 0)
            {
                return res.output.strip();
            }
        }
        catch (Exception e)
        {
        }
        return "unknown";
    }
    
    /// Run linter on source files
    static auto lint(
        string[] sources,
        string configFile = "",
        bool styleCheck = true,
        bool syntaxCheck = true,
        string reportFormat = "stylish"
    )
    {
        string[] cmd = ["dscanner"];
        
        // Lint mode
        cmd ~= "--styleCheck";
        
        // Config file
        if (!configFile.empty && exists(configFile))
        {
            cmd ~= "--config=" ~ configFile;
        }
        
        // Report format
        if (!reportFormat.empty)
        {
            cmd ~= "--reportFormat=" ~ reportFormat;
        }
        
        // Add source files
        cmd ~= sources;
        
        return execute(cmd);
    }
    
    /// Syntax check
    static auto syntaxCheck(string[] sources)
    {
        string[] cmd = ["dscanner", "--syntaxCheck"];
        cmd ~= sources;
        return execute(cmd);
    }
    
    /// Generate ctags
    static auto generateCtags(string[] sources, string outputFile = "tags")
    {
        string[] cmd = ["dscanner", "--ctags"];
        cmd ~= sources;
        
        auto res = execute(cmd);
        
        if (res.status == 0 && !outputFile.empty)
        {
            try
            {
                std.file.write(outputFile, res.output);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to write ctags file: " ~ e.msg);
            }
        }
        
        return res;
    }
    
    /// Generate etags
    static auto generateEtags(string[] sources, string outputFile = "TAGS")
    {
        string[] cmd = ["dscanner", "--etags"];
        cmd ~= sources;
        
        auto res = execute(cmd);
        
        if (res.status == 0 && !outputFile.empty)
        {
            try
            {
                std.file.write(outputFile, res.output);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to write etags file: " ~ e.msg);
            }
        }
        
        return res;
    }
    
    /// Find symbol definition
    static auto findSymbol(string[] sources, string symbolName)
    {
        string[] cmd = ["dscanner", "--symbol", symbolName];
        cmd ~= sources;
        return execute(cmd);
    }
    
    /// List all imports in files
    static auto listImports(string[] sources)
    {
        string[] cmd = ["dscanner", "--imports"];
        cmd ~= sources;
        return execute(cmd);
    }
    
    /// Detect code duplicates
    static auto detectDuplicates(string[] sources)
    {
        string[] cmd = ["dscanner", "--sloc"];
        cmd ~= sources;
        return execute(cmd);
    }
}

/// DUB test runner
class DubTest
{
    /// Run DUB tests
    static auto runTests(
        string projectDir,
        string compiler = "",
        bool verbose = false,
        string filter = ""
    )
    {
        string[] cmd = ["dub", "test"];
        
        // Set working directory
        if (projectDir.empty)
        {
            projectDir = getcwd();
        }
        
        // Compiler selection
        if (!compiler.empty)
        {
            cmd ~= "--compiler=" ~ compiler;
        }
        
        // Verbose
        if (verbose)
        {
            cmd ~= "--verbose";
        }
        
        // Filter
        if (!filter.empty)
        {
            cmd ~= "--" ~ filter;
        }
        
        return execute(cmd, null, std.process.Config.none, size_t.max, projectDir);
    }
    
    /// Run DUB tests with coverage
    static auto runTestsWithCoverage(
        string projectDir,
        string compiler = "",
        bool verbose = false
    )
    {
        string[] cmd = ["dub", "test", "--build=unittest-cov"];
        
        if (projectDir.empty)
        {
            projectDir = getcwd();
        }
        
        if (!compiler.empty)
        {
            cmd ~= "--compiler=" ~ compiler;
        }
        
        if (verbose)
        {
            cmd ~= "--verbose";
        }
        
        return execute(cmd, null, std.process.Config.none, size_t.max, projectDir);
    }
}

/// D documentation generator
class DDoc
{
    /// Generate documentation using DMD/LDC
    static auto generateDocs(
        string[] sources,
        string outputDir = "docs",
        string compiler = "dmd",
        string[] importPaths = []
    )
    {
        // Create output directory
        if (!exists(outputDir))
        {
            mkdirRecurse(outputDir);
        }
        
        string[] cmd = [compiler];
        cmd ~= "-D";
        cmd ~= "-Dd" ~ outputDir;
        
        // Import paths
        foreach (importPath; importPaths)
        {
            cmd ~= "-I" ~ importPath;
        }
        
        // Source files
        cmd ~= sources;
        
        return execute(cmd);
    }
    
    /// Generate JSON description
    static auto generateJSON(
        string[] sources,
        string outputFile = "output.json",
        string compiler = "dmd",
        string[] importPaths = []
    )
    {
        string[] cmd = [compiler];
        cmd ~= "-X";
        cmd ~= "-Xf" ~ outputFile;
        
        // Import paths
        foreach (importPath; importPaths)
        {
            cmd ~= "-I" ~ importPath;
        }
        
        // Source files
        cmd ~= sources;
        
        return execute(cmd);
    }
}


