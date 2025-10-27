module languages.scripting.go.tooling.tools;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import utils.logging.logger;
import utils.process : isCommandAvailable;

/// Result of running a Go tool
struct ToolResult
{
    bool success;
    string output;
    string[] warnings;
    string[] errors;
    
    /// Check if tool found issues
    bool hasIssues() const pure nothrow
    {
        return !warnings.empty || !errors.empty;
    }
}

/// Go tooling wrapper - integrates gofmt, govet, linters
class GoTools
{
    /// Check if go command is available
    static bool isGoAvailable()
    {
        auto res = execute(["go", "version"]);
        return res.status == 0;
    }
    
    /// Get Go version
    static string getGoVersion()
    {
        auto res = execute(["go", "version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Format Go source files with gofmt
    static ToolResult format(const string[] sources, bool write = false)
    {
        ToolResult result;
        result.success = true;
        
        if (!isCommandAvailable("gofmt"))
        {
            result.warnings ~= "gofmt not available";
            return result;
        }
        
        foreach (source; sources)
        {
            if (!exists(source))
                continue;
            
            string[] cmd = ["gofmt"];
            if (write)
                cmd ~= "-w";
            cmd ~= source;
            
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.success = false;
                result.errors ~= "gofmt failed on " ~ source ~ ": " ~ res.output;
            }
            else if (!write && !res.output.empty)
            {
                // Non-empty output means file needs formatting
                result.warnings ~= source ~ " needs formatting";
            }
        }
        
        return result;
    }
    
    /// Check Go source with go vet
    static ToolResult vet(string[] packages, string workDir = ".")
    {
        ToolResult result;
        
        if (!isGoAvailable())
        {
            result.warnings ~= "go not available";
            result.success = true; // Don't fail build
            return result;
        }
        
        string[] cmd = ["go", "vet"];
        if (packages.empty)
            cmd ~= "./...";
        else
            cmd ~= packages;
        
        Logger.debugLog("Running go vet: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.success = false;
            result.output = res.output;
            
            // Parse vet output
            foreach (line; res.output.lineSplitter)
            {
                auto trimmed = line.strip;
                if (!trimmed.empty)
                    result.errors ~= trimmed;
            }
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    /// Run golangci-lint (comprehensive linter suite)
    static ToolResult lintGolangCI(string workDir = ".", string[] extraArgs = [])
    {
        ToolResult result;
        
        if (!isCommandAvailable("golangci-lint"))
        {
            result.warnings ~= "golangci-lint not available (install: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)";
            result.success = true; // Don't fail build
            return result;
        }
        
        string[] cmd = ["golangci-lint", "run", "./..."] ~ extraArgs;
        
        Logger.debugLog("Running golangci-lint: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        result.output = res.output;
        
        // golangci-lint returns non-zero if issues found
        if (res.status != 0)
        {
            foreach (line; res.output.lineSplitter)
            {
                auto trimmed = line.strip;
                if (!trimmed.empty)
                    result.warnings ~= trimmed;
            }
        }
        
        result.success = true; // Don't fail build on lint warnings
        
        return result;
    }
    
    /// Run staticcheck (focused static analyzer)
    static ToolResult lintStaticCheck(string workDir = ".")
    {
        ToolResult result;
        
        if (!isCommandAvailable("staticcheck"))
        {
            result.warnings ~= "staticcheck not available (install: go install honnef.co/go/tools/cmd/staticcheck@latest)";
            result.success = true;
            return result;
        }
        
        string[] cmd = ["staticcheck", "./..."];
        
        Logger.debugLog("Running staticcheck: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        result.output = res.output;
        
        if (res.status != 0)
        {
            foreach (line; res.output.lineSplitter)
            {
                auto trimmed = line.strip;
                if (!trimmed.empty)
                    result.warnings ~= trimmed;
            }
        }
        
        result.success = true;
        
        return result;
    }
    
    /// Run golint (classic linter, deprecated but still used)
    static ToolResult lintGoLint(string[] packages, string workDir = ".")
    {
        ToolResult result;
        
        if (!isCommandAvailable("golint"))
        {
            result.warnings ~= "golint not available and deprecated (use golangci-lint instead)";
            result.success = true;
            return result;
        }
        
        string[] cmd = ["golint"];
        if (packages.empty)
            cmd ~= "./...";
        else
            cmd ~= packages;
        
        Logger.debugLog("Running golint: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        result.output = res.output;
        
        foreach (line; res.output.lineSplitter)
        {
            auto trimmed = line.strip;
            if (!trimmed.empty)
                result.warnings ~= trimmed;
        }
        
        result.success = true;
        
        return result;
    }
    
    /// Run go generate
    static ToolResult generate(string[] packages, string workDir = ".")
    {
        ToolResult result;
        
        if (!isGoAvailable())
        {
            result.errors ~= "go not available";
            result.success = false;
            return result;
        }
        
        string[] cmd = ["go", "generate"];
        if (packages.empty)
            cmd ~= "./...";
        else
            cmd ~= packages;
        
        Logger.info("Running go generate: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        result.output = res.output;
        
        if (res.status != 0)
        {
            result.success = false;
            result.errors ~= "go generate failed: " ~ res.output;
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    /// Run go mod tidy
    static ToolResult modTidy(string workDir = ".")
    {
        ToolResult result;
        
        if (!isGoAvailable())
        {
            result.errors ~= "go not available";
            result.success = false;
            return result;
        }
        
        string[] cmd = ["go", "mod", "tidy"];
        
        Logger.info("Running go mod tidy");
        
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        result.output = res.output;
        
        if (res.status != 0)
        {
            result.success = false;
            result.errors ~= "go mod tidy failed: " ~ res.output;
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    /// Run go mod download
    static ToolResult modDownload(string workDir = ".")
    {
        ToolResult result;
        
        if (!isGoAvailable())
        {
            result.errors ~= "go not available";
            result.success = false;
            return result;
        }
        
        string[] cmd = ["go", "mod", "download"];
        
        Logger.info("Downloading Go modules");
        
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        result.output = res.output;
        
        if (res.status != 0)
        {
            result.success = false;
            result.errors ~= "go mod download failed: " ~ res.output;
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    /// Run go mod vendor
    static ToolResult modVendor(string workDir = ".")
    {
        ToolResult result;
        
        if (!isGoAvailable())
        {
            result.errors ~= "go not available";
            result.success = false;
            return result;
        }
        
        string[] cmd = ["go", "mod", "vendor"];
        
        Logger.info("Vendoring dependencies");
        
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        result.output = res.output;
        
        if (res.status != 0)
        {
            result.success = false;
            result.errors ~= "go mod vendor failed: " ~ res.output;
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
}

