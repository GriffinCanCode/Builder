module languages.scripting.perl.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import std.json;
import std.string : lineSplitter, strip, indexOf;
import languages.base.base;
import languages.base.mixins;
import languages.scripting.perl.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;
import core.caching.action : ActionCache, ActionCacheConfig, ActionId, ActionType;

/// Perl build handler with action-level caching
class PerlHandler : BaseLanguageHandler
{
    mixin CachingHandlerMixin!"perl";
    mixin ConfigParsingMixin!(PerlConfig, "parsePerlConfig", ["perl", "perlConfig"]);
    mixin OutputResolutionMixin!(PerlConfig, "parsePerlConfig");
    mixin SimpleBuildOrchestrationMixin!(PerlConfig, "parsePerlConfig");
    
    private void enhanceConfigFromProject(
        ref PerlConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        // Validate Perl is available
        if (!isPerlAvailable(config))
        {
            Logger.warning("Perl interpreter not available at: " ~ config.perlVersion.interpreterPath);
        }
    }
    
    private LanguageBuildResult buildExecutable(
        const Target target,
        const WorkspaceConfig config,
        PerlConfig perlConfig
    )
    {
        LanguageBuildResult result;
        
        // Install dependencies if requested
        if (perlConfig.installDeps && !perlConfig.modules.empty)
        {
            if (!installDependencies(perlConfig, config.root))
            {
                result.error = "Failed to install dependencies";
                return result;
            }
        }
        
        // Format code if configured
        if (perlConfig.format.autoFormat)
        {
            formatCode(target.sources, perlConfig);
        }
        
        // Lint with Perl::Critic if configured
        if (perlConfig.format.formatter == PerlFormatter.PerlCritic ||
            perlConfig.format.formatter == PerlFormatter.Both)
        {
            auto critResult = lintWithCritic(target.sources, perlConfig);
            if (!critResult.success && perlConfig.format.failOnCritic)
            {
                result.error = "Perl::Critic violations found:\n" ~ critResult.error;
                return result;
            }
        }
        
        // Syntax check
        string[] syntaxErrors;
        if (!checkSyntax(target.sources, perlConfig, syntaxErrors))
        {
            result.error = "Syntax errors:\n" ~ syntaxErrors.join("\n");
            return result;
        }
        
        // For executable scripts, create output or copy to bin
        if (!target.sources.empty)
        {
            string mainScript = target.sources[0];
            string outputPath;
            
            if (!target.outputPath.empty)
            {
                outputPath = buildPath(config.options.outputDir, target.outputPath);
            }
            else
            {
                auto baseName = mainScript.baseName.stripExtension;
                outputPath = buildPath(config.options.outputDir, baseName);
            }
            
            // Ensure output directory exists
            auto outputDir = outputPath.dirName;
            if (!exists(outputDir))
            {
                mkdirRecurse(outputDir);
            }
            
            // Copy script to output and make executable
            try
            {
                copy(mainScript, outputPath);
                version(Posix)
                {
                    import std.process : executeShell;
                    executeShell("chmod +x " ~ outputPath);
                }
                result.outputs ~= outputPath;
                result.success = true;
                result.outputHash = FastHash.hashFile(mainScript);
            }
            catch (Exception e)
            {
                result.error = "Failed to create executable: " ~ e.msg;
                return result;
            }
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        const Target target,
        const WorkspaceConfig config,
        PerlConfig perlConfig
    )
    {
        LanguageBuildResult result;
        
        // Install dependencies if requested
        if (perlConfig.installDeps && !perlConfig.modules.empty)
        {
            if (!installDependencies(perlConfig, config.root))
            {
                result.error = "Failed to install dependencies";
                return result;
            }
        }
        
        // Syntax check all module files
        string[] syntaxErrors;
        if (!checkSyntax(target.sources, perlConfig, syntaxErrors))
        {
            result.error = "Syntax errors:\n" ~ syntaxErrors.join("\n");
            return result;
        }
        
        // For CPAN mode, run build tool
        if (perlConfig.mode == PerlBuildMode.CPAN)
        {
            return buildCPANModule(target, config, perlConfig);
        }
        
        // For regular modules, just validate
        result.success = true;
        result.outputs = target.sources.dup;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        // Generate documentation if configured
        if (perlConfig.documentation.generator != PerlDocGenerator.None)
        {
            generateDocumentation(target.sources, perlConfig, config.root);
        }
        
        return result;
    }
    
    private LanguageBuildResult runTests(
        const Target target,
        const WorkspaceConfig config,
        PerlConfig perlConfig
    )
    {
        LanguageBuildResult result;
        
        // Determine test framework
        auto framework = perlConfig.test.framework;
        if (framework == PerlTestFramework.Auto)
        {
            framework = detectTestFramework(config.root);
        }
        
        // Run tests based on framework
        final switch (framework)
        {
            case PerlTestFramework.Auto:
                // Fallback to prove
                framework = PerlTestFramework.Prove;
                goto case PerlTestFramework.Prove;
            
            case PerlTestFramework.Prove:
                result = runProveTests(target, perlConfig, config.root);
                break;
            
            case PerlTestFramework.TestMore:
            case PerlTestFramework.Test2:
            case PerlTestFramework.TestClass:
                result = runPerlTests(target, perlConfig, config.root);
                break;
            
            case PerlTestFramework.TAPHarness:
                result = runTAPHarness(target, perlConfig, config.root);
                break;
            
            case PerlTestFramework.None:
                result.success = true;
                break;
        }
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(
        const Target target,
        const WorkspaceConfig config,
        PerlConfig perlConfig
    )
    {
        LanguageBuildResult result;
        
        // For custom builds, just validate syntax
        string[] syntaxErrors;
        if (!checkSyntax(target.sources, perlConfig, syntaxErrors))
        {
            result.error = "Syntax errors:\n" ~ syntaxErrors.join("\n");
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    private LanguageBuildResult buildCPANModule(
        const Target target,
        const WorkspaceConfig config,
        PerlConfig perlConfig
    )
    {
        LanguageBuildResult result;
        
        // Detect build tool
        auto buildTool = perlConfig.buildTool;
        if (buildTool == PerlBuildTool.Auto)
        {
            if (exists(buildPath(config.root, "Build.PL")))
                buildTool = PerlBuildTool.ModuleBuild;
            else if (exists(buildPath(config.root, "Makefile.PL")))
                buildTool = PerlBuildTool.MakeMaker;
            else if (exists(buildPath(config.root, "dist.ini")))
                buildTool = PerlBuildTool.DistZilla;
            else if (exists(buildPath(config.root, "minil.toml")))
                buildTool = PerlBuildTool.Minilla;
        }
        
        // Run appropriate build tool
        final switch (buildTool)
        {
            case PerlBuildTool.Auto:
                result.error = "Could not detect CPAN build tool (no Build.PL or Makefile.PL found)";
                return result;
            
            case PerlBuildTool.ModuleBuild:
                return runModuleBuild(config.root);
            
            case PerlBuildTool.MakeMaker:
                return runMakeMaker(config.root);
            
            case PerlBuildTool.DistZilla:
                return runDistZilla(config.root);
            
            case PerlBuildTool.Minilla:
                return runMinilla(config.root);
            
            case PerlBuildTool.None:
                result.success = true;
                break;
        }
        
        return result;
    }
    
    /// Check if Perl is available
    private bool isPerlAvailable(const PerlConfig config)
    {
        string perlCmd = config.perlVersion.interpreterPath.empty ? "perl" : config.perlVersion.interpreterPath;
        
        try
        {
            auto result = execute([perlCmd, "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Check syntax of Perl files with action-level caching
    private bool checkSyntax(const string[] sources, const PerlConfig config, ref string[] errors)
    {
        string perlCmd = config.perlVersion.interpreterPath.empty ? "perl" : config.perlVersion.interpreterPath;
        bool allValid = true;
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            // Build metadata for cache validation
            string[string] metadata;
            metadata["interpreter"] = perlCmd;
            metadata["warnings"] = config.warnings.to!string;
            metadata["includeDirs"] = config.includeDirs.join(",");
            
            // Create action ID for syntax check
            ActionId actionId;
            actionId.targetId = "syntax_check";
            actionId.type = ActionType.Compile;
            actionId.subId = baseName(source);
            actionId.inputHash = FastHash.hashFile(source);
            
            // Check if syntax check is cached
            if (getCache().isCached(actionId, [source], metadata))
            {
                Logger.debugLog("  [Cached] Syntax check: " ~ source);
                continue;
            }
            
            // Build command
            string[] cmd = [perlCmd, "-c"];
            
            // Add warning and strict flags
            if (config.warnings)
                cmd ~= "-w";
            
            // Add include directories
            foreach (incDir; config.includeDirs)
            {
                cmd ~= ["-I", incDir];
            }
            
            cmd ~= source;
            
            bool success = false;
            try
            {
                auto res = execute(cmd);
                success = (res.status == 0);
                
                if (!success)
                {
                    errors ~= source ~ ": " ~ res.output;
                    allValid = false;
                }
            }
            catch (Exception e)
            {
                errors ~= source ~ ": " ~ e.msg;
                allValid = false;
            }
            
            // Update cache with syntax check result
            getCache().update(
                actionId,
                [source],
                [],
                metadata,
                success
            );
        }
        
        return allValid;
    }
    
    /// Format code with perltidy
    private void formatCode(const string[] sources, const PerlConfig config)
    {
        // Check if perltidy is available
        try
        {
            auto checkResult = execute(["perltidy", "--version"]);
            if (checkResult.status != 0)
                return;
        }
        catch (Exception e)
        {
            return;
        }
        
        Logger.info("Formatting Perl code with perltidy");
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            string[] cmd = ["perltidy", "-b"]; // -b for backup and in-place edit
            
            if (exists(config.format.perltidyrc))
                cmd ~= ["-pro=" ~ config.format.perltidyrc];
            
            cmd ~= source;
            
            try
            {
                execute(cmd);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to format " ~ source ~ ": " ~ e.msg);
            }
        }
    }
    
    /// Lint with Perl::Critic with action-level caching
    private LanguageBuildResult lintWithCritic(const string[] sources, const PerlConfig config)
    {
        LanguageBuildResult result;
        
        // Check if perlcritic is available
        try
        {
            auto checkResult = execute(["perlcritic", "--version"]);
            if (checkResult.status != 0)
            {
                result.success = true;
                return result;
            }
        }
        catch (Exception e)
        {
            result.success = true;
            return result;
        }
        
        Logger.info("Linting Perl code with Perl::Critic");
        
        // Build metadata for cache validation
        string[string] metadata;
        metadata["severity"] = config.format.critic.severity.to!string;
        metadata["verbose"] = config.format.critic.verbose.to!string;
        metadata["theme"] = config.format.critic.theme;
        metadata["include"] = config.format.critic.include.join(",");
        metadata["exclude"] = config.format.critic.exclude.join(",");
        if (exists(config.format.perlcriticrc))
            metadata["profile"] = FastHash.hashFile(config.format.perlcriticrc);
        
        // Create action ID for perlcritic analysis
        ActionId actionId;
        actionId.targetId = "perlcritic";
        actionId.type = ActionType.Custom;
        actionId.subId = "analysis";
        actionId.inputHash = FastHash.hashStrings(sources);
        
        // Check if analysis is cached
        if (getCache().isCached(actionId, sources, metadata))
        {
            Logger.info("  [Cached] Perl::Critic analysis");
            result.success = true;
            return result;
        }
        
        string[] cmd = ["perlcritic"];
        
        // Add severity
        cmd ~= ["--severity", config.format.critic.severity.to!string];
        
        // Add config file if exists
        if (exists(config.format.perlcriticrc))
            cmd ~= ["--profile", config.format.perlcriticrc];
        
        // Add verbose/color flags
        if (config.format.critic.verbose)
            cmd ~= "--verbose";
        
        // Add theme
        if (!config.format.critic.theme.empty)
            cmd ~= ["--theme", config.format.critic.theme];
        
        // Add include/exclude policies
        foreach (policy; config.format.critic.include)
            cmd ~= ["--include", policy];
        foreach (policy; config.format.critic.exclude)
            cmd ~= ["--exclude", policy];
        
        cmd ~= sources;
        
        bool success = false;
        try
        {
            auto res = execute(cmd);
            success = (res.status == 0);
            if (!success)
            {
                result.error = res.output;
            }
            else
            {
                result.success = true;
            }
        }
        catch (Exception e)
        {
            result.error = e.msg;
        }
        
        // Update cache with analysis result
        getCache().update(
            actionId,
            sources,
            [],
            metadata,
            success
        );
        
        return result;
    }
    
    /// Install dependencies with action-level caching
    private bool installDependencies(const PerlConfig config, string projectRoot)
    {
        PerlPackageManager pm = config.packageManager;
        if (pm == PerlPackageManager.Auto)
        {
            // Auto-detect best available package manager
            if (isCommandAvailable("cpanm"))
                pm = PerlPackageManager.CPANMinus;
            else if (isCommandAvailable("cpm"))
                pm = PerlPackageManager.CPM;
            else if (isCommandAvailable("cpan"))
                pm = PerlPackageManager.CPAN;
            else
            {
                Logger.error("No CPAN package manager found");
                return false;
            }
        }
        
        // Get package manager command
        string pmCmd;
        final switch (pm)
        {
            case PerlPackageManager.Auto:
                return false;
            case PerlPackageManager.CPANMinus:
                pmCmd = "cpanm";
                break;
            case PerlPackageManager.CPM:
                pmCmd = "cpm";
                break;
            case PerlPackageManager.CPAN:
                pmCmd = "cpan";
                break;
            case PerlPackageManager.Carton:
                pmCmd = "carton";
                break;
            case PerlPackageManager.None:
                return true;
        }
        
        Logger.info("Installing dependencies with " ~ pmCmd);
        
        // Install modules with per-module caching
        foreach (mod; config.modules)
        {
            // Build metadata for cache validation
            string[string] metadata;
            metadata["packageManager"] = pmCmd;
            metadata["useLocalLib"] = config.cpan.useLocalLib.to!string;
            metadata["localLibDir"] = config.cpan.localLibDir;
            metadata["version"] = mod.version_;
            
            // Add module with version if specified
            string modSpec = mod.name;
            if (!mod.version_.empty)
                modSpec ~= "@" ~ mod.version_;
            
            // Create action ID for dependency installation
            ActionId actionId;
            actionId.targetId = "perl_deps";
            actionId.type = ActionType.Package;
            actionId.subId = mod.name;
            actionId.inputHash = FastHash.hashString(modSpec);
            
            // Check if module installation is cached
            if (getCache().isCached(actionId, [], metadata))
            {
                Logger.debugLog("  [Cached] Module: " ~ modSpec);
                continue;
            }
            
            string[] cmd = [pmCmd];
            
            // Add local::lib options
            if (config.cpan.useLocalLib && !config.cpan.localLibDir.empty)
            {
                cmd ~= ["-L", config.cpan.localLibDir];
            }
            
            cmd ~= modSpec;
            
            Logger.debugLog("Installing: " ~ modSpec);
            
            bool success = false;
            try
            {
                auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
                success = (res.status == 0);
                if (!success)
                {
                    Logger.error("Failed to install " ~ modSpec ~ ": " ~ res.output);
                    if (!mod.optional)
                    {
                        getCache().update(actionId, [], [], metadata, false);
                        return false;
                    }
                }
            }
            catch (Exception e)
            {
                Logger.error("Failed to install " ~ modSpec ~ ": " ~ e.msg);
                if (!mod.optional)
                {
                    getCache().update(actionId, [], [], metadata, false);
                    return false;
                }
            }
            
            // Update cache with installation result
            getCache().update(actionId, [], [], metadata, success);
        }
        
        return true;
    }
    
    /// Run prove tests with action-level caching
    private LanguageBuildResult runProveTests(
        const Target target,
        const PerlConfig config,
        string projectRoot
    )
    {
        LanguageBuildResult result;
        
        if (!isCommandAvailable("prove"))
        {
            result.error = "prove command not available";
            return result;
        }
        
        // Gather test files for cache validation
        string[] testFiles;
        if (!config.test.testPaths.empty)
        {
            foreach (testPath; config.test.testPaths)
            {
                auto fullPath = buildPath(projectRoot, testPath);
                if (exists(fullPath) && isDir(fullPath))
                {
                    foreach (entry; dirEntries(fullPath, "*.t", SpanMode.depth))
                    {
                        testFiles ~= entry.name;
                    }
                }
                else if (exists(fullPath) && isFile(fullPath))
                {
                    testFiles ~= fullPath;
                }
            }
        }
        else if (exists(buildPath(projectRoot, "t")))
        {
            foreach (entry; dirEntries(buildPath(projectRoot, "t"), "*.t", SpanMode.depth))
            {
                testFiles ~= entry.name;
            }
        }
        
        // Build metadata for cache validation
        string[string] metadata;
        metadata["verbose"] = config.test.prove.verbose.to!string;
        metadata["lib"] = config.test.prove.lib.to!string;
        metadata["recurse"] = config.test.prove.recurse.to!string;
        metadata["parallel"] = config.test.parallel.to!string;
        metadata["jobs"] = config.test.jobs.to!string;
        metadata["includes"] = config.test.prove.includes.join(",");
        
        // Create action ID for test execution
        ActionId actionId;
        actionId.targetId = target.name;
        actionId.type = ActionType.Test;
        actionId.subId = "prove";
        actionId.inputHash = FastHash.hashStrings(testFiles);
        
        // Check if test execution is cached
        if (getCache().isCached(actionId, testFiles, metadata))
        {
            Logger.info("  [Cached] Test execution: prove");
            result.success = true;
            result.outputHash = FastHash.hashStrings(target.sources);
            return result;
        }
        
        string[] cmd = ["prove"];
        
        // Add prove options
        if (config.test.prove.verbose)
            cmd ~= "-v";
        
        if (config.test.prove.lib)
            cmd ~= "-l";
        
        if (config.test.prove.recurse)
            cmd ~= "-r";
        
        if (config.test.prove.timer)
            cmd ~= "--timer";
        
        if (config.test.prove.color)
            cmd ~= "--color";
        
        // Add parallel execution
        if (config.test.parallel)
        {
            int jobs = config.test.jobs;
            if (jobs == 0)
                jobs = 4; // Default
            cmd ~= ["-j", jobs.to!string];
        }
        
        // Add include directories
        foreach (incDir; config.test.prove.includes)
        {
            cmd ~= ["-I", incDir];
        }
        
        // Add test paths
        if (!config.test.testPaths.empty)
            cmd ~= config.test.testPaths;
        else
            cmd ~= "t/";
        
        Logger.info("Running tests with prove: " ~ cmd.join(" "));
        
        bool success = false;
        try
        {
            auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
            success = (res.status == 0);
            
            if (!success)
            {
                result.error = "Tests failed:\n" ~ res.output;
            }
            else
            {
                result.success = true;
                result.outputHash = FastHash.hashStrings(target.sources);
            }
        }
        catch (Exception e)
        {
            result.error = "Failed to run tests: " ~ e.msg;
        }
        
        // Update cache with test result
        getCache().update(
            actionId,
            testFiles,
            [],
            metadata,
            success
        );
        
        return result;
    }
    
    /// Run Perl tests directly
    private LanguageBuildResult runPerlTests(
        const Target target,
        const PerlConfig config,
        string projectRoot
    )
    {
        LanguageBuildResult result;
        
        string perlCmd = config.perlVersion.interpreterPath.empty ? "perl" : config.perlVersion.interpreterPath;
        
        // Find test files
        string[] testFiles;
        foreach (testPath; config.test.testPaths)
        {
            auto fullPath = buildPath(projectRoot, testPath);
            if (exists(fullPath) && isDir(fullPath))
            {
                foreach (entry; dirEntries(fullPath, "*.t", SpanMode.depth))
                {
                    testFiles ~= entry.name;
                }
            }
            else if (exists(fullPath) && isFile(fullPath))
            {
                testFiles ~= fullPath;
            }
        }
        
        if (testFiles.empty)
        {
            result.error = "No test files found";
            return result;
        }
        
        Logger.info("Running " ~ testFiles.length.to!string ~ " test files");
        
        bool allPassed = true;
        foreach (testFile; testFiles)
        {
            string[] cmd = [perlCmd];
            
            // Add include directories
            foreach (incDir; config.includeDirs)
            {
                cmd ~= ["-I", incDir];
            }
            
            cmd ~= ["-I", "lib"]; // Add standard lib directory
            
            if (config.warnings)
                cmd ~= "-w";
            
            cmd ~= testFile;
            
            try
            {
                auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
                if (res.status != 0)
                {
                    Logger.error("Test failed: " ~ testFile);
                    allPassed = false;
                }
            }
            catch (Exception e)
            {
                Logger.error("Failed to run test " ~ testFile ~ ": " ~ e.msg);
                allPassed = false;
            }
        }
        
        if (!allPassed)
        {
            result.error = "Some tests failed";
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Run TAP::Harness tests
    private LanguageBuildResult runTAPHarness(
        const Target target,
        const PerlConfig config,
        string projectRoot
    )
    {
        // TAP::Harness is more complex - for now, fall back to prove
        return runProveTests(target, config, projectRoot);
    }
    
    /// Run Module::Build with action-level caching
    private LanguageBuildResult runModuleBuild(string projectRoot)
    {
        LanguageBuildResult result;
        
        Logger.info("Building with Module::Build (Build.PL)");
        
        string buildPL = buildPath(projectRoot, "Build.PL");
        string[] inputFiles = [buildPL];
        
        // Add lib files
        string libDir = buildPath(projectRoot, "lib");
        if (exists(libDir))
        {
            foreach (entry; dirEntries(libDir, "*.pm", SpanMode.depth))
            {
                inputFiles ~= entry.name;
            }
        }
        
        // Build metadata for cache validation
        string[string] metadata;
        metadata["buildSystem"] = "Module::Build";
        
        // Create action ID
        ActionId actionId;
        actionId.targetId = baseName(projectRoot);
        actionId.type = ActionType.Package;
        actionId.subId = "module_build";
        actionId.inputHash = FastHash.hashStrings(inputFiles);
        
        // Check if build is cached
        if (getCache().isCached(actionId, inputFiles, metadata))
        {
            Logger.info("  [Cached] Module::Build");
            result.success = true;
            return result;
        }
        
        // Run Build.PL
        bool success = false;
        auto configRes = execute(["perl", "Build.PL"], null, Config.none, size_t.max, projectRoot);
        if (configRes.status != 0)
        {
            result.error = "Build.PL failed: " ~ configRes.output;
            getCache().update(actionId, inputFiles, [], metadata, false);
            return result;
        }
        
        // Run ./Build
        auto buildRes = execute(["./Build"], null, Config.none, size_t.max, projectRoot);
        if (buildRes.status != 0)
        {
            result.error = "Build failed: " ~ buildRes.output;
            getCache().update(actionId, inputFiles, [], metadata, false);
            return result;
        }
        
        success = true;
        result.success = true;
        
        // Update cache with success
        getCache().update(actionId, inputFiles, [], metadata, success);
        
        return result;
    }
    
    /// Run ExtUtils::MakeMaker with action-level caching
    private LanguageBuildResult runMakeMaker(string projectRoot)
    {
        LanguageBuildResult result;
        
        Logger.info("Building with ExtUtils::MakeMaker (Makefile.PL)");
        
        string makefilePL = buildPath(projectRoot, "Makefile.PL");
        string[] inputFiles = [makefilePL];
        
        // Add lib files
        string libDir = buildPath(projectRoot, "lib");
        if (exists(libDir))
        {
            foreach (entry; dirEntries(libDir, "*.pm", SpanMode.depth))
            {
                inputFiles ~= entry.name;
            }
        }
        
        // Build metadata for cache validation
        string[string] metadata;
        metadata["buildSystem"] = "ExtUtils::MakeMaker";
        
        // Create action ID
        ActionId actionId;
        actionId.targetId = baseName(projectRoot);
        actionId.type = ActionType.Package;
        actionId.subId = "make_maker";
        actionId.inputHash = FastHash.hashStrings(inputFiles);
        
        // Check if build is cached
        if (getCache().isCached(actionId, inputFiles, metadata))
        {
            Logger.info("  [Cached] ExtUtils::MakeMaker");
            result.success = true;
            return result;
        }
        
        // Run Makefile.PL
        bool success = false;
        auto configRes = execute(["perl", "Makefile.PL"], null, Config.none, size_t.max, projectRoot);
        if (configRes.status != 0)
        {
            result.error = "Makefile.PL failed: " ~ configRes.output;
            getCache().update(actionId, inputFiles, [], metadata, false);
            return result;
        }
        
        // Run make
        auto buildRes = execute(["make"], null, Config.none, size_t.max, projectRoot);
        if (buildRes.status != 0)
        {
            result.error = "make failed: " ~ buildRes.output;
            getCache().update(actionId, inputFiles, [], metadata, false);
            return result;
        }
        
        success = true;
        result.success = true;
        
        // Update cache with success
        getCache().update(actionId, inputFiles, [], metadata, success);
        
        return result;
    }
    
    /// Run Dist::Zilla
    private LanguageBuildResult runDistZilla(string projectRoot)
    {
        LanguageBuildResult result;
        
        if (!isCommandAvailable("dzil"))
        {
            result.error = "dzil command not available (install Dist::Zilla)";
            return result;
        }
        
        Logger.info("Building with Dist::Zilla");
        
        auto buildRes = execute(["dzil", "build"], null, Config.none, size_t.max, projectRoot);
        if (buildRes.status != 0)
        {
            result.error = "dzil build failed: " ~ buildRes.output;
            return result;
        }
        
        result.success = true;
        return result;
    }
    
    /// Run Minilla
    private LanguageBuildResult runMinilla(string projectRoot)
    {
        LanguageBuildResult result;
        
        if (!isCommandAvailable("minil"))
        {
            result.error = "minil command not available (install Minilla)";
            return result;
        }
        
        Logger.info("Building with Minilla");
        
        auto buildRes = execute(["minil", "build"], null, Config.none, size_t.max, projectRoot);
        if (buildRes.status != 0)
        {
            result.error = "minil build failed: " ~ buildRes.output;
            return result;
        }
        
        result.success = true;
        return result;
    }
    
    /// Generate documentation with action-level caching
    private void generateDocumentation(const string[] sources, const PerlConfig config, string projectRoot)
    {
        PerlDocGenerator generator = config.documentation.generator;
        if (generator == PerlDocGenerator.Auto)
        {
            generator = PerlDocGenerator.Pod2HTML;
        }
        
        string outputDir = buildPath(projectRoot, config.documentation.outputDir);
        if (!exists(outputDir))
        {
            mkdirRecurse(outputDir);
        }
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            auto baseName = source.baseName.stripExtension;
            
            // Generate HTML with caching
            if (generator == PerlDocGenerator.Pod2HTML || generator == PerlDocGenerator.Both)
            {
                string htmlOutput = buildPath(outputDir, baseName ~ ".html");
                
                // Build metadata for cache validation
                string[string] htmlMetadata;
                htmlMetadata["generator"] = "pod2html";
                htmlMetadata["outputDir"] = outputDir;
                
                // Create action ID for HTML generation
                ActionId htmlActionId;
                htmlActionId.targetId = "pod_docs";
                htmlActionId.type = ActionType.Custom;
                htmlActionId.subId = baseName ~ "_html";
                htmlActionId.inputHash = FastHash.hashFile(source);
                
                // Check if HTML generation is cached
                if (getCache().isCached(htmlActionId, [source], htmlMetadata) && exists(htmlOutput))
                {
                    Logger.debugLog("  [Cached] POD HTML: " ~ baseName);
                }
                else
                {
                    try
                    {
                        auto res = execute(["pod2html", "--infile=" ~ source, "--outfile=" ~ htmlOutput]);
                        bool success = (res.status == 0);
                        
                        getCache().update(
                            htmlActionId,
                            [source],
                            [htmlOutput],
                            htmlMetadata,
                            success
                        );
                    }
                    catch (Exception e)
                    {
                        Logger.warning("Failed to generate HTML docs for " ~ source);
                        getCache().update(htmlActionId, [source], [], htmlMetadata, false);
                    }
                }
            }
            
            // Generate man pages with caching
            if (generator == PerlDocGenerator.Pod2Man || generator == PerlDocGenerator.Both)
            {
                if (config.documentation.generateMan)
                {
                    string manOutput = buildPath(outputDir, baseName ~ "." ~ config.documentation.manSection.to!string);
                    
                    // Build metadata for cache validation
                    string[string] manMetadata;
                    manMetadata["generator"] = "pod2man";
                    manMetadata["manSection"] = config.documentation.manSection.to!string;
                    manMetadata["outputDir"] = outputDir;
                    
                    // Create action ID for man page generation
                    ActionId manActionId;
                    manActionId.targetId = "pod_docs";
                    manActionId.type = ActionType.Custom;
                    manActionId.subId = baseName ~ "_man";
                    manActionId.inputHash = FastHash.hashFile(source);
                    
                    // Check if man generation is cached
                    if (getCache().isCached(manActionId, [source], manMetadata) && exists(manOutput))
                    {
                        Logger.debugLog("  [Cached] POD man: " ~ baseName);
                    }
                    else
                    {
                        try
                        {
                            auto res = execute(["pod2man", source, manOutput]);
                            bool success = (res.status == 0);
                            
                            getCache().update(
                                manActionId,
                                [source],
                                [manOutput],
                                manMetadata,
                                success
                            );
                        }
                        catch (Exception e)
                        {
                            Logger.warning("Failed to generate man page for " ~ source);
                            getCache().update(manActionId, [source], [], manMetadata, false);
                        }
                    }
                }
            }
        }
    }
    
    /// Detect test framework from project
    private PerlTestFramework detectTestFramework(string projectRoot)
    {
        // Check for prove
        if (isCommandAvailable("prove"))
            return PerlTestFramework.Prove;
        
        // Check for Test2
        try
        {
            auto res = execute(["perl", "-MTest2", "-e", "1"]);
            if (res.status == 0)
                return PerlTestFramework.Test2;
        }
        catch (Exception e) {}
        
        // Fallback to Test::More (most common)
        return PerlTestFramework.TestMore;
    }
    
    /// Check if a command is available
    private bool isCommandAvailable(string cmd)
    {
        try
        {
            version(Windows)
            {
                auto res = execute(["where", cmd]);
                return res.status == 0;
            }
            else
            {
                auto res = execute(["which", cmd]);
                return res.status == 0;
            }
        }
        catch (Exception e)
        {
            return false;
        }
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
                auto imports = () @trusted { return parsePerlImports(source, content); }();
                allImports ~= imports;
            }
            catch (Exception e)
            {
                Logger.warning("Failed to analyze imports in " ~ source ~ ": " ~ e.msg);
            }
        }
        
        return allImports;
    }
    
    /// Parse Perl imports from file content
    private Import[] parsePerlImports(string filepath, string content)
    {
        Import[] imports;
        
        import std.regex;
        
        // Match: use Module;
        // Or: use Module qw(...);
        // Or: require Module;
        auto useRegex = regex(`^\s*(?:use|require)\s+([A-Za-z_]\w*(?:::\w+)*)\s*`, "m");
        
        size_t lineNum = 1;
        foreach (line; lineSplitter(content))
        {
            auto matches = matchFirst(line, useRegex);
            if (!matches.empty && matches.length >= 2)
            {
                Import imp;
                imp.moduleName = matches[1];
                imp.kind = determineImportKind(matches[1]);
                imp.location = SourceLocation(filepath, lineNum, 0);
                imports ~= imp;
            }
            lineNum++;
        }
        
        return imports;
    }
    
    /// Determine import kind for Perl modules
    private ImportKind determineImportKind(string moduleName)
    {
        // Core modules
        const string[] coreModules = [
            "strict", "warnings", "base", "parent", "Carp", "Data::Dumper",
            "File::Spec", "File::Basename", "File::Path", "Cwd",
            "Getopt::Long", "Getopt::Std", "Time::HiRes", "Scalar::Util",
            "List::Util", "Test::More", "Test2::V0"
        ];
        
        foreach (core; coreModules)
        {
            if (moduleName == core)
                return ImportKind.External; // Core modules treated as external
        }
        
        // Relative imports (modules in same project, typically start with project namespace)
        // For now, assume single-word modules or those starting with lowercase are relative
        import std.uni : isLower;
        if (moduleName.indexOf("::") < 0 || (moduleName.length > 0 && isLower(moduleName[0])))
            return ImportKind.Relative;
        
        // Everything else is external (CPAN modules)
        return ImportKind.External;
    }
}

