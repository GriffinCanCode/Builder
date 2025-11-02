/**
 * Build System Adapters
 * 
 * Concrete implementations for Builder, Buck2, Bazel, and Pants
 */

module tests.bench.comparative.adapters;

import tests.bench.comparative.architecture;
import std.stdio;
import std.file;
import std.path;
import std.process;
import std.datetime.stopwatch;
import std.datetime : Duration, msecs;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.string;
import std.random;

/// Builder adapter - our own system
class BuilderAdapter : IBuildSystemAdapter
{
    private string binaryPath;
    
    this(string binaryPath = "./bin/builder")
    {
        this.binaryPath = binaryPath;
    }
    
    override @property BuildSystem system() const { return BuildSystem.Builder; }
    
    override Result!bool isInstalled()
    {
        if (!exists(binaryPath))
            return Result!bool("Builder binary not found at: " ~ binaryPath);
        return Result!bool(true);
    }
    
    override Result!string getVersion()
    {
        auto result = execute([binaryPath, "version"]);
        if (result.status != 0)
            return Result!string("Failed to get version");
        return Result!string(result.output.strip);
    }
    
    override Result!void generateProject(in ProjectConfig config, string outputDir)
    {
        import tests.bench.target_generator;
        
        try
        {
            // Use existing target generator
            auto genConfig = GeneratorConfig();
            genConfig.targetCount = config.targetCount;
            genConfig.projectType = ProjectType.Monorepo;
            genConfig.avgDepsPerTarget = config.avgDependenciesPerTarget;
            genConfig.libToExecRatio = config.libToExecRatio;
            genConfig.generateSources = config.generateRealSources;
            genConfig.outputDir = outputDir;
            
            auto generator = new TargetGenerator(genConfig);
            auto targets = generator.generate();
            
            writeln(format("[Builder] Generated %d targets", targets.length));
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Failed to generate project: " ~ e.msg);
        }
    }
    
    override Result!void clean(string projectDir)
    {
        try
        {
            auto cacheDir = buildPath(projectDir, ".builder-cache");
            if (exists(cacheDir))
                rmdirRecurse(cacheDir);
            
            auto binDir = buildPath(projectDir, "bin");
            if (exists(binDir))
                rmdirRecurse(binDir);
            
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Clean failed: " ~ e.msg);
        }
    }
    
    override Result!BuildMetrics build(string projectDir, bool incremental)
    {
        try
        {
            import core.memory : GC;
            
            if (!incremental)
            {
                auto cleanResult = clean(projectDir);
                if (cleanResult.isErr)
                    return Result!BuildMetrics(cleanResult.error);
            }
            
            auto memBefore = GC.stats().usedSize;
            auto sw = StopWatch(AutoStart.yes);
            
            auto result = execute([binaryPath, "build"], null, Config.none, size_t.max, projectDir);
            
            sw.stop();
            auto memAfter = GC.stats().usedSize;
            
            BuildMetrics metrics;
            metrics.totalTime = sw.peek();
            metrics.success = result.status == 0;
            metrics.memoryUsedMB = (memAfter - memBefore) / (1024 * 1024);
            metrics.peakMemoryMB = GC.stats().usedSize / (1024 * 1024);
            
            if (!metrics.success)
                metrics.errorMessage = result.output;
            
            // Parse output for detailed metrics
            parseBuilderOutput(result.output, metrics);
            
            return Result!BuildMetrics(metrics);
        }
        catch (Exception e)
        {
            BuildMetrics metrics;
            metrics.success = false;
            metrics.errorMessage = e.msg;
            return Result!BuildMetrics(metrics);
        }
    }
    
    override Result!void modifyFiles(string projectDir, double changePercent)
    {
        try
        {
            // Find source files and modify a percentage
            auto sourceFiles = dirEntries(projectDir, SpanMode.depth)
                .filter!(f => f.isFile && (f.name.endsWith(".ts") || f.name.endsWith(".py") || f.name.endsWith(".rs")))
                .array;
            
            auto numToChange = cast(size_t)(sourceFiles.length * changePercent);
            
            foreach (i; 0 .. numToChange)
            {
                if (i >= sourceFiles.length) break;
                
                auto file = sourceFiles[i];
                auto content = readText(file.name);
                content ~= format("\n// Modified at %s\n", Clock.currTime());
                std.file.write(file.name, content);
            }
            
            writeln(format("[Builder] Modified %d / %d files", numToChange, sourceFiles.length));
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Modify failed: " ~ e.msg);
        }
    }
    
