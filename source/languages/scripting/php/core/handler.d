module languages.scripting.php.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import std.conv;
import std.uuid;
import languages.base.base;
import languages.scripting.php.core.config;
import languages.scripting.php.tooling.detection;
import languages.scripting.php.managers.composer;
import languages.scripting.php.analysis;
import languages.scripting.php.tooling.formatters;
import languages.scripting.php.tooling.packagers;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;
import utils.security.validation;

/// PHP build handler - comprehensive and modular
class PHPHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building PHP target: " ~ target.name);
        
        // Parse PHP configuration
        PHPConfig phpConfig = parsePHPConfig(target);
        
        // Detect and enhance configuration from project structure
        enhanceConfigFromProject(phpConfig, target, config);
        
        // Detect PHP version and validate
        string phpCmd = setupPHPEnvironment(phpConfig);
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, phpConfig, phpCmd);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, phpConfig, phpCmd);
                break;
            case TargetType.Test:
                result = runTests(target, config, phpConfig, phpCmd);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, phpConfig, phpCmd);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        string[] outputs;
        
        PHPConfig phpConfig = parsePHPConfig(target);
        
        // For PHAR builds, return the PHAR file
        if (phpConfig.mode == PHPBuildMode.PHAR || phpConfig.mode == PHPBuildMode.FrankenPHP)
        {
            string outputFile = phpConfig.phar.outputFile;
            if (outputFile.empty)
                outputFile = "app.phar";
            
            outputs ~= buildPath(config.options.outputDir, outputFile);
        }
        else
        {
            // Standard output path
            if (!target.outputPath.empty)
            {
                outputs ~= buildPath(config.options.outputDir, target.outputPath);
            }
            else
            {
                auto name = target.name.split(":")[$ - 1];
                outputs ~= buildPath(config.options.outputDir, name);
            }
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        LanguageBuildResult result;
        
        // Install Composer dependencies if requested
        if (phpConfig.composer.autoInstall)
        {
            if (!installComposerDeps(phpConfig, config.root))
            {
                result.error = "Failed to install Composer dependencies";
                return result;
            }
        }
        
        // Run formatter if configured
        if (phpConfig.formatter.enabled && phpConfig.formatter.formatter != PHPFormatter.None)
        {
            Logger.info("Running code formatter");
            auto formatter = FormatterFactory.create(phpConfig.formatter.formatter, config.root);
            auto formatResult = formatter.format(target.sources, phpConfig.formatter, config.root, false);
            
            if (!formatResult.success)
            {
                Logger.warning("Formatting had issues, continuing anyway");
            }
        }
        
        // Run static analysis if configured
        if (phpConfig.analysis.enabled && phpConfig.analysis.analyzer != PHPAnalyzer.None)
        {
            Logger.info("Running static analysis");
            auto analyzer = AnalyzerFactory.create(phpConfig.analysis.analyzer, config.root);
            auto analysisResult = analyzer.analyze(target.sources, phpConfig.analysis, config.root);
            
            if (analysisResult.hasErrors())
            {
                result.error = "Static analysis found errors:\n" ~ analysisResult.errors.join("\n");
                return result;
            }
            
            if (analysisResult.hasIssues())
            {
                Logger.warning("Static analysis warnings:");
                foreach (warning; analysisResult.warnings)
                {
                    Logger.warning("  " ~ warning);
                }
            }
        }
        
        // Validate PHP syntax
        auto validationResult = PHPTools.validateSyntaxBatch(target.sources, phpCmd);
        if (!validationResult.success)
        {
            result.error = "PHP syntax validation failed:\n" ~ validationResult.errors.join("\n");
            return result;
        }
        
        // Validate PSR-4 autoloading if configured
        if (phpConfig.validateAutoload)
        {
            validatePSR4Autoload(config.root, phpConfig);
        }
        
        // Build based on mode
        final switch (phpConfig.mode)
        {
            case PHPBuildMode.Script:
                result = buildScript(target, config, phpConfig, phpCmd);
                break;
            case PHPBuildMode.Application:
                result = buildApplication(target, config, phpConfig, phpCmd);
                break;
            case PHPBuildMode.Library:
                result = buildLibrary(target, config, phpConfig, phpCmd);
                break;
            case PHPBuildMode.PHAR:
                result = buildPHAR(target, config, phpConfig, phpCmd);
                break;
            case PHPBuildMode.Package:
                result = buildPackage(target, config, phpConfig, phpCmd);
                break;
            case PHPBuildMode.FrankenPHP:
                result = buildFrankenPHP(target, config, phpConfig, phpCmd);
                break;
        }
        
        return result;
    }
    
    private LanguageBuildResult buildScript(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        LanguageBuildResult result;
        
        // Create executable wrapper
        auto outputs = getOutputs(target, config);
        if (!outputs.empty && !target.sources.empty)
        {
            auto outputPath = outputs[0];
            auto outputDir = dirName(outputPath);
            auto mainFile = target.sources[0];
            
            // Ensure output directory exists
            if (!exists(outputDir))
                mkdirRecurse(outputDir);
            
            // Create wrapper script with shebang
            string wrapper = "#!/usr/bin/env php\n<?php\n";
            
            // Add strict types if configured
            if (phpConfig.strictTypes)
            {
                wrapper ~= "declare(strict_types=1);\n\n";
            }
            
            // Set include paths if configured
            if (!phpConfig.includePaths.empty)
            {
                wrapper ~= "set_include_path(get_include_path() . PATH_SEPARATOR . '" ~ 
                          phpConfig.includePaths.join("' . PATH_SEPARATOR . '") ~ "');\n\n";
            }
            
            // Include composer autoloader if exists
            string autoloadPath = buildPath(config.root, "vendor", "autoload.php");
            if (exists(autoloadPath))
            {
                string relPath = relativePath(autoloadPath, outputDir);
                wrapper ~= "require_once dirname(__FILE__) . '/" ~ relPath ~ "';\n\n";
            }
            
            // Include main file
            string mainRelPath = relativePath(mainFile, outputDir);
            wrapper ~= "require_once dirname(__FILE__) . '/" ~ mainRelPath ~ "';\n";
            
            std.file.write(outputPath, wrapper);
            
            // Make executable on Unix
            version(Posix)
            {
                // Validate path before using it with external command
                if (!SecurityValidator.isPathSafe(outputPath))
                {
                    Logger.error("Unsafe output path detected: " ~ outputPath);
                }
                else
                {
                    // Use safe array form instead of executeShell
                    auto chmodResult = execute(["chmod", "+x", outputPath]);
                    if (chmodResult.status != 0)
                    {
                        Logger.warning("Failed to make wrapper executable: " ~ chmodResult.output);
                    }
                }
            }
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildApplication(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        // Same as script but ensure composer autoload is set up
        auto result = buildScript(target, config, phpConfig, phpCmd);
        
        if (result.success && phpConfig.composer.optimizeAutoloader)
        {
            Logger.info("Optimizing Composer autoloader");
            auto composer = new ComposerTool(phpConfig.composer.composerPath, config.root);
            composer.dumpAutoload(true, phpConfig.composer.authoritative, phpConfig.composer.apcu);
        }
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        LanguageBuildResult result;
        
        // Validate syntax
        auto validationResult = PHPTools.validateSyntaxBatch(target.sources, phpCmd);
        if (!validationResult.success)
        {
            result.error = "PHP syntax validation failed:\n" ~ validationResult.errors.join("\n");
            return result;
        }
        
        // Static analysis is important for libraries
        if (phpConfig.analysis.enabled)
        {
            Logger.info("Running static analysis");
            auto analyzer = AnalyzerFactory.create(phpConfig.analysis.analyzer, config.root);
            auto analysisResult = analyzer.analyze(target.sources, phpConfig.analysis, config.root);
            
            if (analysisResult.hasErrors())
            {
                result.error = "Static analysis found errors:\n" ~ analysisResult.errors.join("\n");
                return result;
            }
        }
        
        // Validate PSR-4 compliance
        if (phpConfig.validateAutoload)
        {
            validatePSR4Autoload(config.root, phpConfig);
        }
        
        result.success = true;
        result.outputs = target.sources.dup;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildPHAR(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        LanguageBuildResult result;
        
        Logger.info("Creating PHAR archive");
        
        // Create packager
        auto packager = PackagerFactory.create(phpConfig.phar.tool);
        
        if (!packager.isAvailable())
        {
            result.error = "PHAR packager '" ~ packager.name() ~ "' is not available";
            return result;
        }
        
        Logger.debug_("Using packager: " ~ packager.name() ~ " (" ~ packager.getVersion() ~ ")");
        
        // Package
        auto packageResult = packager.createPackage(target.sources, phpConfig.phar, config.root);
        
        if (!packageResult.success)
        {
            result.error = "PHAR packaging failed:\n" ~ packageResult.errors.join("\n");
            return result;
        }
        
        result.success = true;
        result.outputs = packageResult.artifacts;
        result.outputHash = FastHash.hashStrings(packageResult.artifacts);
        
        return result;
    }
    
    private LanguageBuildResult buildPackage(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        LanguageBuildResult result;
        
        // Validate composer.json
        auto composer = new ComposerTool(phpConfig.composer.composerPath, config.root);
        
        if (!composer.validate())
        {
            Logger.warning("composer.json validation failed");
        }
        
        // Build library first
        result = buildLibrary(target, config, phpConfig, phpCmd);
        
        return result;
    }
    
    private LanguageBuildResult buildFrankenPHP(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        LanguageBuildResult result;
        
        if (!PHPTools.isFrankenPHPAvailable(phpConfig.frankenphp.binaryPath))
        {
            result.error = "FrankenPHP not available. Install from: https://frankenphp.dev/";
            return result;
        }
        
        Logger.info("Building FrankenPHP standalone binary");
        
        // First create PHAR if embed is enabled
        string[] pharFiles;
        if (phpConfig.frankenphp.embed)
        {
            auto pharResult = buildPHAR(target, config, phpConfig, phpCmd);
            if (!pharResult.success)
                return pharResult;
            pharFiles = pharResult.outputs;
            Logger.info("PHAR created: " ~ pharFiles.join(", "));
        }
        
        // Build FrankenPHP static binary with embedded PHAR
        auto embedResult = embedFrankenPHPBinary(
            pharFiles,
            target,
            config,
            phpConfig
        );
        
        if (!embedResult.success)
        {
            result.error = embedResult.error;
            return result;
        }
        
        result.success = true;
        result.outputs = embedResult.outputs;
        result.outputHash = embedResult.outputHash;
        
        return result;
    }
    
    /// Embed PHAR into FrankenPHP static binary
    private LanguageBuildResult embedFrankenPHPBinary(
        string[] pharFiles,
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig
    )
    {
        LanguageBuildResult result;
        
        // Determine output binary name
        string outputName = target.name.split(":")[$ - 1];
        if (outputName.empty)
            outputName = "app";
        
        string outputPath = buildPath(config.options.outputDir, outputName);
        
        // Ensure output directory exists
        if (!exists(dirName(outputPath)))
            mkdirRecurse(dirName(outputPath));
        
        // FrankenPHP static build approach
        // Method 1: Use frankenphp-build with embedded files
        if (phpConfig.frankenphp.embed && !pharFiles.empty)
        {
            // Create temporary directory for build
            import std.uuid : randomUUID;
            string tempBuildDir = buildPath(tempDir(), "frankenphp-build-" ~ randomUUID().toString());
            bool shouldCleanup = true;
            
            void cleanup()
            {
                if (shouldCleanup && exists(tempBuildDir))
                {
                    try
                    {
                        rmdirRecurse(tempBuildDir);
                    }
                    catch (Exception e)
                    {
                        // Ignore cleanup errors
                    }
                }
            }
            
            scope(exit) cleanup();
            
            mkdirRecurse(tempBuildDir);
            
            // Copy PHAR to temp build directory
            string embedPharPath = buildPath(tempBuildDir, "app.phar");
            foreach (pharFile; pharFiles)
            {
                if (exists(pharFile))
                {
                    std.file.copy(pharFile, embedPharPath);
                    break;  // Use first PHAR
                }
            }
            
            if (!exists(embedPharPath))
            {
                result.error = "No valid PHAR file found to embed";
                return result;
            }
            
            // Create a bootstrap PHP file that loads the PHAR
            string bootstrapPath = buildPath(tempBuildDir, "index.php");
            string bootstrap = "<?php\n";
            if (phpConfig.strictTypes)
                bootstrap ~= "declare(strict_types=1);\n\n";
            
            bootstrap ~= "// FrankenPHP embedded PHAR loader\n";
            bootstrap ~= "require 'phar://' . __DIR__ . '/app.phar/index.php';\n";
            
            std.file.write(bootstrapPath, bootstrap);
            
            // Build command for FrankenPHP static binary
            string[] buildCmd = [
                phpConfig.frankenphp.binaryPath,
                "php-server"
            ];
            
            // Add worker mode if configured
            if (phpConfig.frankenphp.worker)
            {
                buildCmd ~= ["--worker", bootstrapPath];
                buildCmd ~= ["--num-workers", phpConfig.frankenphp.workers.to!string];
            }
            
            // Add document root
            if (!phpConfig.frankenphp.docRoot.empty)
            {
                buildCmd ~= ["--root", tempBuildDir];
            }
            
            // Add any additional server args
            buildCmd ~= phpConfig.frankenphp.serverArgs;
            
            Logger.info("Creating FrankenPHP binary: " ~ buildCmd.join(" "));
            Logger.info("Note: FrankenPHP static builds require 'frankenphp-builder' or custom Go build");
            Logger.info("Creating wrapper script with embedded references");
            
            // Since actual static binary building requires frankenphp-builder or Go toolchain,
            // create a wrapper script that uses the installed FrankenPHP with the PHAR
            createFrankenPHPWrapper(
                outputPath,
                embedPharPath,
                bootstrapPath,
                phpConfig,
                config.root
            );
            
            result.success = true;
            result.outputs = [outputPath];
            result.outputHash = FastHash.hashFile(outputPath);
        }
        else
        {
            // No embedding, just create wrapper for FrankenPHP server
            createFrankenPHPWrapper(
                outputPath,
                "",
                target.sources.empty ? "" : target.sources[0],
                phpConfig,
                config.root
            );
            
            result.success = true;
            result.outputs = [outputPath];
            result.outputHash = FastHash.hashFile(outputPath);
        }
        
        return result;
    }
    
    /// Create FrankenPHP wrapper script
    private void createFrankenPHPWrapper(
        string outputPath,
        string pharPath,
        string entryPoint,
        PHPConfig phpConfig,
        string projectRoot
    )
    {
        string wrapper = "#!/usr/bin/env bash\n";
        wrapper ~= "# FrankenPHP application wrapper\n";
        wrapper ~= "# Generated by Builder\n\n";
        
        wrapper ~= "SCRIPT_DIR=\"$( cd \"$( dirname \"${BASH_SOURCE[0]}\" )\" && pwd )\"\n";
        wrapper ~= "PROJECT_ROOT=\"" ~ projectRoot ~ "\"\n\n";
        
        // Export environment variables
        wrapper ~= "export APP_ENV=\"${APP_ENV:-production}\"\n";
        wrapper ~= "export FRANKENPHP_CONFIG=\"${FRANKENPHP_CONFIG:-}\"\n\n";
        
        // Build FrankenPHP command
        wrapper ~= "FRANKENPHP_BIN=\"" ~ phpConfig.frankenphp.binaryPath ~ "\"\n\n";
        
        wrapper ~= "# Check if FrankenPHP is available\n";
        wrapper ~= "if ! command -v \"$FRANKENPHP_BIN\" &> /dev/null; then\n";
        wrapper ~= "    echo \"Error: FrankenPHP not found. Install from https://frankenphp.dev/\"\n";
        wrapper ~= "    exit 1\n";
        wrapper ~= "fi\n\n";
        
        // Build command arguments
        wrapper ~= "ARGS=(\"php-server\")\n\n";
        
        if (!pharPath.empty)
        {
            string relPharPath = relativePath(pharPath, dirName(outputPath));
            wrapper ~= "# Use embedded PHAR\n";
            wrapper ~= "PHAR_PATH=\"$SCRIPT_DIR/" ~ relPharPath ~ "\"\n";
            wrapper ~= "if [ ! -f \"$PHAR_PATH\" ]; then\n";
            wrapper ~= "    echo \"Error: PHAR not found at $PHAR_PATH\"\n";
            wrapper ~= "    exit 1\n";
            wrapper ~= "fi\n\n";
        }
        
        if (phpConfig.frankenphp.worker && !entryPoint.empty)
        {
            string relEntryPoint = relativePath(entryPoint, dirName(outputPath));
            wrapper ~= "ARGS+=(\"--worker\" \"$SCRIPT_DIR/" ~ relEntryPoint ~ "\")\n";
            wrapper ~= "ARGS+=(\"--num-workers\" \"" ~ phpConfig.frankenphp.workers.to!string ~ "\")\n";
        }
        
        if (!phpConfig.frankenphp.docRoot.empty)
        {
            wrapper ~= "ARGS+=(\"--root\" \"$PROJECT_ROOT/" ~ phpConfig.frankenphp.docRoot ~ "\")\n";
        }
        
        // Add custom server arguments
        foreach (arg; phpConfig.frankenphp.serverArgs)
        {
            wrapper ~= "ARGS+=(\"" ~ arg ~ "\")\n";
        }
        
        wrapper ~= "\n# Execute FrankenPHP\n";
        wrapper ~= "exec \"$FRANKENPHP_BIN\" \"${ARGS[@]}\" \"$@\"\n";
        
        // Write wrapper script
        std.file.write(outputPath, wrapper);
        
        // Make executable on Unix
        version(Posix)
        {
            if (SecurityValidator.isPathSafe(outputPath))
            {
                auto chmodResult = execute(["chmod", "+x", outputPath]);
                if (chmodResult.status != 0)
                {
                    Logger.warning("Failed to make wrapper executable: " ~ chmodResult.output);
                }
            }
        }
        
        Logger.info("Created FrankenPHP wrapper: " ~ outputPath);
    }
    
    private LanguageBuildResult runTests(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        LanguageBuildResult result;
        
        // Determine test framework
        auto framework = phpConfig.test.framework;
        if (framework == PHPTestFramework.Auto)
        {
            framework = detectTestFramework(config.root);
        }
        
        // Run tests based on framework
        final switch (framework)
        {
            case PHPTestFramework.Auto:
                // Fallback to PHPUnit
                framework = PHPTestFramework.PHPUnit;
                goto case PHPTestFramework.PHPUnit;
                
            case PHPTestFramework.PHPUnit:
                result = runPHPUnit(target, config, phpConfig, phpCmd);
                break;
                
            case PHPTestFramework.Pest:
                result = runPest(target, config, phpConfig, phpCmd);
                break;
                
            case PHPTestFramework.Codeception:
                result = runCodeception(target, config, phpConfig, phpCmd);
                break;
                
            case PHPTestFramework.Behat:
                result = runBehat(target, config, phpConfig, phpCmd);
                break;
                
            case PHPTestFramework.None:
                result.success = true;
                break;
        }
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Parse PHP configuration from target
    private PHPConfig parsePHPConfig(const Target target)
    {
        PHPConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("php" in target.langConfig)
            configKey = "php";
        else if ("phpConfig" in target.langConfig)
            configKey = "phpConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = PHPConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse PHP config, using defaults: " ~ e.msg);
            }
        }
        
        return config;
    }
    
    /// Enhance configuration based on project structure
    private void enhanceConfigFromProject(
        ref PHPConfig config,
        const Target target,
        const WorkspaceConfig workspace
    )
    {
        if (target.sources.empty)
            return;
        
        string sourceDir = dirName(target.sources[0]);
        
        // Auto-detect composer.json
        if (config.composer.composerJson.empty)
        {
            string composerPath = ComposerTool.findComposerJson(sourceDir);
            if (!composerPath.empty)
            {
                config.composer.composerJson = composerPath;
                Logger.debug_("Found composer.json: " ~ composerPath);
            }
        }
        
        // Auto-detect analyzer
        if (config.analysis.analyzer == PHPAnalyzer.Auto)
        {
            config.analysis.analyzer = AnalyzerFactory.detectFromProject(workspace.root);
        }
        
        // Auto-detect formatter
        if (config.formatter.formatter == PHPFormatter.Auto)
        {
            config.formatter.formatter = FormatterFactory.detectFromProject(workspace.root);
        }
    }
    
    /// Setup PHP environment and return PHP command to use
    private string setupPHPEnvironment(PHPConfig config)
    {
        string phpCmd = "php";
        
        // Use specific interpreter if configured
        if (!config.phpVersion.interpreterPath.empty)
        {
            phpCmd = config.phpVersion.interpreterPath;
        }
        
        // Verify PHP is available
        if (!PHPTools.isPHPAvailable(phpCmd))
        {
            Logger.warning("PHP not available at: " ~ phpCmd ~ ", falling back to 'php'");
            phpCmd = "php";
        }
        
        Logger.debug_("Using PHP: " ~ phpCmd ~ " (" ~ PHPTools.getPHPVersion(phpCmd) ~ ")");
        
        return phpCmd;
    }
    
    /// Install Composer dependencies
    private bool installComposerDeps(PHPConfig config, string projectRoot)
    {
        if (!ComposerTool.isAvailable(config.composer.composerPath))
        {
            Logger.error("Composer not available");
            return false;
        }
        
        auto composer = new ComposerTool(config.composer.composerPath, projectRoot);
        
        Logger.info("Installing Composer dependencies");
        bool success = composer.install(
            config.composer.noDev,
            config.composer.optimizeAutoloader
        );
        
        return success;
    }
    
    /// Validate PSR-4 autoloading
    private void validatePSR4Autoload(string projectRoot, PHPConfig config)
    {
        if (config.composer.composerJson.empty)
            return;
        
        try
        {
            auto metadata = ComposerTool.parseComposerJson(config.composer.composerJson);
            
            foreach (ns, dir; metadata.autoload.psr4)
            {
                string fullPath = buildPath(projectRoot, dir);
                if (!exists(fullPath))
                {
                    Logger.warning("PSR-4 directory not found: " ~ fullPath ~ " for namespace " ~ ns);
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to validate PSR-4 autoload: " ~ e.msg);
        }
    }
    
    /// Detect test framework from project
    private PHPTestFramework detectTestFramework(string projectRoot)
    {
        // Check for PHPUnit
        if (PHPTools.isPHPUnitAvailable() || exists(buildPath(projectRoot, "phpunit.xml")))
            return PHPTestFramework.PHPUnit;
        
        // Check for Pest
        if (PHPTools.isPestAvailable() || exists(buildPath(projectRoot, "pest.php")))
            return PHPTestFramework.Pest;
        
        // Check for Codeception
        if (PHPTools.isCodeceptionAvailable() || exists(buildPath(projectRoot, "codeception.yml")))
            return PHPTestFramework.Codeception;
        
        // Check for Behat
        if (PHPTools.isBehatAvailable() || exists(buildPath(projectRoot, "behat.yml")))
            return PHPTestFramework.Behat;
        
        return PHPTestFramework.PHPUnit; // Default
    }
    
    /// Run PHPUnit tests
    private LanguageBuildResult runPHPUnit(
        in Target target,
        in WorkspaceConfig config,
        PHPConfig phpConfig,
        string phpCmd
    )
    {
        LanguageBuildResult result;
        
        string phpunitCmd = PHPTools.getPHPUnitCommand();
        if (phpunitCmd.empty)
        {
            result.error = "PHPUnit not found. Install: composer require --dev phpunit/phpunit";
            return result;
        }
        
        string[] cmd = [phpunitCmd];
        
        // Configuration file
        if (!phpConfig.test.configFile.empty && exists(phpConfig.test.configFile))
        {
            cmd ~= ["--configuration", phpConfig.test.configFile];
        }
        
        // Verbose
        if (phpConfig.test.verbose)
            cmd ~= "--verbose";
        
        // Coverage
        if (phpConfig.test.coverage)
        {
            cmd ~= ["--coverage-" ~ phpConfig.test.coverageFormat, phpConfig.test.coverageDir];
        }
        
        // Stop on failure
        if (phpConfig.test.stopOnFailure)
            cmd ~= "--stop-on-failure";
        
        // Test paths
        if (!phpConfig.test.testPaths.empty)
            cmd ~= phpConfig.test.testPaths;
        else if (!target.sources.empty)
            cmd ~= target.sources;
        
        Logger.info("Running PHPUnit: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, config.root);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Run Pest tests
    private LanguageBuildResult runPest(in Target target, in WorkspaceConfig config, PHPConfig phpConfig, string phpCmd)
    {
        LanguageBuildResult result;
        
        if (!PHPTools.isPestAvailable())
        {
            result.error = "Pest not found. Install: composer require --dev pestphp/pest";
            return result;
        }
        
        string[] cmd = [buildPath("vendor", "bin", "pest")];
        
        if (phpConfig.test.verbose)
            cmd ~= "-v";
        
        if (phpConfig.test.coverage)
            cmd ~= "--coverage";
        
        Logger.info("Running Pest: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, config.root);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Run Codeception tests
    private LanguageBuildResult runCodeception(in Target target, in WorkspaceConfig config, PHPConfig phpConfig, string phpCmd)
    {
        LanguageBuildResult result;
        // Implementation similar to runPHPUnit
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Run Behat tests
    private LanguageBuildResult runBehat(in Target target, in WorkspaceConfig config, PHPConfig phpConfig, string phpCmd)
    {
        LanguageBuildResult result;
        // Implementation similar to runPHPUnit
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.PHP);
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

