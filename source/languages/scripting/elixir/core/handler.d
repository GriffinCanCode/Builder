module languages.scripting.elixir.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import std.json;
import languages.base.base;
import languages.scripting.elixir.core.config;
import languages.scripting.elixir.managers;
import languages.scripting.elixir.tooling;
import languages.scripting.elixir.analysis;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// Elixir build handler - comprehensive and modular
class ElixirHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config) @trusted
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Elixir target: " ~ target.name);
        
        // Parse Elixir configuration
        ElixirConfig elixirConfig = parseElixirConfig(target);
        
        // Auto-detect and enhance configuration from project structure
        enhanceConfigFromProject(elixirConfig, target, config);
        
        // Setup Elixir environment
        string elixirCmd = setupElixirEnvironment(elixirConfig, config.root);
        string mixCmd = setupMixCommand(elixirConfig, config.root);
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, elixirConfig, elixirCmd, mixCmd);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, elixirConfig, elixirCmd, mixCmd);
                break;
            case TargetType.Test:
                result = runTests(target, config, elixirConfig, elixirCmd, mixCmd);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, elixirConfig, elixirCmd, mixCmd);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config) @trusted
    {
        string[] outputs;
        
        ElixirConfig elixirConfig = parseElixirConfig(target);
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Different output based on project type
            final switch (elixirConfig.projectType)
            {
                case ElixirProjectType.Script:
                    outputs ~= target.sources; // Scripts are their own output
                    break;
                case ElixirProjectType.Escript:
                    outputs ~= buildPath(config.options.outputDir, name);
                    break;
                case ElixirProjectType.MixProject:
                case ElixirProjectType.Phoenix:
                case ElixirProjectType.PhoenixLiveView:
                case ElixirProjectType.Library:
                    // BEAM files in _build directory
                    string buildDir = elixirConfig.project.buildPath;
                    string envDir = envToString(elixirConfig.env);
                    outputs ~= buildPath(buildDir, envDir, "lib");
                    break;
                case ElixirProjectType.Umbrella:
                    // Each app in umbrella
                    string buildDir = elixirConfig.project.buildPath;
                    string envDir = envToString(elixirConfig.env);
                    foreach (app; elixirConfig.umbrella.apps)
                    {
                        outputs ~= buildPath(buildDir, envDir, "lib", app);
                    }
                    break;
                case ElixirProjectType.Nerves:
                    // Firmware file
                    outputs ~= buildPath(config.options.outputDir, name ~ ".fw");
                    break;
            }
            
            // Add release output if configured
            if (elixirConfig.release.type != ReleaseType.None)
            {
                outputs ~= buildPath(elixirConfig.release.path, elixirConfig.release.name);
            }
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(
        const Target target,
        const WorkspaceConfig config,
        ElixirConfig elixirConfig,
        string elixirCmd,
        string mixCmd
    ) @trusted
    {
        LanguageBuildResult result;
        
        // Pre-build steps
        if (!preBuildSteps(elixirConfig, config.root, mixCmd))
        {
            result.error = "Pre-build steps failed";
            return result;
        }
        
        // Auto-format if configured
        if (elixirConfig.format.enabled)
        {
            Logger.info("Auto-formatting code");
            auto formatResult = Formatter.format(
                elixirConfig.format,
                cast(string[])target.sources,
                mixCmd,
                elixirConfig.format.checkFormatted
            );
            
            if (!formatResult.success && elixirConfig.format.checkFormatted)
            {
                result.error = "Code is not properly formatted";
                return result;
            }
            
            if (formatResult.hasIssues())
            {
                foreach (issue; formatResult.issues)
                {
                    Logger.warning("  " ~ issue);
                }
            }
        }
        
        // Run Credo if configured
        if (elixirConfig.credo.enabled)
        {
            Logger.info("Running Credo static analysis");
            auto credoResult = CredoChecker.check(elixirConfig.credo, mixCmd);
            
            if (credoResult.hasErrors())
            {
                result.error = "Credo found critical issues:\n" ~ credoResult.errors.join("\n");
                return result;
            }
            
            if (credoResult.hasWarnings())
            {
                Logger.warning("Credo warnings:");
                foreach (warning; credoResult.warnings)
                {
                    Logger.warning("  " ~ warning);
                }
            }
        }
        
        // Build using appropriate builder
        auto builder = BuilderFactory.create(elixirConfig.projectType, elixirConfig);
        
        if (!builder.isAvailable())
        {
            result.error = "Required tools not available for " ~ elixirConfig.projectType.to!string;
            return result;
        }
        
        Logger.debug_("Using builder: " ~ builder.name());
        
        auto buildResult = builder.build(cast(string[])target.sources, elixirConfig, cast(Target)target, cast(WorkspaceConfig)config);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        // Report warnings
        if (!buildResult.warnings.empty)
        {
            Logger.info("Build completed with warnings:");
            foreach (warning; buildResult.warnings)
            {
                Logger.warning("  " ~ warning);
            }
        }
        
        // Post-build steps
        if (result.success)
        {
            postBuildSteps(elixirConfig, config.root, mixCmd, buildResult);
        }
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        const Target target,
        const WorkspaceConfig config,
        ElixirConfig elixirConfig,
        string elixirCmd,
        string mixCmd
    ) @trusted
    {
        LanguageBuildResult result;
        
        // Libraries should use Library mode
        if (elixirConfig.projectType == ElixirProjectType.MixProject)
        {
            elixirConfig.projectType = ElixirProjectType.Library;
        }
        
        // Pre-build steps
        if (!preBuildSteps(elixirConfig, config.root, mixCmd))
        {
            result.error = "Pre-build steps failed";
            return result;
        }
        
        // Format check
        if (elixirConfig.format.enabled)
        {
            auto formatResult = Formatter.format(
                elixirConfig.format,
                cast(string[])target.sources,
                mixCmd,
                elixirConfig.format.checkFormatted
            );
            
            if (!formatResult.success && elixirConfig.format.checkFormatted)
            {
                result.error = "Code is not properly formatted";
                return result;
            }
        }
        
        // Run Dialyzer if configured
        if (elixirConfig.dialyzer.enabled)
        {
            Logger.info("Running Dialyzer type analysis");
            auto dialyzerResult = DialyzerChecker.check(elixirConfig.dialyzer, mixCmd);
            
            if (dialyzerResult.hasErrors())
            {
                result.error = "Dialyzer found type errors:\n" ~ dialyzerResult.errors.join("\n");
                return result;
            }
            
            if (dialyzerResult.hasWarnings())
            {
                Logger.warning("Dialyzer warnings:");
                foreach (warning; dialyzerResult.warnings)
                {
                    Logger.warning("  " ~ warning);
                }
            }
        }
        
        // Build
        auto builder = BuilderFactory.create(elixirConfig.projectType, elixirConfig);
        auto buildResult = builder.build(cast(string[])target.sources, elixirConfig, cast(Target)target, cast(WorkspaceConfig)config);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        // Generate documentation if configured
        if (result.success && elixirConfig.docs.enabled)
        {
            Logger.info("Generating documentation");
            DocGenerator.generate(elixirConfig.docs, mixCmd);
        }
        
        // Build Hex package if configured
        if (result.success && elixirConfig.hex.publish)
        {
            Logger.info("Building Hex package");
            HexManager.buildPackage(elixirConfig.hex, mixCmd);
        }
        
        return result;
    }
    
    private LanguageBuildResult runTests(
        const Target target,
        const WorkspaceConfig config,
        ElixirConfig elixirConfig,
        string elixirCmd,
        string mixCmd
    ) @trusted
    {
        LanguageBuildResult result;
        
        // Pre-build steps (compile dependencies)
        if (!preBuildSteps(elixirConfig, config.root, mixCmd))
        {
            result.error = "Pre-build steps failed";
            return result;
        }
        
        // Build test command
        string[] cmd = [mixCmd, "test"];
        
        // Set MIX_ENV to test
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        env["MIX_ENV"] = "test";
        
        // Merge custom environment variables
        foreach (key, value; elixirConfig.env_)
            env[key] = value;
        
        // Add ExUnit options
        if (elixirConfig.test.trace)
            cmd ~= "--trace";
        
        if (elixirConfig.test.maxCases > 0)
            cmd ~= ["--max-cases", elixirConfig.test.maxCases.to!string];
        
        foreach (tag; elixirConfig.test.exclude)
            cmd ~= ["--exclude", tag];
        
        foreach (tag; elixirConfig.test.include)
            cmd ~= ["--include", tag];
        
        foreach (tag; elixirConfig.test.only)
            cmd ~= ["--only", tag];
        
        if (elixirConfig.test.seed > 0)
            cmd ~= ["--seed", elixirConfig.test.seed.to!string];
        
        if (elixirConfig.test.timeout > 0)
            cmd ~= ["--timeout", elixirConfig.test.timeout.to!string];
        
        if (!elixirConfig.test.colors)
            cmd ~= "--no-color";
        
        // Add test paths
        if (!elixirConfig.test.testPaths.empty)
            cmd ~= elixirConfig.test.testPaths;
        
        Logger.info("Running ExUnit tests: " ~ cmd.join(" "));
        
        // Run tests
        auto res = execute(cmd, env, Config.none, size_t.max, config.root);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        // Run coverage if configured
        if (elixirConfig.coverage.enabled)
        {
            Logger.info("Generating test coverage");
            
            string[] covCmd = [mixCmd];
            if (!elixirConfig.test.coverageTool.empty)
                covCmd ~= [elixirConfig.test.coverageTool];
            else
                covCmd ~= ["coveralls"];
            
            if (!elixirConfig.coverage.post)
                covCmd ~= ["--local"];
            
            auto covRes = execute(covCmd, env, Config.none, size_t.max, config.root);
            
            if (covRes.status != 0)
            {
                Logger.warning("Coverage generation failed");
            }
        }
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(
        const Target target,
        const WorkspaceConfig config,
        ElixirConfig elixirConfig,
        string elixirCmd,
        string mixCmd
    ) @safe
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Parse Elixir configuration from target
    private ElixirConfig parseElixirConfig(const Target target) @trusted
    {
        ElixirConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("elixir" in target.langConfig)
            configKey = "elixir";
        else if ("elixirConfig" in target.langConfig)
            configKey = "elixirConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = ElixirConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse Elixir config, using defaults: " ~ e.msg);
            }
        }
        
        return config;
    }
    
    /// Enhance configuration based on project structure
    private void enhanceConfigFromProject(
        ref ElixirConfig config,
        const Target target,
        const WorkspaceConfig workspace
    ) @trusted
    {
        if (target.sources.empty)
            return;
        
        string sourceDir = dirName(target.sources[0]);
        
        // Auto-detect project type
        if (config.projectType == ElixirProjectType.MixProject)
        {
            auto detectedType = ProjectDetector.detectProjectType(sourceDir);
            if (detectedType != ElixirProjectType.MixProject)
            {
                config.projectType = detectedType;
                Logger.debug_("Detected project type: " ~ detectedType.to!string);
            }
        }
        
        // Parse mix.exs if exists
        string mixExsPath = buildPath(sourceDir, config.project.mixExsPath);
        if (exists(mixExsPath))
        {
            auto mixInfo = MixProjectParser.parse(mixExsPath);
            
            if (config.project.name.empty && !mixInfo.name.empty)
                config.project.name = mixInfo.name;
            
            if (config.project.app.empty && !mixInfo.app.empty)
                config.project.app = mixInfo.app;
            
            if (config.project.version_.empty && !mixInfo.version_.empty)
                config.project.version_ = mixInfo.version_;
            
            Logger.debug_("Parsed Mix project: " ~ mixInfo.app);
        }
        
        // Check for Phoenix
        if (ProjectDetector.isPhoenixProject(sourceDir))
        {
            config.phoenix.enabled = true;
            Logger.debug_("Detected Phoenix application");
            
            if (ProjectDetector.hasLiveView(sourceDir))
            {
                config.phoenix.liveView = true;
                Logger.debug_("Detected Phoenix LiveView");
            }
        }
        
        // Check for umbrella
        if (ProjectDetector.isUmbrellaProject(sourceDir))
        {
            config.projectType = ElixirProjectType.Umbrella;
            auto apps = ProjectDetector.getUmbrellaApps(sourceDir, config.umbrella.appsDir);
            if (!apps.empty)
            {
                config.umbrella.apps = apps;
                Logger.debug_("Detected umbrella apps: " ~ apps.join(", "));
            }
        }
        
        // Check for Nerves
        if (ProjectDetector.isNervesProject(sourceDir))
        {
            config.nerves.enabled = true;
            Logger.debug_("Detected Nerves project");
        }
        
        // Check for .tool-versions (asdf)
        string toolVersionsPath = buildPath(sourceDir, ".tool-versions");
        if (exists(toolVersionsPath))
        {
            auto versions = VersionManager.parseToolVersions(toolVersionsPath);
            if ("elixir" in versions)
            {
                Logger.debug_("Found Elixir version in .tool-versions: " ~ versions["elixir"]);
            }
        }
    }
    
    /// Setup Elixir environment and return Elixir command to use
    private string setupElixirEnvironment(ElixirConfig config, string projectRoot) @trusted
    {
        string elixirCmd = "elixir";
        
        // Use specific path if configured
        if (!config.elixirVersion.elixirPath.empty)
        {
            elixirCmd = config.elixirVersion.elixirPath;
        }
        else if (config.elixirVersion.useAsdf)
        {
            // Use asdf version manager
            auto vm = new AsdfVersionManager(projectRoot);
            if (vm.isAvailable())
            {
                elixirCmd = vm.getElixirPath();
                Logger.info("Using Elixir from asdf: " ~ vm.getCurrentVersion());
            }
        }
        
        // Verify Elixir is available
        if (!ElixirTools.isElixirAvailable(elixirCmd))
        {
            Logger.warning("Elixir not available at: " ~ elixirCmd ~ ", falling back to 'elixir'");
            elixirCmd = "elixir";
        }
        
        auto version_ = ElixirTools.getElixirVersion(elixirCmd);
        Logger.debug_("Using Elixir: " ~ elixirCmd ~ " (" ~ version_ ~ ")");
        
        return elixirCmd;
    }
    
    /// Setup Mix command
    private string setupMixCommand(ElixirConfig config, string projectRoot) @trusted
    {
        string mixCmd = "mix";
        
        // Use local mix if available
        string localMix = buildPath(projectRoot, "mix");
        if (exists(localMix))
        {
            mixCmd = localMix;
        }
        
        if (!ElixirTools.isMixAvailable(mixCmd))
        {
            Logger.warning("Mix not available");
        }
        
        return mixCmd;
    }
    
    /// Pre-build steps (dependencies, compilation)
    private bool preBuildSteps(ElixirConfig config, string projectRoot, string mixCmd) @trusted
    {
        // Clean if requested
        if (config.clean)
        {
            Logger.info("Cleaning build artifacts");
            auto cleanRes = execute([mixCmd, "clean"], null, Config.none, size_t.max, projectRoot);
            if (cleanRes.status != 0)
            {
                Logger.warning("Clean failed");
            }
        }
        
        // Install/update dependencies
        if (config.installDeps || config.depsGet)
        {
            Logger.info("Fetching dependencies");
            auto depsRes = execute([mixCmd, "deps.get"], null, Config.none, size_t.max, projectRoot);
            if (depsRes.status != 0)
            {
                Logger.error("Failed to fetch dependencies: " ~ depsRes.output);
                return false;
            }
        }
        
        // Clean dependencies if requested
        if (config.depsClean)
        {
            Logger.info("Cleaning dependencies");
            auto cleanRes = execute([mixCmd, "deps.clean", "--all"], null, Config.none, size_t.max, projectRoot);
            if (cleanRes.status != 0)
            {
                Logger.warning("Deps clean failed");
            }
        }
        
        // Compile dependencies
        if (config.depsCompile)
        {
            Logger.info("Compiling dependencies");
            auto compRes = execute([mixCmd, "deps.compile"], null, Config.none, size_t.max, projectRoot);
            if (compRes.status != 0)
            {
                Logger.error("Failed to compile dependencies: " ~ compRes.output);
                return false;
            }
        }
        
        return true;
    }
    
    /// Post-build steps (Dialyzer, releases, etc.)
    private void postBuildSteps(
        ElixirConfig config,
        string projectRoot,
        string mixCmd,
        ElixirBuildResult buildResult
    ) @trusted
    {
        // Run Dialyzer if configured (post-build for type checking)
        if (config.dialyzer.enabled)
        {
            Logger.info("Running Dialyzer");
            auto dialyzerResult = DialyzerChecker.check(config.dialyzer, mixCmd);
            if (dialyzerResult.hasWarnings())
            {
                Logger.warning("Dialyzer warnings:");
                foreach (warning; dialyzerResult.warnings)
                {
                    Logger.warning("  " ~ warning);
                }
            }
        }
        
        // Build release if configured
        if (config.release.type != ReleaseType.None)
        {
            Logger.info("Building release");
            auto releaseBuilder = ReleaseManager.createBuilder(config.release.type);
            if (releaseBuilder.isAvailable())
            {
                releaseBuilder.buildRelease(config.release, mixCmd);
            }
        }
        
        // Generate documentation if configured
        if (config.docs.enabled)
        {
            Logger.info("Generating documentation");
            DocGenerator.generate(config.docs, mixCmd);
        }
    }
    
    /// Convert MixEnv to string
    private string envToString(MixEnv env) @safe pure nothrow
    {
        final switch (env)
        {
            case MixEnv.Dev: return "dev";
            case MixEnv.Test: return "test";
            case MixEnv.Prod: return "prod";
            case MixEnv.Custom: return "custom";
        }
    }
    
    override Import[] analyzeImports(in string[] sources) @trusted
    {
        auto spec = getLanguageSpec(TargetLanguage.Elixir);
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

