module languages.web.css.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import languages.base.base;
import languages.web.css.core.config;
import languages.web.css.processors;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// CSS/SCSS/PostCSS build handler
class CSSHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debugLog("Building CSS target: " ~ target.name);
        
        // Parse CSS configuration
        CSSConfig cssConfig = parseCSSConfig(target);
        
        // Auto-detect processor from file extensions
        if (cssConfig.processor == CSSProcessorType.Auto)
        {
            cssConfig.processor = detectProcessor(target.sources);
        }
        
        final switch (target.type)
        {
            case TargetType.Executable:
            case TargetType.Library:
                result = compileCSS(target, config, cssConfig);
                break;
            case TargetType.Test:
                // CSS doesn't have tests, just validate
                result = validateCSS(target, config, cssConfig);
                break;
            case TargetType.Custom:
                result = compileCSS(target, config, cssConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        CSSConfig cssConfig = parseCSSConfig(target);
        
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else if (!cssConfig.output.empty)
        {
            outputs ~= buildPath(config.options.outputDir, cssConfig.output);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputs ~= buildPath(config.options.outputDir, name ~ ".css");
        }
        
        if (cssConfig.sourcemap)
        {
            outputs ~= outputs[0] ~ ".map";
        }
        
        return outputs;
    }
    
    private LanguageBuildResult compileCSS(in Target target, in WorkspaceConfig config, CSSConfig cssConfig)
    {
        LanguageBuildResult result;
        
        // Check for empty sources
        if (target.sources.length == 0)
        {
            result.success = false;
            result.error = "No source files specified for target " ~ target.name;
            return result;
        }
        
        // Production mode enables minification
        if (cssConfig.mode == CSSBuildMode.Production)
        {
            cssConfig.minify = true;
        }
        
        // Create processor
        auto processor = CSSProcessorFactory.create(cssConfig.processor);
        
        if (!processor.isAvailable())
        {
            // Fallback to no processing for pure CSS
            if (cssConfig.processor != CSSProcessorType.None)
            {
                Logger.warning("Processor '" ~ processor.name() ~ "' not available, using pure CSS");
                processor = CSSProcessorFactory.create(CSSProcessorType.None);
            }
        }
        
        Logger.debugLog("Using CSS processor: " ~ processor.name());
        
        // Compile
        auto compileResult = processor.compile(target.sources, cssConfig, target, config);
        
        if (!compileResult.success)
        {
            result.error = compileResult.error;
            return result;
        }
        
        result.success = true;
        result.outputs = compileResult.outputs;
        result.outputHash = compileResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult validateCSS(in Target target, in WorkspaceConfig config, CSSConfig cssConfig)
    {
        LanguageBuildResult result;
        
        // Simple validation - check files exist and are readable
        foreach (source; target.sources)
        {
            if (!exists(source) || !isFile(source))
            {
                result.error = "CSS file not found: " ~ source;
                return result;
            }
            
            try
            {
                readText(source);
            }
            catch (Exception e)
            {
                result.error = "Failed to read CSS file " ~ source ~ ": " ~ e.msg;
                return result;
            }
        }
        
        result.success = true;
        result.outputs = target.sources.dup;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Parse CSS configuration from target
    private CSSConfig parseCSSConfig(in Target target)
    {
        CSSConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("css" in target.langConfig)
            configKey = "css";
        else if ("cssConfig" in target.langConfig)
            configKey = "cssConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = CSSConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse CSS config, using defaults: " ~ e.msg);
            }
        }
        
        // Auto-detect entry point if not specified
        if (config.entry.empty && !target.sources.empty)
        {
            config.entry = target.sources[0];
        }
        
        return config;
    }
    
    /// Detect processor from file extensions
    private CSSProcessorType detectProcessor(const(string[]) sources)
    {
        foreach (source; sources)
        {
            string ext = extension(source);
            switch (ext)
            {
                case ".scss":
                case ".sass":
                    return CSSProcessorType.SCSS;
                case ".less":
                    return CSSProcessorType.Less;
                case ".styl":
                case ".stylus":
                    return CSSProcessorType.Stylus;
                default:
                    break;
            }
        }
        
        // Check for PostCSS config files
        if (!sources.empty)
        {
            string dir = dirName(sources[0]);
            if (exists(buildPath(dir, "postcss.config.js")) ||
                exists(buildPath(dir, "postcss.config.json")) ||
                exists(buildPath(dir, ".postcssrc")))
            {
                return CSSProcessorType.PostCSS;
            }
        }
        
        // Default to pure CSS
        return CSSProcessorType.None;
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
        // CSS imports are typically @import statements
        // For now, return empty - could be enhanced
        return [];
    }
}

