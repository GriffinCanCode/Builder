module languages.compiled.d.builders.direct;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.d.builders.base;
import languages.compiled.d.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Direct compiler invocation builder (dmd/ldc/gdc)
class DirectCompilerBuilder : DBuilder
{
    private DConfig config;
    private string compilerCmd;
    
    this(DConfig config)
    {
        this.config = config;
        this.compilerCmd = getCompilerCommand(config.compiler, config.customCompiler);
    }
    
    DCompileResult build(
        in string[] sources,
        in DConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        DCompileResult result;
        
        // Determine output path
        string outputPath = getOutputPath(config, target, workspace);
        string outputDir = dirName(outputPath);
        
        // Create output directory
        if (!exists(outputDir))
        {
            mkdirRecurse(outputDir);
        }
        
        // Build command based on compiler
        string[] cmd = buildCompilerCommand(sources, outputPath, config);
        
        Logger.debug_("Compiler command: " ~ cmd.join(" "));
        
        // Set environment variables
        string[string] env = environment.toAA();
        foreach (key, value; config.env)
        {
            env[key] = value;
        }
        
        // Execute compilation
        auto res = execute(cmd, env);
        
        if (res.status != 0)
        {
            result.error = "Compilation failed:\n" ~ res.output;
            
            // Try to extract warnings even on failure
            extractWarnings(res.output, result);
            
            return result;
        }
        
        // Extract warnings from output
        extractWarnings(res.output, result);
        
        // Verify output exists
        if (!exists(outputPath))
        {
            result.error = "Expected output file not found: " ~ outputPath;
            return result;
        }
        
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        // Generate documentation if requested
        if (config.compilerConfig.doc)
        {
            generateDocumentation(sources, config, result);
        }
        
        // Generate JSON if requested
        if (config.compilerConfig.json)
        {
            generateJSON(sources, config, result);
        }
        
        result.success = true;
        return result;
    }
    
