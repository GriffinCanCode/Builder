module languages.scripting.javascript.bundlers.esbuild;

import languages.scripting.javascript.bundlers.base;
import languages.scripting.javascript.core.config;
import config.schema.schema;
import std.process;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import std.conv;
import std.string;
import utils.files.hash;
import utils.logging.logger;

/// esbuild bundler - fastest option for most use cases
class ESBuildBundler : Bundler
{
    BundleResult bundle(
        string[] sources,
        JSConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        BundleResult result;
        
        // Check if esbuild is available
        if (!isAvailable())
        {
            result.error = "esbuild not found. Install: npm install -g esbuild";
            return result;
        }
        
        // Determine entry point
        string entry = config.entry.empty ? sources[0] : config.entry;
        
        // Build output path
        string outputDir = workspace.options.outputDir;
        mkdirRecurse(outputDir);
        
        string outputFile = buildPath(
            outputDir,
            target.name.split(":")[$ - 1] ~ ".js"
        );
        
        // Build esbuild command
        string[] cmd = ["esbuild", entry];
        
        // Bundle mode
        if (config.mode == JSBuildMode.Bundle)
        {
            cmd ~= "--bundle";
        }
        
        // Output file
        cmd ~= "--outfile=" ~ outputFile;
        
        // Platform
        final switch (config.platform)
        {
            case Platform.Browser:
                cmd ~= "--platform=browser";
                break;
            case Platform.Node:
                cmd ~= "--platform=node";
                break;
            case Platform.Neutral:
                cmd ~= "--platform=neutral";
                break;
        }
        
        // Format
        final switch (config.format)
        {
            case OutputFormat.ESM:
                cmd ~= "--format=esm";
                break;
            case OutputFormat.CommonJS:
                cmd ~= "--format=cjs";
                break;
            case OutputFormat.IIFE:
                cmd ~= "--format=iife";
                break;
            case OutputFormat.UMD:
                // esbuild doesn't support UMD, fall back to IIFE
                cmd ~= "--format=iife";
                Logger.warning("esbuild doesn't support UMD, using IIFE instead");
                break;
        }
        
        // Minification
        if (config.minify)
        {
            cmd ~= "--minify";
        }
        
        // Source maps
        if (config.sourcemap)
        {
            cmd ~= "--sourcemap";
        }
        
        // Target ES version
        cmd ~= "--target=" ~ config.target;
        
        // External packages
        foreach (ext; config.external)
        {
            cmd ~= "--external:" ~ ext;
        }
        
        // JSX support
        if (config.jsx)
        {
            cmd ~= "--jsx=transform";
            cmd ~= "--jsx-factory=" ~ config.jsxFactory;
        }
        
        // Custom loaders
        foreach (extension, loader; config.loaders)
        {
            cmd ~= "--loader:" ~ extension ~ "=" ~ loader;
        }
        
        // Additional flags from target
        cmd ~= target.flags;
        
        Logger.debug_("Running esbuild: " ~ cmd.join(" "));
        
        // Execute esbuild
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "esbuild failed: " ~ res.output;
            return result;
        }
        
        Logger.debug_("esbuild completed successfully");
        
        // Success
        result.success = true;
        result.outputs = [outputFile];
        
        if (config.sourcemap && exists(outputFile ~ ".map"))
        {
            result.outputs ~= outputFile ~ ".map";
        }
        
        result.outputHash = FastHash.hashFiles(result.outputs);
        
        return result;
    }
    
    bool isAvailable()
    {
        auto res = execute(["esbuild", "--version"]);
        return res.status == 0;
    }
    
    string name() const
    {
        return "esbuild";
    }
    
    string getVersion()
    {
        auto res = execute(["esbuild", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

