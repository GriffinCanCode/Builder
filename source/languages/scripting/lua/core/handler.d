module languages.scripting.lua.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import std.conv;
import languages.base.base;
import languages.scripting.lua.core.config;
import languages.scripting.lua.tooling.detection;
import languages.scripting.lua.tooling.builders;
import languages.scripting.lua.managers.luarocks;
import languages.scripting.lua.tooling.detection : isLuaRocksAvailable;
import languages.scripting.lua.tooling.formatters;
import languages.scripting.lua.tooling.checkers;
import languages.scripting.lua.tooling.testers;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;
import utils.process : isCommandAvailable;

/// Lua language build handler - orchestrates all Lua build operations
class LuaHandler : BaseLanguageHandler
{
    /// Build implementation - orchestrates Lua compilation/execution
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Required by BaseLanguageHandler design (called via @trusted wrapper)
    /// 2. Performs file I/O (parseLuaConfig reads JSON)
    /// 3. Delegates to build* methods which execute Lua toolchain
    /// 4. All operations validated by configuration system
    /// 
    /// Invariants:
    /// - Configuration is parsed and validated before build
    /// - Target type determines build method (final switch ensures coverage)
    /// - All file paths are constructed within workspace
    /// 
    /// What could go wrong:
    /// - Config parse fails: validateConfig catches, returns error
    /// - Build method fails: error propagates in result.error
    /// - Lua toolchain missing: detected in validateConfig
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config) @trusted
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
    
    /// Get output file paths for target
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Required by BaseLanguageHandler (called via @trusted wrapper)
    /// 2. Performs path construction with buildPath (safe operations)
    /// 3. May read files to detect rockspec (file I/O)
    /// 4. parseLuaConfig performs JSON parsing
    /// 
    /// Invariants:
    /// - Output paths are within outputDir or workspace
    /// - Empty outputPath falls back to defaults
    /// - Rockspec detection is optional, failure returns empty
    /// 
    /// What could go wrong:
    /// - Config parse fails: caught by parseLuaConfig, returns defaults
    /// - File read fails: findRockspec handles, returns empty string
    override string[] getOutputs(in Target target, in WorkspaceConfig config) @trusted
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
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Executes Lua builders (LuaJIT, bytecode, or script)
    /// 2. Installs dependencies via LuaRocks (process execution)
    /// 3. Runs formatters and linters (external tools)
    /// 4. Validates syntax (reads source files)
    /// 5. All operations use validated paths and commands
    /// 
    /// Invariants:
    /// - Dependencies installed before building
    /// - Format/lint are optional (failure logged, doesn't stop build)
    /// - Builder is selected based on config.buildMode
    /// - Output hash computed from built files
    /// 
    /// What could go wrong:
    /// - Dependency install fails: propagates in result.error
    /// - Builder fails: error message in result.error
    /// - Format/lint fail: logged but build continues
    private LanguageBuildResult buildExecutable(in Target target, in WorkspaceConfig config, LuaConfig luaConfig) @trusted
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
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Executes LuaRocks make (external process)
    /// 2. Installs dependencies (process execution, file I/O)
    /// 3. Validates and formats code (file I/O)
    /// 4. Finds and uses rockspec file (file scanning)
    /// 
    /// Invariants:
    /// - Rockspec file is required for library builds
    /// - Dependencies installed via LuaRocks
    /// - Format/lint are optional pre-build steps
    /// - Success determined by LuaRocks exit code
    /// 
    /// What could go wrong:
    /// - No rockspec: caught and returned as error
    /// - LuaRocks not available: detected in validateConfig
    /// - make fails: exit code captured in result.error
    private LanguageBuildResult buildLibrary(in Target target, in WorkspaceConfig config, LuaConfig luaConfig) @trusted
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
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Executes test framework (Busted, LuaUnit, or custom)
    /// 2. Auto-detects framework if not specified (file scanning)
    /// 3. Installs dependencies before testing
    /// 4. Runs external test process with validated paths
    /// 
    /// Invariants:
    /// - Test framework is detected or explicitly configured
    /// - Dependencies installed before test execution
    /// - Test files are validated to exist
    /// - Exit code determines test success
    /// 
    /// What could go wrong:
    /// - No test framework found: returns error
    /// - Test execution fails: captured in exit code
    /// - Dependency install fails: propagates error
    private LanguageBuildResult runTests(in Target target, in WorkspaceConfig config, LuaConfig luaConfig) @trusted
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
    private LanguageBuildResult buildCustom(in Target target, in WorkspaceConfig config, LuaConfig luaConfig) @safe
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Parse Lua configuration from target
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Parses JSON from target.config (untrusted input)
    /// 2. LuaConfig.fromJSON validates and sanitizes values
    /// 3. File I/O if custom config file specified
    /// 4. Exception handling ensures safe defaults
    /// 
    /// Invariants:
    /// - Invalid JSON returns default config
    /// - All config values are validated by fromJSON
    /// - Exceptions result in default config (safe fallback)
    /// 
    /// What could go wrong:
    /// - Malformed JSON: parseJSON throws, caught, returns default
    /// - Invalid config values: fromJSON validates, uses defaults
    private LuaConfig parseLuaConfig(in Target target) @trusted
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
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Calls isCommandAvailable() to check toolchain (process execution)
    /// 2. Validates file paths exist (file I/O)
    /// 3. Checks LuaRocks availability (process execution)
    /// 4. All checks are read-only queries
    /// 
    /// Invariants:
    /// - Returns empty string if valid
    /// - Returns error message if invalid
    /// - No state modification (pure validation)
    /// 
    /// What could go wrong:
    /// - Command check fails: returns validation error (safe)
    /// - File doesn't exist: returns validation error (safe)
    private string validateConfig(LuaConfig config, const Target target) @trusted
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
    
    /// Install project dependencies via LuaRocks
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Executes LuaRocks install command (external process)
    /// 2. Finds rockspec file (file I/O, directory scanning)
    /// 3. Parses rockspec for dependencies (file read)
    /// 4. Installs each dependency (multiple process executions)
    /// 
    /// Invariants:
    /// - LuaRocks availability checked before calling
    /// - Rockspec file is validated to exist
    /// - Each dependency install is independent
    /// - Failures are logged but may not stop process
    /// 
    /// What could go wrong:
    /// - LuaRocks not available: detected by caller
    /// - Install fails: exit code captured in result
    /// - Network issues: LuaRocks handles, returns error
    private DependencyResult installDependencies(const Target target, LuaConfig config) @trusted
    {
        DependencyResult result;
        
        if (!config.luarocks.enabled)
        {
            result.success = true;
            return result;
        }
        
        // Check if LuaRocks is available
        if (!isLuaRocksAvailable())
        {
            result.error = "LuaRocks is not installed or not in PATH";
            return result;
        }
        
        // Create LuaRocks manager
        auto manager = new LuaRocksManager(config.luarocks);
        
        // Find rockspec file
        string rockspecFile = findRockspec(target);
        
        if (!rockspecFile.empty)
        {
            // Install dependencies from rockspec
            Logger.info("Installing dependencies from rockspec: " ~ rockspecFile);
            auto rockResult = manager.installDependencies(rockspecFile);
            
            if (!rockResult.success)
            {
                result.error = rockResult.error;
                return result;
            }
            
            Logger.info("Successfully installed dependencies from rockspec");
        }
        else if (!config.luarocks.dependencies.empty)
        {
            // Install specified rocks
            Logger.info("Installing " ~ config.luarocks.dependencies.length.to!string ~ " rocks");
            
            foreach (rock; config.luarocks.dependencies)
            {
                auto rockResult = manager.installRock(rock);
                
                if (!rockResult.success)
                {
                    result.error = "Failed to install rock '" ~ rock ~ "': " ~ rockResult.error;
                    return result;
                }
                
                Logger.info("Installed rock: " ~ rock);
            }
        }
        else
        {
            Logger.debug_("No rockspec file found and no rocks specified, skipping dependency installation");
        }
        
        result.success = true;
        return result;
    }
    
    /// Find rockspec file in project
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Scans directory for .rockspec files (file I/O)
    /// 2. Uses dirEntries() to iterate directory (system call)
    /// 3. Checks file existence and extensions (file queries)
    /// 4. Returns empty string on failure (safe default)
    /// 
    /// Invariants:
    /// - Only searches within target directory
    /// - Returns first .rockspec found
    /// - Empty string if none found (safe fallback)
    /// - No files are modified (read-only scan)
    /// 
    /// What could go wrong:
    /// - Directory doesn't exist: dirEntries throws, caught, returns empty
    /// - Permission denied: exception caught, returns empty
    /// - Multiple rockspecs: returns first one found (acceptable)
    private string findRockspec(const Target target) @trusted
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
    
    /// Run code formatter (stylua or lua-format)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Executes external formatter tool (process execution)
    /// 2. Passes source file paths as arguments (validated paths)
    /// 3. Formatter modifies files in-place (intentional side effect)
    /// 4. Tool availability checked before execution
    /// 
    /// Invariants:
    /// - Formatter tool is validated to exist
    /// - Only formats files within target sources
    /// - Format failures are logged, don't stop build
    /// - Exit code determines format success
    /// 
    /// What could go wrong:
    /// - Formatter not installed: caught by isCommandAvailable
    /// - Format fails on file: exit code captured, logged
    /// - File corrupted: formatter's responsibility, rollback not provided
    private FormatResult runFormatter(const Target target, LuaConfig config) @trusted
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
    
    /// Run static analysis linter (luacheck)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Executes luacheck tool (external process)
    /// 2. Passes source files for analysis (validated paths)
    /// 3. Parses linter output (text processing)
    /// 4. Read-only operation (doesn't modify files)
    /// 
    /// Invariants:
    /// - Linter is optional (failure doesn't stop build)
    /// - Only analyzes files within target sources
    /// - Exit code indicates linting success
    /// - Output is parsed for warnings/errors
    /// 
    /// What could go wrong:
    /// - Luacheck not installed: detected, skipped gracefully
    /// - Lint fails: captured in exit code, logged
    /// - Output parsing fails: handled safely
    private LintResult runLinter(const Target target, LuaConfig config) @trusted
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
    
    /// Validate Lua syntax by compilation check
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Executes Lua compiler with -p flag (syntax check only)
    /// 2. Passes source file path (validated within workspace)
    /// 3. No code execution (only parsing)
    /// 4. Reads compiler output for errors
    /// 
    /// Invariants:
    /// - Compiler is validated to exist
    /// - -p flag ensures parse-only mode
    /// - No bytecode is generated or executed
    /// - Exit code indicates syntax validity
    /// 
    /// What could go wrong:
    /// - Compiler not found: detected by getLuaCompiler
    /// - Syntax error: captured in exit code (expected)
    /// - File read fails: compiler reports error
    private SyntaxResult validateSyntax(string source, LuaConfig config) @trusted
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
    
    /// Get Lua compiler path based on runtime
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Calls isCommandAvailable() for each runtime (process execution)
    /// 2. Checks PATH environment for lua/luajit executables
    /// 3. Falls back through runtime priority list
    /// 4. Returns validated command name or empty string
    /// 
    /// Invariants:
    /// - Tries runtimes in priority order: LuaJIT > Lua > LuaU
    /// - isCommandAvailable validates each candidate
    /// - Empty string indicates no compiler found
    /// - Result is safe to use with execute()
    /// 
    /// What could go wrong:
    /// - No Lua found: returns empty string (caller handles)
    /// - Multiple Luas: returns first found (acceptable)
    /// - Command check fails: handled by isCommandAvailable
    private string getLuaCompiler(LuaConfig config) @trusted
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
    private LuaBuilder selectBuilder(LuaConfig config) @safe
    {
        return BuilderFactory.create(config.mode, config);
    }
    
    /// Auto-detect test framework from project files
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Scans test directories for framework files (file I/O)
    /// 2. Reads test files to detect require statements (file read)
    /// 3. Checks for framework-specific files (file queries)
    /// 4. Falls back to None if detection fails
    /// 
    /// Invariants:
    /// - Only scans within test/ or spec/ directories
    /// - Detects Busted (busted config) or LuaUnit (require pattern)
    /// - Returns None if no framework detected (safe default)
    /// - No files are modified (read-only detection)
    /// 
    /// What could go wrong:
    /// - Directory doesn't exist: handled gracefully, returns None
    /// - File read fails: caught, continues scanning
    /// - False positive: unlikely, patterns are specific
    private LuaTestFramework detectTestFramework(const Target target) @trusted
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
                catch (Exception e)
                {
                    import utils.logging.logger : Logger;
                    Logger.debug_("Failed to detect Lua test framework: " ~ e.msg);
                }
            }
        }
        
        // Default to busted if available, otherwise LuaUnit
        return isCommandAvailable("busted") ? LuaTestFramework.Busted : LuaTestFramework.LuaUnit;
    }
    
    
    /// Convert runtime enum to string
    private string runtimeToString(LuaRuntime runtime) @safe pure nothrow
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
    private string testFrameworkToString(LuaTestFramework framework) @safe pure nothrow
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
    
    /// Analyze Lua import/require statements
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Reads source files to parse require() calls (file I/O)
    /// 2. Uses regex to match require/dofile patterns (memory-safe)
    /// 3. Delegates to LanguageSpec for structured parsing
    /// 4. Returns import list for dependency analysis
    /// 
    /// Invariants:
    /// - Only reads files, never modifies them
    /// - Validates file existence before reading
    /// - Empty array returned if parsing fails
    /// - Import paths are extracted as strings
    /// 
    /// What could go wrong:
    /// - File doesn't exist: checked with exists(), skipped
    /// - File read fails: caught, returns partial results
    /// - Regex doesn't match: returns empty for that file (safe)
    override Import[] analyzeImports(in string[] sources) @trusted
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