    override size_t optimalParallelism() const
    {
        import std.parallelism : totalCPUs;
        return totalCPUs;
    }
    
    private void parseBuilderOutput(string output, ref BuildMetrics metrics)
    {
        // Parse Builder output for cache hits, targets built, etc.
        foreach (line; output.lineSplitter)
        {
            if (line.canFind("targets"))
            {
                auto parts = line.split();
                if (parts.length > 0)
                    metrics.targetsBuilt = to!size_t(parts[0]);
            }
            else if (line.canFind("Cache"))
            {
                // Parse cache statistics
            }
        }
    }
}

/// Buck2 adapter
class Buck2Adapter : IBuildSystemAdapter
{
    private string binaryPath;
    
    this(string binaryPath = "buck2")
    {
        this.binaryPath = binaryPath;
    }
    
    override @property BuildSystem system() const { return BuildSystem.Buck2; }
    
    override Result!bool isInstalled()
    {
        auto result = execute([binaryPath, "--version"]);
        if (result.status != 0)
            return Result!bool("Buck2 not installed. Install with: brew install buck2");
        return Result!bool(true);
    }
    
    override Result!string getVersion()
    {
        auto result = execute([binaryPath, "--version"]);
        if (result.status != 0)
            return Result!string("Failed to get version");
        return Result!string(result.output.strip);
    }
    
    override Result!void generateProject(in ProjectConfig config, string outputDir)
    {
        try
        {
            mkdirRecurse(outputDir);
            
            // Generate .buckconfig
            auto buckconfig = File(buildPath(outputDir, ".buckconfig"), "w");
            buckconfig.writeln("[buildfile]");
            buckconfig.writeln("name = BUCK");
            buckconfig.writeln();
            buckconfig.writeln("[repositories]");
            buckconfig.writeln("root = .");
            buckconfig.close();
            
            // Generate BUCK files
            generateBuckTargets(config, outputDir);
            
            writeln(format("[Buck2] Generated %d targets", config.targetCount));
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Failed to generate Buck2 project: " ~ e.msg);
        }
    }
    
    override Result!void clean(string projectDir)
    {
        try
        {
            auto result = execute([binaryPath, "clean"], null, Config.none, size_t.max, projectDir);
            if (result.status != 0)
                return Result!void("Buck2 clean failed: " ~ result.output);
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Clean failed: " ~ e.msg);
        }
    }
    
    override Result!BuildMetrics build(string projectDir, bool incremental)
    {
        try
        {
            if (!incremental)
            {
                auto cleanResult = clean(projectDir);
                if (cleanResult.isErr)
                    return Result!BuildMetrics(cleanResult.error);
            }
            
            auto sw = StopWatch(AutoStart.yes);
            auto result = execute([binaryPath, "build", "//..."], null, Config.none, size_t.max, projectDir);
            sw.stop();
            
            BuildMetrics metrics;
            metrics.totalTime = sw.peek();
            metrics.success = result.status == 0;
            
            if (!metrics.success)
                metrics.errorMessage = result.output;
            
            parseBuck2Output(result.output, metrics);
            
            return Result!BuildMetrics(metrics);
        }
        catch (Exception e)
        {
            BuildMetrics metrics;
            metrics.success = false;
            metrics.errorMessage = e.msg;
            return Result!BuildMetrics(metrics);
        }
    }
    
    override Result!void modifyFiles(string projectDir, double changePercent)
    {
        // Similar to Builder adapter
        try
        {
            auto sourceFiles = dirEntries(projectDir, SpanMode.depth)
                .filter!(f => f.isFile && (f.name.endsWith(".py") || f.name.endsWith(".cpp")))
                .array;
            
            auto numToChange = cast(size_t)(sourceFiles.length * changePercent);
            
            foreach (i; 0 .. numToChange)
            {
                if (i >= sourceFiles.length) break;
                
                auto file = sourceFiles[i];
                auto content = readText(file.name);
                content ~= format("\n# Modified at %s\n", Clock.currTime());
                std.file.write(file.name, content);
            }
            
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Modify failed: " ~ e.msg);
        }
    }
    
