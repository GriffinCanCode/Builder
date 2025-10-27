module languages.web.css.processors.postcss;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.web.css.core.config;
import languages.web.css.processors.base;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// PostCSS processor
class PostCSSProcessor : CSSProcessor
{
    CSSCompileResult compile(
        const(string[]) sources,
        CSSConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        CSSCompileResult result;
        
        // Determine output path
        string outputPath;
        if (!config.output.empty)
        {
            outputPath = buildPath(workspace.options.outputDir, config.output);
        }
        else if (!target.outputPath.empty)
        {
            outputPath = buildPath(workspace.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputPath = buildPath(workspace.options.outputDir, name ~ ".css");
        }
        
        mkdirRecurse(dirName(outputPath));
        
        // Build postcss command
        string[] cmd = ["postcss"];
        
        // Entry
        string entry = config.entry.empty ? sources[0] : config.entry;
        cmd ~= [entry];
        
        // Output
        cmd ~= ["-o", outputPath];
        
        // Source maps
        if (config.sourcemap)
        {
            cmd ~= ["--map"];
        }
        
        Logger.debugLog("Running: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "PostCSS compilation failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        if (config.sourcemap && exists(outputPath ~ ".map"))
        {
            result.outputs ~= outputPath ~ ".map";
        }
        result.outputHash = FastHash.hashFiles(result.outputs);
        
        return result;
    }
    
    bool isAvailable()
    {
        auto res = execute(["postcss", "--version"]);
        return res.status == 0;
    }
    
    string name() const
    {
        return "postcss";
    }
    
    string getVersion()
    {
        auto res = execute(["postcss", "--version"]);
        if (res.status == 0)
            return res.output;
        return "unknown";
    }
}

/// Less CSS processor (stub)
class LessProcessor : CSSProcessor
{
    CSSCompileResult compile(
        const(string[]) sources,
        CSSConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        CSSCompileResult result;
        result.error = "Less processor not yet implemented";
        return result;
    }
    
    bool isAvailable() { return false; }
    string name() const { return "less"; }
    string getVersion() { return "unknown"; }
}

/// Stylus processor (stub)
class StylusProcessor : CSSProcessor
{
    CSSCompileResult compile(
        const(string[]) sources,
        CSSConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        CSSCompileResult result;
        result.error = "Stylus processor not yet implemented";
        return result;
    }
    
    bool isAvailable() { return false; }
    string name() const { return "stylus"; }
    string getVersion() { return "unknown"; }
}

