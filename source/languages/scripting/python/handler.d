module languages.scripting.python.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import languages.base.base;
import languages.scripting.python.config;
import languages.scripting.python.tools;
import languages.scripting.python.environments;
import languages.scripting.python.packages;
import languages.scripting.python.checker;
import languages.scripting.python.formatter;
import languages.scripting.python.dependencies;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;
import utils.python.pycheck;
import utils.python.pywrap;

/// Python build handler - comprehensive and modular
class PythonHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Python target: " ~ target.name);
        
        // Parse Python configuration
        PyConfig pyConfig = parsePyConfig(target);
        
        // Detect and enhance configuration from project structure
        enhanceConfigFromProject(pyConfig, target, config);
        
        // Setup Python environment
        string pythonCmd = setupPythonEnvironment(pyConfig, config.root);
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, pyConfig, pythonCmd);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, pyConfig, pythonCmd);
                break;
            case TargetType.Test:
                result = runTests(target, config, pyConfig, pythonCmd);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, pyConfig, pythonCmd);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(Target target, WorkspaceConfig config)
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
        Target target,
        WorkspaceConfig config,
        PyConfig pyConfig,
        string pythonCmd
    )
    {
        LanguageBuildResult result;
        
        // Install dependencies if requested
        if (pyConfig.installDeps)
        {
            if (!installDependencies(pyConfig, config.root, pythonCmd))
            {
                result.error = "Failed to install dependencies";
                return result;
            }
        }
        
        // Auto-format if configured
        if (pyConfig.autoFormat && pyConfig.formatter != PyFormatter.None)
        {
            Logger.info("Auto-formatting code");
            auto fmtResult = Formatter.format(target.sources, pyConfig.formatter, pythonCmd, false);
            if (!fmtResult.success)
            {
                Logger.warning("Formatting failed, continuing anyway");
            }
        }
        
        // Auto-lint if configured
        if (pyConfig.autoLint && pyConfig.linter != PyLinter.None)
        {
            Logger.info("Auto-linting code");
            auto lintResult = Linter.lint(target.sources, pyConfig.linter, pythonCmd);
            if (lintResult.hasIssues())
            {
                Logger.warning("Linting found issues:");
                foreach (warning; lintResult.warnings)
                {
                    Logger.warning("  " ~ warning);
                }
            }
        }
        
        // Type check if configured
        if (pyConfig.typeCheck.enabled)
        {
            Logger.info("Running type checking");
            auto typeResult = TypeChecker.check(target.sources, pyConfig.typeCheck, pythonCmd);
            
            if (typeResult.hasErrors)
            {
                result.error = "Type checking failed:\n" ~ typeResult.errors.join("\n");
                return result;
            }
            
            if (typeResult.hasWarnings)
            {
                Logger.warning("Type checking warnings:");
                foreach (warning; typeResult.warnings)
                {
                    Logger.warning("  " ~ warning);
                }
            }
        }
        
        // Validate Python syntax using AST parser (fast batch validation)
        auto validationResult = PyValidator.validate(target.sources);
        
        if (!validationResult.success)
        {
            result.error = validationResult.firstError();
            return result;
        }
        
        // Create smart executable wrapper
        auto outputs = getOutputs(target, config);
        if (!outputs.empty && !target.sources.empty)
        {
            auto outputPath = outputs[0];
            auto mainFile = target.sources[0];
            
            // Get entry point metadata from validation
            auto mainFileResult = validationResult.files[0];
            
            WrapperConfig wrapperConfig;
            wrapperConfig.mainFile = mainFile;
            wrapperConfig.outputPath = outputPath;
            wrapperConfig.projectRoot = config.root.empty ? "." : config.root;
            wrapperConfig.hasMain = mainFileResult.hasMain;
            wrapperConfig.hasMainGuard = mainFileResult.hasMainGuard;
            wrapperConfig.isExecutable = mainFileResult.isExecutable;
            
            PyWrapperGenerator.generate(wrapperConfig);
        }
        
        // Compile bytecode if configured
        if (pyConfig.compileBytecode)
        {
            compileToBytecode(target.sources, pythonCmd);
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        Target target,
        WorkspaceConfig config,
        PyConfig pyConfig,
        string pythonCmd
    )
    {
        LanguageBuildResult result;
        
        // Install dependencies if requested
        if (pyConfig.installDeps)
        {
            if (!installDependencies(pyConfig, config.root, pythonCmd))
            {
                result.error = "Failed to install dependencies";
                return result;
            }
        }
        
        // Type check if configured
        if (pyConfig.typeCheck.enabled)
        {
            Logger.info("Running type checking");
            auto typeResult = TypeChecker.check(target.sources, pyConfig.typeCheck, pythonCmd);
            
            if (typeResult.hasErrors)
            {
                result.error = "Type checking failed:\n" ~ typeResult.errors.join("\n");
                return result;
            }
        }
        
        // Validate Python syntax
        auto validationResult = PyValidator.validate(target.sources);
        
        if (!validationResult.success)
        {
            result.error = validationResult.firstError();
            return result;
        }
        
        // Generate stubs if configured
        if (pyConfig.generateStubs)
        {
            generateStubs(target.sources, pythonCmd);
        }
        
        result.success = true;
        result.outputs = target.sources;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult runTests(
        Target target,
        WorkspaceConfig config,
        PyConfig pyConfig,
        string pythonCmd
    )
    {
        LanguageBuildResult result;
        
        // Determine test runner
        auto runner = pyConfig.test.runner;
        if (runner == PyTestRunner.Auto)
        {
            runner = detectTestRunner(target, pythonCmd);
        }
        
        // Run tests based on runner
        final switch (runner)
        {
            case PyTestRunner.Auto:
                // Fallback to pytest
                runner = PyTestRunner.Pytest;
                goto case PyTestRunner.Pytest;
                
            case PyTestRunner.Pytest:
                if (!PyTools.isPytestAvailable(pythonCmd))
                {
                    result.error = "pytest not available (install: pip install pytest)";
                    return result;
                }
                
                result = runPytest(target, pyConfig, pythonCmd);
                break;
                
            case PyTestRunner.Unittest:
                result = runUnittest(target, pyConfig, pythonCmd);
                break;
                
            case PyTestRunner.Nose2:
                result = runNose2(target, pyConfig, pythonCmd);
                break;
                
            case PyTestRunner.Tox:
                result = runTox(target, pyConfig);
                break;
                
            case PyTestRunner.None:
                result.success = true;
                break;
        }
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(
        Target target,
        WorkspaceConfig config,
        PyConfig pyConfig,
        string pythonCmd
    )
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Parse Python configuration from target
    private PyConfig parsePyConfig(Target target)
    {
        PyConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("python" in target.langConfig)
            configKey = "python";
        else if ("pyConfig" in target.langConfig)
            configKey = "pyConfig";
        
        if (!configKey.empty)
        {
            try
            {
                import std.json : parseJSON;
                auto json = parseJSON(target.langConfig[configKey]);
                config = PyConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse Python config, using defaults: " ~ e.msg);
            }
        }
        
        return config;
    }
    
    /// Enhance configuration based on project structure
    private void enhanceConfigFromProject(
        ref PyConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        if (target.sources.empty)
            return;
        
        string sourceDir = dirName(target.sources[0]);
        
        // Auto-detect package manager if set to auto
        if (config.packageManager == PyPackageManager.Auto)
        {
            config.packageManager = PackageManagerFactory.detectFromProject(sourceDir);
            Logger.debug_("Detected package manager: " ~ config.packageManager.to!string);
        }
        
        // Auto-detect virtual environment tool
        if (config.venv.enabled && config.venv.tool == VirtualEnvConfig.Tool.Auto)
        {
            config.venv.tool = VirtualEnv.detectProjectType(sourceDir);
        }
        
        // Find dependency files if not specified
        if (config.requirementsFiles.empty)
        {
            auto depFiles = DependencyAnalyzer.findDependencyFiles(sourceDir);
            if (!depFiles.empty)
            {
                Logger.debug_("Found dependency files: " ~ depFiles.join(", "));
                config.requirementsFiles = depFiles;
            }
        }
    }
    
    /// Setup Python environment and return Python command to use
    private string setupPythonEnvironment(PyConfig config, string projectRoot)
    {
        string pythonCmd = "python3";
        
        // Use specific interpreter if configured
        if (!config.pythonVersion.interpreterPath.empty)
        {
            pythonCmd = config.pythonVersion.interpreterPath;
        }
        
        // Setup virtual environment if enabled
        if (config.venv.enabled)
        {
            string venvPath = VirtualEnv.ensureVenv(config.venv, projectRoot, pythonCmd);
            
            if (!venvPath.empty)
            {
                // Use Python from venv
                pythonCmd = VirtualEnv.getVenvPython(venvPath);
                Logger.info("Using virtual environment: " ~ venvPath);
            }
        }
        
        // Verify Python is available
        if (!PyTools.isPythonCommandAvailable(pythonCmd))
        {
            Logger.warning("Python not available at: " ~ pythonCmd ~ ", falling back to python3");
            pythonCmd = "python3";
        }
        
        Logger.debug_("Using Python: " ~ pythonCmd ~ " (" ~ PyTools.getPythonVersion(pythonCmd) ~ ")");
        
        return pythonCmd;
    }
    
    /// Install dependencies using configured package manager
    private bool installDependencies(PyConfig config, string projectRoot, string pythonCmd)
    {
        // Get venv path for package manager
        string venvPath = "";
        if (config.venv.enabled && !config.venv.path.empty)
        {
            venvPath = config.venv.path;
            if (!venvPath.isAbsolute)
                venvPath = buildPath(projectRoot, venvPath);
        }
        
        // Create package manager
        auto pm = PackageManagerFactory.create(config.packageManager, pythonCmd, venvPath);
        
        if (!pm.isAvailable())
        {
            Logger.error("Package manager not available: " ~ pm.name());
            return false;
        }
        
        Logger.info("Using package manager: " ~ pm.name() ~ " (" ~ pm.getVersion() ~ ")");
        
        // Install from dependency files
        if (!config.requirementsFiles.empty)
        {
            foreach (depFile; config.requirementsFiles)
            {
                auto result = pm.installFromFile(depFile, false, config.editableInstall);
                if (!result.success)
                {
                    Logger.error("Failed to install from " ~ depFile ~ ": " ~ result.error);
                    return false;
                }
            }
        }
        else
        {
            // Install from default location (works for poetry, pdm, hatch)
            auto result = pm.installPackages([], false, config.editableInstall);
            if (!result.success)
            {
                Logger.error("Failed to install dependencies: " ~ result.error);
                return false;
            }
        }
        
        return true;
    }
    
    /// Compile Python sources to bytecode
    private void compileToBytecode(string[] sources, string pythonCmd)
    {
        Logger.info("Compiling to bytecode");
        
        foreach (source; sources)
        {
            auto cmd = [pythonCmd, "-m", "py_compile", source];
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                Logger.warning("Failed to compile " ~ source ~ " to bytecode");
            }
        }
    }
    
    /// Generate stub files (.pyi)
    private void generateStubs(string[] sources, string pythonCmd)
    {
        Logger.info("Generating stub files");
        
        // Use stubgen if available
        auto cmd = [pythonCmd, "-m", "mypy.stubgen"] ~ sources;
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            Logger.warning("Failed to generate stubs (install mypy for stub generation)");
        }
    }
    
    /// Detect test runner from project
    private PyTestRunner detectTestRunner(Target target, string pythonCmd)
    {
        // Check for pytest
        if (PyTools.isPytestAvailable(pythonCmd))
            return PyTestRunner.Pytest;
        
        // Default to unittest (standard library)
        return PyTestRunner.Unittest;
    }
    
    /// Run tests with pytest
    private LanguageBuildResult runPytest(Target target, PyConfig config, string pythonCmd)
    {
        LanguageBuildResult result;
        
        string[] cmd = [pythonCmd, "-m", "pytest"];
        
        if (config.test.verbose)
            cmd ~= "-v";
        
        if (config.test.coverage)
        {
            cmd ~= "--cov";
            if (!config.test.coverageFile.empty)
                cmd ~= ["--cov-report", config.test.coverageFormat];
        }
        
        if (config.test.parallel)
        {
            cmd ~= "-n";
            if (config.test.workers > 0)
                cmd ~= config.test.workers.to!string;
            else
                cmd ~= "auto";
        }
        
        // Add test paths
        if (!config.test.testPaths.empty)
            cmd ~= config.test.testPaths;
        else if (!target.sources.empty)
            cmd ~= target.sources;
        
        Logger.info("Running pytest: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Run tests with unittest
    private LanguageBuildResult runUnittest(Target target, PyConfig config, string pythonCmd)
    {
        LanguageBuildResult result;
        
        string[] cmd = [pythonCmd, "-m", "unittest"];
        
        if (config.test.verbose)
            cmd ~= "-v";
        
        if (!target.sources.empty)
            cmd ~= target.sources;
        else
            cmd ~= "discover";
        
        Logger.info("Running unittest: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Run tests with nose2
    private LanguageBuildResult runNose2(Target target, PyConfig config, string pythonCmd)
    {
        LanguageBuildResult result;
        
        string[] cmd = [pythonCmd, "-m", "nose2"];
        
        if (config.test.verbose)
            cmd ~= "-v";
        
        Logger.info("Running nose2: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Run tests with tox
    private LanguageBuildResult runTox(Target target, PyConfig config)
    {
        LanguageBuildResult result;
        
        string[] cmd = ["tox"];
        
        Logger.info("Running tox: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    override Import[] analyzeImports(string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.Python);
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

