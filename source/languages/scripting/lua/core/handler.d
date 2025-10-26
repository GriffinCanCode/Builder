module languages.scripting.lua.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import languages.base.base;
import languages.scripting.lua.core.config;
import languages.scripting.lua.tooling.detection;
import languages.scripting.lua.tooling.builders;
import languages.scripting.lua.managers.luarocks;
import languages.scripting.lua.tooling.formatters;
import languages.scripting.lua.tooling.checkers;
import languages.scripting.lua.tooling.testers;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// Lua language build handler - orchestrates all Lua build operations
class LuaHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Lua target: " ~ target.name);
        
        // Parse Lua configuration
        LuaConfig luaConfig = parseLuaConfig(target);
        
        // Auto-detect runtime if needed
        if (luaConfig.runtime == LuaRuntime.Auto)
        {
            luaConfig.runtime = detectRuntime();
            Logger.debug_("Auto-detected runtime: " ~ runtimeToString(luaConfig.runtime));
        }
        
        // Validate configuration
        auto validation = validateConfig(luaConfig, target);
        if (!validation.empty)
        {
            result.error = "Configuration validation failed: " ~ validation;
            return result;
        }
        
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, luaConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, luaConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, luaConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, luaConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(Target target, WorkspaceConfig config)
    {
        LuaConfig luaConfig = parseLuaConfig(target);
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Output depends on build mode
            final switch (luaConfig.mode)
            {
                case LuaBuildMode.Script:
                    outputs ~= buildPath(config.options.outputDir, name);
                    break;
                case LuaBuildMode.Bytecode:
                    if (!luaConfig.bytecode.outputFile.empty)
                        outputs ~= buildPath(config.options.outputDir, luaConfig.bytecode.outputFile);
                    else
                        outputs ~= buildPath(config.options.outputDir, name ~ ".luac");
                    break;
                case LuaBuildMode.Library:
                    outputs ~= buildPath(config.options.outputDir, name ~ ".lua");
                    break;
                case LuaBuildMode.Rock:
                    outputs ~= buildPath(config.options.outputDir, name ~ "-rock");
                    break;
                case LuaBuildMode.Application:
                    outputs ~= buildPath(config.options.outputDir, name);
                    break;
            }
        }
        
        return outputs;
    }
    
    /// Build executable target
    private LanguageBuildResult buildExecutable(Target target, WorkspaceConfig config, LuaConfig luaConfig)
    {
        LanguageBuildResult result;
        
        // Install dependencies if requested
        if (luaConfig.installDeps || luaConfig.luarocks.autoInstall)
        {
            auto depResult = installDependencies(target, luaConfig);
            if (!depResult.success)
            {
                result.error = depResult.error;
                return result;
            }
        }
        
        // Run formatter if enabled
        if (luaConfig.format.autoFormat)
        {
            auto formatResult = runFormatter(target, luaConfig);
            if (!formatResult.success && !luaConfig.format.checkOnly)
            {
                Logger.warning("Formatting failed: " ~ formatResult.error);
            }
        }
        
        // Run linter if enabled
        if (luaConfig.lint.enabled)
        {
            auto lintResult = runLinter(target, luaConfig);
            if (!lintResult.success && luaConfig.lint.failOnWarning)
            {
                result.error = "Lint errors found: " ~ lintResult.error;
                return result;
            }
            if (!lintResult.success)
            {
                Logger.warning("Lint warnings: " ~ lintResult.error);
            }
        }
        
        // Select and run appropriate builder
        auto builder = selectBuilder(luaConfig);
        auto buildResult = builder.build(target.sources, luaConfig, target, config);
        
        if (!buildResult.success)
        {
            result.error = buildResult.error;
            return result;
        }
        
        result.success = true;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    /// Build library target
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config, LuaConfig luaConfig)
    {
        LanguageBuildResult result;
        
        // Libraries should use library mode
        if (luaConfig.mode == LuaBuildMode.Script)
        {
            luaConfig.mode = LuaBuildMode.Library;
        }
        
        // Validate syntax
        foreach (source; target.sources)
        {
            auto syntaxResult = validateSyntax(source, luaConfig);
            if (!syntaxResult.success)
            {
                result.error = syntaxResult.error;
                return result;
            }
        }
        
        // Run formatter if enabled
        if (luaConfig.format.autoFormat)
        {
            runFormatter(target, luaConfig);
        }
        
        // Run linter if enabled
        if (luaConfig.lint.enabled)
        {
            auto lintResult = runLinter(target, luaConfig);
            if (!lintResult.success && luaConfig.lint.failOnWarning)
            {
                result.error = "Lint errors in library: " ~ lintResult.error;
                return result;
            }
        }
        
        // Build library
        auto builder = selectBuilder(luaConfig);
        auto buildResult = builder.build(target.sources, luaConfig, target, config);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    /// Run tests
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config, LuaConfig luaConfig)
    {
        LanguageBuildResult result;
        
        // Auto-detect test framework if not specified
        if (luaConfig.test.framework == LuaTestFramework.Auto)
        {
            luaConfig.test.framework = detectTestFramework(target);
            Logger.debug_("Auto-detected test framework: " ~ testFrameworkToString(luaConfig.test.framework));
        }
        
        // Select test runner
        auto tester = TesterFactory.create(luaConfig.test.framework, luaConfig);
        
        if (!tester.isAvailable())
        {
            result.error = "Test framework '" ~ testFrameworkToString(luaConfig.test.framework) ~ 
                          "' is not available. Please install it.";
            return result;
        }
        
        // Run tests
        auto testResult = tester.runTests(target.sources, luaConfig, target, config);
        
        result.success = testResult.success;
        result.error = testResult.error;
        result.outputHash = testResult.outputHash;
        
        return result;
    }
    
    /// Build custom target
    private LanguageBuildResult buildCustom(Target target, WorkspaceConfig config, LuaConfig luaConfig)
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Parse Lua configuration from target
    private LuaConfig parseLuaConfig(Target target)
    {
        LuaConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("lua" in target.langConfig)
            configKey = "lua";
        else if ("luaConfig" in target.langConfig)
            configKey = "luaConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = LuaConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse Lua config, using defaults: " ~ e.msg);
            }
        }
        
        // Auto-detect entry point if not specified
        if (config.entryPoint.empty && !target.sources.empty)
        {
            config.entryPoint = target.sources[0];
        }
        
        return config;
    }
    
    /// Validate configuration
    private string validateConfig(LuaConfig config, Target target)
    {
        import std.format : format;
        
        // Check if sources exist
        if (target.sources.empty)
        {
            return "No source files specified";
        }
        
        foreach (source; target.sources)
        {
            if (!exists(source))
            {
                return format("Source file not found: %s", source);
            }
        }
        
        // Validate runtime requirements
        if (config.runtime == LuaRuntime.LuaJIT && config.luajit.enabled)
        {
            if (!isCommandAvailable("luajit"))
            {
                return "LuaJIT runtime selected but luajit command not found";
            }
        }
        
        // Validate bytecode mode requirements
        if (config.mode == LuaBuildMode.Bytecode)
        {
            if (!isCommandAvailable("luac") && !config.luajit.bytecode)
            {
                return "Bytecode mode requires luac compiler";
            }
        }
        
        // Validate rock mode requirements
        if (config.mode == LuaBuildMode.Rock)
        {
            if (!config.luarocks.enabled)
            {
                return "Rock mode requires LuaRocks to be enabled";
            }
            if (!isCommandAvailable("luarocks"))
            {
                return "LuaRocks is not installed";
            }
        }
        
        return "";
    }
    
    /// Install dependencies
    private struct DependencyResult
    {
        bool success;
        string error;
    }
    
    private DependencyResult installDependencies(Target target, LuaConfig config)
    {
        DependencyResult result;
        
        if (!config.luarocks.enabled)
        {
            result.success = true;
            return result;
        }
        
        auto manager = new LuaRocksManager(config.luarocks);
        
        // Find rockspec if not specified
        if (config.luarocks.rockspecFile.empty)
        {
            auto rockspec = findRockspec(target);
            if (!rockspec.empty)
            {
                config.luarocks.rockspecFile = rockspec;
            }
        }
        
        // Install dependencies
        if (!config.luarocks.rockspecFile.empty && exists(config.luarocks.rockspecFile))
        {
            auto installResult = manager.installDependencies(config.luarocks.rockspecFile);
            result.success = installResult.success;
            result.error = installResult.error;
        }
        else if (!config.luarocks.dependencies.empty)
        {
            // Install specific dependencies
            foreach (dep; config.luarocks.dependencies)
            {
                auto installResult = manager.installRock(dep);
                if (!installResult.success)
                {
                    result.success = false;
                    result.error = installResult.error;
                    return result;
                }
            }
            result.success = true;
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    /// Find rockspec file in project
    private string findRockspec(Target target)
    {
        if (target.sources.empty)
            return "";
        
        string dir = dirName(target.sources[0]);
        
        // Search for .rockspec files
        try
        {
            auto entries = dirEntries(dir, "*.rockspec", SpanMode.shallow);
            foreach (entry; entries)
            {
                if (entry.isFile)
                    return entry.name;
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to search for rockspec: " ~ e.msg);
        }
        
        return "";
    }
    
    /// Run formatter
    private struct FormatResult
    {
        bool success;
        string error;
    }
    
    private FormatResult runFormatter(Target target, LuaConfig config)
    {
        FormatResult result;
        
        auto formatter = FormatterFactory.create(config.format.formatter, config);
        
        if (!formatter.isAvailable())
        {
            result.success = false;
            result.error = "Formatter not available";
            return result;
        }
        
        auto fmtResult = formatter.format(target.sources, config);
        result.success = fmtResult.success;
        result.error = fmtResult.error;
        
        return result;
    }
    
    /// Run linter
    private struct LintResult
    {
        bool success;
        string error;
    }
    
    private LintResult runLinter(Target target, LuaConfig config)
    {
        LintResult result;
        
        auto checker = CheckerFactory.create(config.lint.linter, config);
        
        if (!checker.isAvailable())
        {
            result.success = false;
            result.error = "Linter not available";
            return result;
        }
        
        auto checkResult = checker.check(target.sources, config);
        result.success = checkResult.success;
        result.error = checkResult.error;
        
        return result;
    }
    
    /// Validate Lua syntax
    private struct SyntaxResult
    {
        bool success;
        string error;
    }
    
    private SyntaxResult validateSyntax(string source, LuaConfig config)
    {
        SyntaxResult result;
        
        // Determine which compiler to use
        string compiler = getLuaCompiler(config);
        
        if (compiler.empty)
        {
            result.success = false;
            result.error = "No Lua compiler available for syntax validation";
            return result;
        }
        
        // Run syntax check
        auto cmd = [compiler, "-p", source];
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.success = false;
            result.error = "Syntax error in " ~ source ~ ": " ~ res.output;
            return result;
        }
        
        result.success = true;
        return result;
    }
    
    /// Get Lua compiler path
    private string getLuaCompiler(LuaConfig config)
    {
        // Try LuaJIT first if enabled
        if (config.luajit.enabled && isCommandAvailable("luajit"))
        {
            return "luajit";
        }
        
        // Try standard luac
        if (isCommandAvailable("luac"))
        {
            return "luac";
        }
        
        // Try version-specific compilers
        final switch (config.runtime)
        {
            case LuaRuntime.Auto:
                break;
            case LuaRuntime.Lua51:
                if (isCommandAvailable("luac5.1")) return "luac5.1";
                break;
            case LuaRuntime.Lua52:
                if (isCommandAvailable("luac5.2")) return "luac5.2";
                break;
            case LuaRuntime.Lua53:
                if (isCommandAvailable("luac5.3")) return "luac5.3";
                break;
            case LuaRuntime.Lua54:
                if (isCommandAvailable("luac5.4")) return "luac5.4";
                break;
            case LuaRuntime.LuaJIT:
                if (isCommandAvailable("luajit")) return "luajit";
                break;
            case LuaRuntime.System:
                if (isCommandAvailable("luac")) return "luac";
                break;
        }
        
        return "";
    }
    
    /// Select appropriate builder based on config
    private LuaBuilder selectBuilder(LuaConfig config)
    {
        return BuilderFactory.create(config.mode, config);
    }
    
    /// Auto-detect test framework
    private LuaTestFramework detectTestFramework(Target target)
    {
        // Check if busted is available
        if (isCommandAvailable("busted"))
        {
            return LuaTestFramework.Busted;
        }
        
        // Check for LuaUnit in sources
        foreach (source; target.sources)
        {
            if (exists(source) && isFile(source))
            {
                try
                {
                    auto content = readText(source);
                    if (content.canFind("require") && content.canFind("luaunit"))
                    {
                        return LuaTestFramework.LuaUnit;
                    }
                }
                catch (Exception) {}
            }
        }
        
        // Default to busted if available, otherwise LuaUnit
        return isCommandAvailable("busted") ? LuaTestFramework.Busted : LuaTestFramework.LuaUnit;
    }
    
    /// Check if command is available
    private bool isCommandAvailable(string command)
    {
        version(Windows)
        {
            auto res = execute(["where", command]);
        }
        else
        {
            auto res = execute(["which", command]);
        }
        
        return res.status == 0;
    }
    
    /// Convert runtime enum to string
    private string runtimeToString(LuaRuntime runtime)
    {
        final switch (runtime)
        {
            case LuaRuntime.Auto: return "auto";
            case LuaRuntime.Lua51: return "Lua 5.1";
            case LuaRuntime.Lua52: return "Lua 5.2";
            case LuaRuntime.Lua53: return "Lua 5.3";
            case LuaRuntime.Lua54: return "Lua 5.4";
            case LuaRuntime.LuaJIT: return "LuaJIT";
            case LuaRuntime.System: return "System Lua";
        }
    }
    
    /// Convert test framework enum to string
    private string testFrameworkToString(LuaTestFramework framework)
    {
        final switch (framework)
        {
            case LuaTestFramework.Auto: return "auto";
            case LuaTestFramework.Busted: return "Busted";
            case LuaTestFramework.LuaUnit: return "LuaUnit";
            case LuaTestFramework.Telescope: return "Telescope";
            case LuaTestFramework.TestMore: return "TestMore";
            case LuaTestFramework.None: return "none";
        }
    }
    
    override Import[] analyzeImports(string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.Lua);
        if (spec is null)
            return [];
        
        Import[] allImports;
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            try
            {
                auto content = readText(source);
                auto imports = spec.scanImports(source, content);
                allImports ~= imports;
            }
            catch (Exception e)
            {
                Logger.warning("Failed to analyze imports in " ~ source);
            }
        }
        
        return allImports;
    }
}

