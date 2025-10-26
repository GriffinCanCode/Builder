module languages.scripting.javascript.bundlers.rollup;

import languages.scripting.javascript.bundlers.base;
import languages.scripting.javascript.bundlers.config;
import config.schema.schema;
import std.process;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import std.conv;
import utils.files.hash;
import utils.logging.logger;

/// Rollup bundler - optimized for library bundles with tree-shaking
class RollupBundler : Bundler
{
    BundleResult bundle(
        string[] sources,
        JSConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        BundleResult result;
        
        // Check if rollup is available
        if (!isAvailable())
        {
            result.error = "rollup not found. Install: npm install -g rollup";
            return result;
        }
        
        // If custom config file specified, use it
        if (!config.configFile.empty && exists(config.configFile))
        {
            return bundleWithConfigFile(config.configFile, workspace, result);
        }
        
        // Otherwise, use CLI mode
        return bundleWithCLI(sources, config, target, workspace, result);
    }
    
    private BundleResult bundleWithConfigFile(
        string configFile,
        WorkspaceConfig workspace,
        BundleResult result
    )
    {
        Logger.debug_("Using rollup config: " ~ configFile);
        
        string[] cmd = ["rollup", "-c", configFile];
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "rollup failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        
        // Parse rollup output to find generated files
        string outputDir = workspace.options.outputDir;
        if (exists(outputDir) && isDir(outputDir))
        {
            foreach (entry; dirEntries(outputDir, SpanMode.shallow))
            {
                if (entry.isFile && entry.name.endsWith(".js"))
                    result.outputs ~= entry.name;
            }
        }
        
        result.outputHash = FastHash.hashFiles(result.outputs);
        
        return result;
    }
    
    private BundleResult bundleWithCLI(
        string[] sources,
        JSConfig config,
        Target target,
        WorkspaceConfig workspace,
        BundleResult result
    )
    {
        string entry = config.entry.empty ? sources[0] : config.entry;
        string outputDir = workspace.options.outputDir;
        mkdirRecurse(outputDir);
        
        string outputFile = buildPath(
            outputDir,
            target.name.split(":")[$ - 1] ~ ".js"
        );
        
        // Build rollup command
        string[] cmd = ["rollup", entry];
        
        // Output file
        cmd ~= "--file";
        cmd ~= outputFile;
        
        // Format
        cmd ~= "--format";
        cmd ~= outputFormatToRollup(config.format);
        
        // Source maps
        if (config.sourcemap)
        {
            cmd ~= "--sourcemap";
        }
        
        // External packages
        foreach (ext; config.external)
        {
            cmd ~= "--external";
            cmd ~= ext;
        }
        
        // Plugins for minification (requires @rollup/plugin-terser)
        if (config.minify)
        {
            Logger.warning("Rollup minification requires @rollup/plugin-terser plugin");
        }
        
        Logger.debug_("Running rollup: " ~ cmd.join(" "));
        
        // Execute rollup
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "rollup failed: " ~ res.output;
            return result;
        }
        
        Logger.debug_("rollup completed successfully");
        
        result.success = true;
        result.outputs = [outputFile];
        
        if (config.sourcemap && exists(outputFile ~ ".map"))
        {
            result.outputs ~= outputFile ~ ".map";
        }
        
        result.outputHash = FastHash.hashFiles(result.outputs);
        
        return result;
    }
    
    private string outputFormatToRollup(OutputFormat format)
    {
        final switch (format)
        {
            case OutputFormat.ESM: return "es";
            case OutputFormat.CommonJS: return "cjs";
            case OutputFormat.IIFE: return "iife";
            case OutputFormat.UMD: return "umd";
        }
    }
    
    bool isAvailable()
    {
        auto res = execute(["rollup", "--version"]);
        return res.status == 0;
    }
    
    string name() const
    {
        return "rollup";
    }
    
    string getVersion()
    {
        auto res = execute(["rollup", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