    bool isAvailable()
    {
        try
        {
            auto res = execute([compilerCmd, "--version"]);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    string name() const
    {
        return compilerCmd;
    }
    
    string getVersion()
    {
        try
        {
            auto res = execute([compilerCmd, "--version"]);
            if (res.status == 0)
            {
                auto lines = res.output.split("\n");
                if (lines.length > 0)
                {
                    return lines[0].strip();
                }
            }
        }
        catch (Exception e)
        {
        }
        return "unknown";
    }
    
    private string getCompilerCommand(DCompiler compiler, string customPath)
    {
        if (compiler == DCompiler.Custom)
            return customPath.empty ? "ldc2" : customPath;
        
        final switch (compiler)
        {
            case DCompiler.Auto:
            case DCompiler.LDC:
                return "ldc2";
            case DCompiler.DMD:
                return "dmd";
            case DCompiler.GDC:
                return "gdc";
            case DCompiler.Custom:
                return customPath;
        }
    }
    
    private string getOutputPath(in DConfig config, in Target target, in WorkspaceConfig workspace)
    {
        if (!target.outputPath.empty)
        {
            return buildPath(workspace.options.outputDir, target.outputPath);
        }
        
        string name = target.name.split(":")[$ - 1];
        if (!config.outputName.empty)
        {
            name = config.outputName;
        }
        
        return buildPath(workspace.options.outputDir, name);
    }
    
    private string[] buildCompilerCommand(in string[] sources, string outputPath, in DConfig config)
    {
        string[] cmd = [compilerCmd];
        
        // Output file
        if (isLDC())
        {
            cmd ~= "-of=" ~ outputPath;
        }
        else if (isDMD())
        {
            cmd ~= "-of" ~ outputPath;
        }
        else if (isGDC())
        {
            cmd ~= "-o" ~ outputPath;
        }
        
        // Output type
        final switch (config.outputType)
        {
            case OutputType.Executable:
                // Default
                break;
            case OutputType.StaticLib:
                if (isLDC() || isDMD())
                    cmd ~= "-lib";
                else if (isGDC())
                    cmd ~= "-c";
                break;
            case OutputType.SharedLib:
                if (isLDC())
                    cmd ~= "-shared";
                else if (isDMD())
                    cmd ~= "-shared";
                else if (isGDC())
                    cmd ~= "-shared";
                break;
            case OutputType.Object:
                cmd ~= "-c";
                break;
        }
        
        // Build configuration flags
        addBuildConfigFlags(cmd, config.buildConfig);
        
        // Optimization
        cmd ~= config.compilerConfig.optimizationFlags;
        
        // Release mode
        if (config.compilerConfig.release)
        {
            cmd ~= "-release";
        }
        
        // Inline
        if (config.compilerConfig.inline)
        {
            cmd ~= "-inline";
        }
        
        // Bounds check
        if (!config.compilerConfig.boundsCheck)
        {
            cmd ~= "-boundscheck=off";
        }
        
        // Debug symbols
        if (config.compilerConfig.debugSymbols)
        {
            cmd ~= "-g";
        }
        
        // Profile
        if (config.compilerConfig.profile)
        {
            cmd ~= "-profile";
        }
        
        // Coverage
        if (config.compilerConfig.coverage || config.test.coverage)
        {
            cmd ~= "-cov";
        }
        
        // Unit tests
        if (config.compilerConfig.unittest_)
        {
            cmd ~= "-unittest";
        }
        
        // BetterC
        if (config.compilerConfig.betterC == BetterCMode.BetterC)
        {
            cmd ~= "-betterC";
        }
        
        // Warnings
        if (config.compilerConfig.warnings)
        {
            cmd ~= "-w";
        }
        if (config.compilerConfig.warningsAsErrors)
        {
            cmd ~= "-de";
        }
        
        // Deprecations
        if (config.compilerConfig.deprecations && !config.compilerConfig.deprecationErrors)
        {
            cmd ~= "-d";
        }
        if (config.compilerConfig.deprecationErrors)
        {
            cmd ~= "-de";
        }
        
        // Info messages
        if (config.compilerConfig.info)
        {
            cmd ~= "-v";
        }
        
        // Verbose
        if (config.compilerConfig.verbose)
        {
            cmd ~= "-v";
        }
        
        // Check only
        if (config.compilerConfig.checkOnly)
        {
            cmd ~= "-o-";
        }
        
        // Color
        if (config.compilerConfig.color)
        {
            cmd ~= "-color=on";
        }
        else
        {
            cmd ~= "-color=off";
        }
        
        // Warning flags
        cmd ~= config.compilerConfig.warningFlags;
        
        // Defines
        foreach (define; config.compilerConfig.defines)
        {
            cmd ~= "-D=" ~ define;
        }
        
        // Version identifiers
        foreach (ver; config.compilerConfig.versions)
        {
            cmd ~= "-version=" ~ ver;
        }
        
        // Debug identifiers
        foreach (dbg; config.compilerConfig.debugs)
        {
            cmd ~= "-debug=" ~ dbg;
        }
        
        // Import paths
        foreach (importPath; config.compilerConfig.importPaths)
        {
            cmd ~= "-I" ~ importPath;
        }
        
        // String import paths
        foreach (stringPath; config.compilerConfig.stringImportPaths)
        {
            cmd ~= "-J" ~ stringPath;
        }
        
        // Library paths
        foreach (libPath; config.compilerConfig.libPaths)
        {
            cmd ~= "-L-L" ~ libPath;
        }
        
        // Libraries
        foreach (lib; config.compilerConfig.libs)
        {
            cmd ~= "-L-l" ~ lib;
        }
        
        // Linker flags
        foreach (flag; config.compilerConfig.linkerFlags)
        {
            cmd ~= "-L" ~ flag;
        }
        
        // Preview features
        foreach (preview; config.compilerConfig.preview)
        {
            cmd ~= "-preview=" ~ preview;
        }
        
        // Revert features
        foreach (revert; config.compilerConfig.revert)
        {
            cmd ~= "-revert=" ~ revert;
        }
        
        // Transition features
        foreach (transition; config.compilerConfig.transition)
        {
            cmd ~= "-transition=" ~ transition;
        }
        
        // DIP features
        if (config.compilerConfig.dip1000)
        {
            cmd ~= "-dip1000";
        }
        if (config.compilerConfig.dip1008)
        {
            cmd ~= "-dip1008";
        }
        if (config.compilerConfig.dip25)
        {
            cmd ~= "-dip25";
        }
        
        // Cross-compilation
        if (!config.compilerConfig.targetTriple.empty && isLDC())
        {
            cmd ~= "-mtriple=" ~ config.compilerConfig.targetTriple;
        }
        
        if (!config.compilerConfig.sysroot.empty && isLDC())
        {
            cmd ~= "-L--sysroot=" ~ config.compilerConfig.sysroot;
        }
        
        // PIC/PIE
        if (config.compilerConfig.pic)
        {
            if (isLDC())
                cmd ~= "-relocation-model=pic";
            else if (isGDC())
                cmd ~= "-fPIC";
        }
        
        // LTO (LDC only)
        if (config.compilerConfig.lto && isLDC())
        {
            cmd ~= "-flto=full";
        }
        
        // Static linking
        if (config.compilerConfig.staticLink)
        {
            cmd ~= "-static";
        }
        
        // Stack stomping (DMD only)
        if (config.compilerConfig.stackStomp && isDMD())
        {
            cmd ~= "-gx";
        }
        
        // Add source files
        cmd ~= sources;
        
        return cmd;
    }
    
    private void addBuildConfigFlags(ref string[] cmd, BuildConfig buildConfig)
    {
        final switch (buildConfig)
        {
            case BuildConfig.Debug:
                cmd ~= "-g";
                break;
            case BuildConfig.Plain:
                // No special flags
                break;
            case BuildConfig.Release:
                cmd ~= "-release";
                cmd ~= "-O";
                break;
            case BuildConfig.ReleaseNoBounds:
                cmd ~= "-release";
                cmd ~= "-O";
                cmd ~= "-boundscheck=off";
                break;
            case BuildConfig.Unittest:
                cmd ~= "-unittest";
                break;
            case BuildConfig.Profile:
                cmd ~= "-profile";
                break;
            case BuildConfig.Cov:
                cmd ~= "-cov";
                break;
            case BuildConfig.UnittestCov:
                cmd ~= "-unittest";
                cmd ~= "-cov";
                break;
            case BuildConfig.SyntaxOnly:
                cmd ~= "-o-";
                break;
        }
    }
    
    private void extractWarnings(string output, ref DCompileResult result)
    {
        foreach (line; output.split("\n"))
        {
            if (line.canFind("Warning:") || line.canFind("warning:") || 
                line.canFind("Deprecation:") || line.canFind("deprecation:"))
            {
                result.hadWarnings = true;
                result.warnings ~= line.strip();
            }
        }
    }
    
    private void generateDocumentation(in string[] sources, in DConfig config, ref DCompileResult result)
    {
        string[] cmd = [compilerCmd];
        cmd ~= "-D";
        cmd ~= "-Dd" ~ config.compilerConfig.docDir;
        
        if (!config.compilerConfig.docFormat.empty)
        {
            cmd ~= "-Df" ~ config.compilerConfig.docFormat;
        }
        
        cmd ~= sources;
        
        auto res = execute(cmd);
        
        if (res.status == 0)
        {
            result.artifacts ~= config.compilerConfig.docDir;
            Logger.info("Documentation generated in " ~ config.compilerConfig.docDir);
        }
        else
        {
            Logger.warning("Documentation generation failed: " ~ res.output);
        }
    }
    
    private void generateJSON(in string[] sources, in DConfig config, ref DCompileResult result)
    {
        string[] cmd = [compilerCmd];
        cmd ~= "-X";
        
        string jsonFile = config.compilerConfig.jsonFile;
        if (jsonFile.empty)
        {
            jsonFile = "output.json";
        }
        
        cmd ~= "-Xf" ~ jsonFile;
        cmd ~= sources;
        
        auto res = execute(cmd);
        
        if (res.status == 0)
        {
            result.artifacts ~= jsonFile;
            Logger.info("JSON description generated: " ~ jsonFile);
        }
        else
        {
            Logger.warning("JSON generation failed: " ~ res.output);
        }
    }
    
    private bool isLDC() const
    {
        return compilerCmd.canFind("ldc");
    }
    
    private bool isDMD() const
    {
        return compilerCmd.canFind("dmd");
    }
    
    private bool isGDC() const
    {
        return compilerCmd.canFind("gdc");
    }
}


