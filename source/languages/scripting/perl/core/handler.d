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
import languages.scripting.perl.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Perl build handler
class PerlHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debugLog("Building Perl target: " ~ target.name);
        
        // Parse Perl configuration
        PerlConfig perlConfig = parsePerlConfig(target);
        
        // Validate Perl is available
        if (!isPerlAvailable(perlConfig))
        {
            result.error = "Perl interpreter not found";
            return result;
        }
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, perlConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, perlConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, perlConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, perlConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputs ~= buildPath(config.options.outputDir, name);
        }
        
        return outputs;
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
    
    /// Parse Perl configuration from target
    private PerlConfig parsePerlConfig(const Target target)
    {
        PerlConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("perl" in target.langConfig)
            configKey = "perl";
        else if ("perlConfig" in target.langConfig)
            configKey = "perlConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = PerlConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse Perl config, using defaults: " ~ e.msg);
            }
        }
        
        return config;
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
    
    /// Check syntax of Perl files
    private bool checkSyntax(const string[] sources, const PerlConfig config, ref string[] errors)
    {
        string perlCmd = config.perlVersion.interpreterPath.empty ? "perl" : config.perlVersion.interpreterPath;
        bool allValid = true;
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
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
            
            try
            {
                auto res = execute(cmd);
                if (res.status != 0)
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
    
    /// Lint with Perl::Critic
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
        
        try
        {
            auto res = execute(cmd);
            if (res.status != 0)
            {
                result.error = res.output;
                return result;
            }
        }
        catch (Exception e)
        {
            result.error = e.msg;
            return result;
        }
        
        result.success = true;
        return result;
    }
    
    /// Install dependencies
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
        
        // Install modules
        foreach (mod; config.modules)
        {
            string[] cmd = [pmCmd];
            
            // Add local::lib options
            if (config.cpan.useLocalLib && !config.cpan.localLibDir.empty)
            {
                cmd ~= ["-L", config.cpan.localLibDir];
            }
            
            // Add module with version if specified
            string modSpec = mod.name;
            if (!mod.version_.empty)
                modSpec ~= "@" ~ mod.version_;
            
            cmd ~= modSpec;
            
            Logger.debugLog("Installing: " ~ modSpec);
            
            try
            {
                auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
                if (res.status != 0)
                {
                    Logger.error("Failed to install " ~ modSpec ~ ": " ~ res.output);
                    if (!mod.optional)
                        return false;
                }
            }
            catch (Exception e)
            {
                Logger.error("Failed to install " ~ modSpec ~ ": " ~ e.msg);
                if (!mod.optional)
                    return false;
            }
        }
        
        return true;
    }
    
    /// Run prove tests
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
        
        try
        {
            auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
            if (res.status != 0)
            {
                result.error = "Tests failed:\n" ~ res.output;
                return result;
            }
            
            result.success = true;
            result.outputHash = FastHash.hashStrings(target.sources);
        }
        catch (Exception e)
        {
            result.error = "Failed to run tests: " ~ e.msg;
            return result;
        }
        
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
    
    /// Run Module::Build
    private LanguageBuildResult runModuleBuild(string projectRoot)
    {
        LanguageBuildResult result;
        
        Logger.info("Building with Module::Build (Build.PL)");
        
        // Run Build.PL
        auto configRes = execute(["perl", "Build.PL"], null, Config.none, size_t.max, projectRoot);
        if (configRes.status != 0)
        {
            result.error = "Build.PL failed: " ~ configRes.output;
            return result;
        }
        
        // Run ./Build
        auto buildRes = execute(["./Build"], null, Config.none, size_t.max, projectRoot);
        if (buildRes.status != 0)
        {
            result.error = "Build failed: " ~ buildRes.output;
            return result;
        }
        
        result.success = true;
        return result;
    }
    
    /// Run ExtUtils::MakeMaker
    private LanguageBuildResult runMakeMaker(string projectRoot)
    {
        LanguageBuildResult result;
        
        Logger.info("Building with ExtUtils::MakeMaker (Makefile.PL)");
        
        // Run Makefile.PL
        auto configRes = execute(["perl", "Makefile.PL"], null, Config.none, size_t.max, projectRoot);
        if (configRes.status != 0)
        {
            result.error = "Makefile.PL failed: " ~ configRes.output;
            return result;
        }
        
        // Run make
        auto buildRes = execute(["make"], null, Config.none, size_t.max, projectRoot);
        if (buildRes.status != 0)
        {
            result.error = "make failed: " ~ buildRes.output;
            return result;
        }
        
        result.success = true;
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
    
    /// Generate documentation
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
            
            // Generate HTML
            if (generator == PerlDocGenerator.Pod2HTML || generator == PerlDocGenerator.Both)
            {
                string htmlOutput = buildPath(outputDir, baseName ~ ".html");
                try
                {
                    execute(["pod2html", "--infile=" ~ source, "--outfile=" ~ htmlOutput]);
                }
                catch (Exception e)
                {
                    Logger.warning("Failed to generate HTML docs for " ~ source);
                }
            }
            
            // Generate man pages
            if (generator == PerlDocGenerator.Pod2Man || generator == PerlDocGenerator.Both)
            {
                if (config.documentation.generateMan)
                {
                    string manOutput = buildPath(outputDir, baseName ~ "." ~ config.documentation.manSection.to!string);
                    try
                    {
                        execute(["pod2man", source, manOutput]);
                    }
                    catch (Exception e)
                    {
                        Logger.warning("Failed to generate man page for " ~ source);
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

