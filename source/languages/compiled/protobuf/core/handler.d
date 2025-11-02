module languages.compiled.protobuf.core.handler;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import std.conv;
import std.string : lineSplitter;
import languages.base.base;
import languages.base.mixins;
import languages.compiled.protobuf.core.config;
import languages.compiled.protobuf.tooling.protoc;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;
import core.caching.actions.action : ActionCache, ActionCacheConfig, ActionId, ActionType;

/// Protocol Buffer build handler with action-level caching
class ProtobufHandler : BaseLanguageHandler
{
    mixin CachingHandlerMixin!"protobuf";
    
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debugLog("Building Protocol Buffer target: " ~ target.name);
        
        // Parse protobuf configuration
        ProtobufConfig pbConfig = parseProtobufConfig(target, config);
        
        // Validate proto files
        if (target.sources.empty)
        {
            result.error = "No proto files specified";
            return result;
        }
        
        // Filter for .proto files only
        string[] protoFiles;
        foreach (source; target.sources)
        {
            if (extension(source) == ".proto")
            {
                protoFiles ~= source;
            }
        }
        
        if (protoFiles.empty)
        {
            result.error = "No .proto files found in sources";
            return result;
        }
        
        // Run linter if requested
        if (pbConfig.lint && BufWrapper.isAvailable())
        {
            Logger.debugLog("Running buf lint...");
            auto lintResult = BufWrapper.lint(protoFiles);
            if (!lintResult.success)
            {
                Logger.warning("Linting issues found:");
                Logger.warning(lintResult.error);
            }
            else if (!lintResult.warnings.empty)
            {
                foreach (warning; lintResult.warnings)
                {
                    if (!warning.empty)
                        Logger.warning("  " ~ warning);
                }
            }
        }
        
        // Run formatter if requested
        if (pbConfig.format && BufWrapper.isAvailable())
        {
            Logger.debugLog("Running buf format...");
            auto fmtResult = BufWrapper.format(protoFiles, true);
            if (!fmtResult.success)
            {
                Logger.warning("Format issues found: " ~ fmtResult.error);
            }
        }
        
        // Compile proto files
        return compileProtoFiles(protoFiles, pbConfig, config);
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        ProtobufConfig pbConfig = parseProtobufConfig(target, config);
        
        string outputDir = pbConfig.outputDir.empty ? 
                          config.options.outputDir : 
                          pbConfig.outputDir;
        
        // Return the output directory path
        // The actual generated files depend on the proto file content
        return [outputDir];
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
        Import[] allImports;
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            try
            {
                auto content = readText(source);
                auto imports = parseProtoImports(source, content);
                allImports ~= imports;
            }
            catch (Exception e)
            {
                Logger.warning("Failed to analyze imports in " ~ source ~ ": " ~ e.msg);
            }
        }
        
        return allImports;
    }
    
    private LanguageBuildResult compileProtoFiles(
        const string[] protoFiles,
        const ProtobufConfig pbConfig,
        const WorkspaceConfig config
    )
    {
        LanguageBuildResult result;
        
        // Select compiler
        bool useProtoc = true;
        
        if (pbConfig.compiler == ProtocCompiler.Buf)
        {
            if (BufWrapper.isAvailable())
            {
                useProtoc = false;
            }
            else
            {
                Logger.warning("Buf compiler not available, falling back to protoc");
            }
        }
        
        // For now, we only support protoc (buf generate would need different implementation)
        if (!ProtocWrapper.isAvailable())
        {
            result.error = "protoc compiler not found. Install from: https://protobuf.dev/downloads/";
            return result;
        }
        
        Logger.debugLog("Using protoc: " ~ ProtocWrapper.getVersion());
        
        // Compile with action-level caching
        auto compileResult = ProtocWrapper.compile(
            protoFiles, 
            pbConfig, 
            config.root,
            actionCache,
            "protobuf"
        );
        
        if (!compileResult.success)
        {
            result.error = compileResult.error;
            return result;
        }
        
        // Report warnings
        if (!compileResult.warnings.empty)
        {
            Logger.warning("Compilation warnings:");
            foreach (warn; compileResult.warnings)
            {
                Logger.warning("  " ~ warn);
            }
        }
        
        result.success = true;
        result.outputs = compileResult.outputs;
        
        // Generate output hash from generated files
        if (!result.outputs.empty)
        {
            result.outputHash = FastHash.hashString(result.outputs.join("\n"));
        }
        
        return result;
    }
    
    private ProtobufConfig parseProtobufConfig(in Target target, in WorkspaceConfig workspace)
    {
        ProtobufConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("protobuf" in target.langConfig)
            configKey = "protobuf";
        else if ("proto" in target.langConfig)
            configKey = "proto";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = ProtobufConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse Protobuf config, using defaults: " ~ e.msg);
            }
        }
        
        // Set default output directory if not specified
        if (config.outputDir.empty)
        {
            config.outputDir = workspace.options.outputDir;
        }
        
        return config;
    }
    
    /// Parse proto imports from file content
    private Import[] parseProtoImports(string filepath, string content)
    {
        Import[] imports;
        
        import std.regex;
        import std.string : strip;
        
        // Match: import "path/to/file.proto";
        // Or: import public "path/to/file.proto";
        // Or: import weak "path/to/file.proto";
        auto importRegex = regex(`import\s+(?:public\s+|weak\s+)?"([^"]+)"`, "g");
        
        size_t lineNum = 1;
        foreach (line; content.lineSplitter)
        {
            auto matches = matchAll(line, importRegex);
            foreach (match; matches)
            {
                if (match.length >= 2)
                {
                    Import imp;
                    imp.moduleName = match[1];
                    imp.kind = determineImportKind(match[1]);
                    imp.location = SourceLocation(filepath, lineNum, 0);
                    imports ~= imp;
                }
            }
            lineNum++;
        }
        
        return imports;
    }
    
    /// Determine import kind for proto files
    private ImportKind determineImportKind(string importPath)
    {
        // Well-known types from google/protobuf are external
        if (importPath.startsWith("google/protobuf/"))
            return ImportKind.External;
        
        // Absolute paths
        if (isAbsolute(importPath))
            return ImportKind.Absolute;
        
        // Relative paths (most common in proto files)
        return ImportKind.Relative;
    }
}