    override size_t optimalParallelism() const
    {
        import std.parallelism : totalCPUs;
        return totalCPUs;
    }
    
    private void generateBuckTargets(in ProjectConfig config, string outputDir)
    {
        // Generate simple Python targets for Buck2
        auto buckFile = File(buildPath(outputDir, "BUCK"), "w");
        
        foreach (i; 0 .. config.targetCount)
        {
            auto targetName = format("target_%05d", i);
            auto sourceFile = format("src/%s.py", targetName);
            
            // Create source file
            auto srcDir = buildPath(outputDir, "src");
            mkdirRecurse(srcDir);
            auto src = File(buildPath(srcDir, targetName ~ ".py"), "w");
            src.writeln("# Auto-generated target");
            src.writeln("def main():");
            src.writeln("    print('Hello from " ~ targetName ~ "')");
            src.close();
            
            // Write Buck rule
            buckFile.writeln(format("python_library("));
            buckFile.writeln(format("    name = '%s',", targetName));
            buckFile.writeln(format("    srcs = ['%s'],", sourceFile));
            
            // Add some dependencies
            if (i > 0)
            {
                buckFile.writeln("    deps = [");
                auto numDeps = min(3, i);
                foreach (d; 0 .. numDeps)
                {
                    auto depIdx = uniform(0, i);
                    buckFile.writeln(format("        ':target_%05d',", depIdx));
                }
                buckFile.writeln("    ],");
            }
            
            buckFile.writeln(")");
            buckFile.writeln();
        }
        
        buckFile.close();
    }
    
    private void parseBuck2Output(string output, ref BuildMetrics metrics)
    {
        // Parse Buck2 output for metrics
        foreach (line; output.lineSplitter)
        {
            if (line.canFind("OK"))
                metrics.targetsBuilt++;
        }
    }
}

/// Bazel adapter
class BazelAdapter : IBuildSystemAdapter
{
    private string binaryPath;
    
    this(string binaryPath = "bazel")
    {
        this.binaryPath = binaryPath;
    }
    
    override @property BuildSystem system() const { return BuildSystem.Bazel; }
    
    override Result!bool isInstalled()
    {
        auto result = execute([binaryPath, "version"]);
        if (result.status != 0)
            return Result!bool("Bazel not installed. Install with: brew install bazel");
        return Result!bool(true);
    }
    
    override Result!string getVersion()
    {
        auto result = execute([binaryPath, "version"]);
        if (result.status != 0)
            return Result!string("Failed to get version");
        return Result!string(result.output.strip);
    }
    
    override Result!void generateProject(in ProjectConfig config, string outputDir)
    {
        try
        {
            mkdirRecurse(outputDir);
            
            // Generate WORKSPACE file
            auto workspace = File(buildPath(outputDir, "WORKSPACE"), "w");
            workspace.writeln("# Bazel workspace");
            workspace.close();
            
            // Generate BUILD files
            generateBazelTargets(config, outputDir);
            
            writeln(format("[Bazel] Generated %d targets", config.targetCount));
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Failed to generate Bazel project: " ~ e.msg);
        }
    }
    
    override Result!void clean(string projectDir)
    {
        try
        {
            auto result = execute([binaryPath, "clean"], null, Config.none, size_t.max, projectDir);
            if (result.status != 0)
                return Result!void("Bazel clean failed: " ~ result.output);
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Clean failed: " ~ e.msg);
        }
    }
    
