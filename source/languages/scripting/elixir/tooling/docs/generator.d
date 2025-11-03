module languages.scripting.elixir.tooling.docs.generator;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.scripting.elixir.config;
import infrastructure.utils.logging.logger;

/// Documentation generator (ExDoc)
class DocGenerator
{
    /// Generate documentation
    static bool generate(DocConfig config, string mixCmd = "mix")
    {
        if (!isExDocAvailable(mixCmd))
        {
            Logger.warning("ExDoc not available (add {:ex_doc, \"~> 0.31\", only: :dev} to deps)");
            return false;
        }
        
        Logger.info("Generating documentation");
        
        string[] cmd = [mixCmd, "docs"];
        
        // ExDoc configuration is typically in mix.exs under project() or docs()
        // So we don't need to pass many CLI options
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            Logger.error("Documentation generation failed: " ~ res.output);
            return false;
        }
        
        string docPath = config.output.empty ? "doc" : config.output;
        if (exists(docPath))
        {
            Logger.info("Documentation generated at: " ~ docPath);
        }
        
        return true;
    }
    
    /// Check if ExDoc is available
    static bool isExDocAvailable(string mixCmd = "mix")
    {
        auto res = execute([mixCmd, "help", "docs"]);
        return res.status == 0;
    }
    
    /// Generate documentation for Hex package
    static bool generateForHex(DocConfig config, string mixCmd = "mix")
    {
        Logger.info("Building documentation for Hex");
        
        auto res = execute([mixCmd, "hex.build", "docs"]);
        
        if (res.status != 0)
        {
            Logger.error("Hex docs build failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
}