    override Result!BuildMetrics build(string projectDir, bool incremental)
    {
        try
        {
            if (!incremental)
            {
                auto cleanResult = clean(projectDir);
                if (cleanResult.isErr)
                    return Result!BuildMetrics(cleanResult.error);
            }
            
            auto sw = StopWatch(AutoStart.yes);
            auto result = execute([binaryPath, "build", "//..."], null, Config.none, size_t.max, projectDir);
            sw.stop();
            
            BuildMetrics metrics;
            metrics.totalTime = sw.peek();
            metrics.success = result.status == 0;
            
            if (!metrics.success)
                metrics.errorMessage = result.output;
            
            parseBazelOutput(result.output, metrics);
            
            return Result!BuildMetrics(metrics);
        }
        catch (Exception e)
        {
            BuildMetrics metrics;
            metrics.success = false;
            metrics.errorMessage = e.msg;
            return Result!BuildMetrics(metrics);
        }
    }
    
    override Result!void modifyFiles(string projectDir, double changePercent)
    {
        // Similar to other adapters
        try
        {
            auto sourceFiles = dirEntries(projectDir, SpanMode.depth)
                .filter!(f => f.isFile && f.name.endsWith(".py"))
                .array;
            
            auto numToChange = cast(size_t)(sourceFiles.length * changePercent);
            
            foreach (i; 0 .. numToChange)
            {
                if (i >= sourceFiles.length) break;
                
                auto file = sourceFiles[i];
                auto content = readText(file.name);
                content ~= format("\n# Modified at %s\n", Clock.currTime());
                std.file.write(file.name, content);
            }
            
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Modify failed: " ~ e.msg);
        }
    }
    
    override size_t optimalParallelism() const
    {
        import std.parallelism : totalCPUs;
        return totalCPUs;
    }
    
    private void generateBazelTargets(in ProjectConfig config, string outputDir)
    {
        // Generate Python targets for Bazel
        auto buildFile = File(buildPath(outputDir, "BUILD"), "w");
        
        foreach (i; 0 .. config.targetCount)
        {
            auto targetName = format("target_%05d", i);
            auto sourceFile = format("%s.py", targetName);
            
            // Create source file
            auto src = File(buildPath(outputDir, sourceFile), "w");
            src.writeln("# Auto-generated target");
            src.writeln("def main():");
            src.writeln("    print('Hello from " ~ targetName ~ "')");
            src.close();
            
            // Write Bazel rule
            buildFile.writeln(format("py_library("));
            buildFile.writeln(format("    name = '%s',", targetName));
            buildFile.writeln(format("    srcs = ['%s'],", sourceFile));
            
            // Add dependencies
            if (i > 0)
            {
                buildFile.writeln("    deps = [");
                auto numDeps = min(3, i);
                foreach (d; 0 .. numDeps)
                {
                    auto depIdx = uniform(0, i);
                    buildFile.writeln(format("        ':target_%05d',", depIdx));
                }
                buildFile.writeln("    ],");
            }
            
            buildFile.writeln(")");
            buildFile.writeln();
        }
        
        buildFile.close();
    }
    
    private void parseBazelOutput(string output, ref BuildMetrics metrics)
    {
        // Parse Bazel output
        foreach (line; output.lineSplitter)
        {
            if (line.canFind("INFO: Build completed successfully"))
                metrics.success = true;
        }
    }
}

/// Pants adapter
class PantsAdapter : IBuildSystemAdapter
{
    private string binaryPath;
    
    this(string binaryPath = "pants")
    {
        this.binaryPath = binaryPath;
    }
    
    override @property BuildSystem system() const { return BuildSystem.Pants; }
    
    override Result!bool isInstalled()
    {
        auto result = execute([binaryPath, "--version"]);
        if (result.status != 0)
            return Result!bool("Pants not installed. Install with: pip install pantsbuild.pants");
        return Result!bool(true);
    }
    
    override Result!string getVersion()
    {
        auto result = execute([binaryPath, "--version"]);
        if (result.status != 0)
            return Result!string("Failed to get version");
        return Result!string(result.output.strip);
    }
    
    override Result!void generateProject(in ProjectConfig config, string outputDir)
    {
        try
        {
            mkdirRecurse(outputDir);
            
            // Generate pants.toml
            auto pantsConfig = File(buildPath(outputDir, "pants.toml"), "w");
            pantsConfig.writeln("[GLOBAL]");
            pantsConfig.writeln("backend_packages = ['pants.backend.python']");
            pantsConfig.close();
            
            // Generate BUILD files
            generatePantsTargets(config, outputDir);
            
            writeln(format("[Pants] Generated %d targets", config.targetCount));
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Failed to generate Pants project: " ~ e.msg);
        }
    }
    
    override Result!void clean(string projectDir)
    {
        try
        {
            // Pants doesn't have explicit clean, remove cache
            auto cacheDir = buildPath(projectDir, ".pants.d");
            if (exists(cacheDir))
                rmdirRecurse(cacheDir);
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Clean failed: " ~ e.msg);
        }
    }
    
    override Result!BuildMetrics build(string projectDir, bool incremental)
    {
        try
        {
            if (!incremental)
            {
                auto cleanResult = clean(projectDir);
                if (cleanResult.isErr)
                    return Result!BuildMetrics(cleanResult.error);
            }
            
            auto sw = StopWatch(AutoStart.yes);
            auto result = execute([binaryPath, "package", "::"], null, Config.none, size_t.max, projectDir);
            sw.stop();
            
            BuildMetrics metrics;
            metrics.totalTime = sw.peek();
            metrics.success = result.status == 0;
            
            if (!metrics.success)
                metrics.errorMessage = result.output;
            
            parsePantsOutput(result.output, metrics);
            
            return Result!BuildMetrics(metrics);
        }
        catch (Exception e)
        {
            BuildMetrics metrics;
            metrics.success = false;
            metrics.errorMessage = e.msg;
            return Result!BuildMetrics(metrics);
        }
    }
    
    override Result!void modifyFiles(string projectDir, double changePercent)
    {
        try
        {
            auto sourceFiles = dirEntries(projectDir, SpanMode.depth)
                .filter!(f => f.isFile && f.name.endsWith(".py"))
                .array;
            
            auto numToChange = cast(size_t)(sourceFiles.length * changePercent);
            
            foreach (i; 0 .. numToChange)
            {
                if (i >= sourceFiles.length) break;
                
                auto file = sourceFiles[i];
                auto content = readText(file.name);
                content ~= format("\n# Modified at %s\n", Clock.currTime());
                std.file.write(file.name, content);
            }
            
            return Result!void();
        }
        catch (Exception e)
        {
            return Result!void("Modify failed: " ~ e.msg);
        }
    }
    
    override size_t optimalParallelism() const
    {
        import std.parallelism : totalCPUs;
        return totalCPUs;
    }
    
    private void generatePantsTargets(in ProjectConfig config, string outputDir)
    {
        // Generate Python targets for Pants
        auto buildFile = File(buildPath(outputDir, "BUILD"), "w");
        
        foreach (i; 0 .. config.targetCount)
        {
            auto targetName = format("target_%05d", i);
            auto sourceFile = format("%s.py", targetName);
            
            // Create source file
            auto src = File(buildPath(outputDir, sourceFile), "w");
            src.writeln("# Auto-generated target");
            src.writeln("def main():");
            src.writeln("    print('Hello from " ~ targetName ~ "')");
            src.close();
            
            // Write Pants target
            buildFile.writeln(format("python_source("));
            buildFile.writeln(format("    name='%s',", targetName));
            buildFile.writeln(format("    source='%s',", sourceFile));
            buildFile.writeln(")");
            buildFile.writeln();
        }
        
        buildFile.close();
    }
    
    private void parsePantsOutput(string output, ref BuildMetrics metrics)
    {
        // Parse Pants output
        foreach (line; output.lineSplitter)
        {
            if (line.canFind("✓") || line.canFind("success"))
                metrics.targetsBuilt++;
        }
    }
}

/// Factory to create adapters
class AdapterFactory
{
    static IBuildSystemAdapter create(BuildSystem system, string binaryPath = null)
    {
        final switch (system)
        {
            case BuildSystem.Builder:
                return new BuilderAdapter(binaryPath ? binaryPath : "./bin/builder");
            case BuildSystem.Buck2:
                return new Buck2Adapter(binaryPath ? binaryPath : "buck2");
            case BuildSystem.Bazel:
                return new BazelAdapter(binaryPath ? binaryPath : "bazel");
            case BuildSystem.Pants:
                return new PantsAdapter(binaryPath ? binaryPath : "pants");
        }
    }
}

