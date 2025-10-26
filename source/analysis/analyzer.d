module analysis.analyzer;

import std.stdio;
import std.algorithm;
import std.array;
import std.file;
import std.datetime.stopwatch;
import core.graph;
import config.schema;
import analysis.types;
import analysis.spec;
import analysis.metagen;
import analysis.scanner;
import analysis.resolver;
import utils.logger;
import utils.hash;

/// Modern dependency analyzer using compile-time metaprogramming
class DependencyAnalyzer
{
    private WorkspaceConfig config;
    private FileScanner scanner;
    private DependencyResolver resolver;
    
    // Inject compile-time generated analyzer functions
    mixin LanguageAnalyzer;
    
    this(WorkspaceConfig config)
    {
        this.config = config;
        this.scanner = new FileScanner();
        this.resolver = new DependencyResolver(config);
    }
    
    /// Analyze dependencies and build graph
    BuildGraph analyze(string targetFilter = "")
    {
        Logger.info("Analyzing dependencies...");
        auto sw = StopWatch(AutoStart.yes);
        
        auto graph = new BuildGraph();
        
        // Add all targets to graph
        foreach (ref target; config.targets)
        {
            if (targetFilter.empty || matchesFilter(target.name, targetFilter))
            {
                graph.addTarget(target);
            }
        }
        
        // Analyze each target and resolve dependencies
        foreach (ref target; config.targets)
        {
            if (target.name !in graph.nodes)
                continue;
            
            auto analysis = analyzeTarget(target);
            
            if (!analysis.isValid)
            {
                Logger.warning("Analysis errors in " ~ target.name);
                continue;
            }
            
            // Add resolved dependencies to graph
            foreach (dep; analysis.dependencies)
            {
                if (dep.targetName in graph.nodes)
                {
                    try
                    {
                        graph.addDependency(target.name, dep.targetName);
                    }
                    catch (Exception e)
                    {
                        Logger.error("Dependency error: " ~ e.msg);
                        throw e;
                    }
                }
            }
            
            Logger.debug_("  " ~ target.name ~ ": " ~ 
                         analysis.dependencies.length.to!string ~ " dependencies");
        }
        
        sw.stop();
        Logger.success("Analysis complete (" ~ sw.peek().total!"msecs".to!string ~ "ms)");
        
        return graph;
    }
    
    /// Analyze a single target
    TargetAnalysis analyzeTarget(ref Target target)
    {
        auto sw = StopWatch(AutoStart.yes);
        
        TargetAnalysis result;
        result.targetName = target.name;
        
        // Analyze each source file
        foreach (source; target.sources)
        {
            if (!exists(source) || !isFile(source))
            {
                Logger.warning("Source file not found: " ~ source);
                continue;
            }
            
            try
            {
                auto content = readText(source);
                auto hash = FastHash.hashString(content);
                
                // Use compile-time generated analyzer
                auto fileAnalysis = analyzeFile(target.language, source, content);
                fileAnalysis.contentHash = hash;
                
                result.files ~= fileAnalysis;
            }
            catch (Exception e)
            {
                Logger.error("Failed to analyze " ~ source ~ ": " ~ e.msg);
                result.files ~= FileAnalysis(
                    source, [], "", true, [e.msg]
                );
            }
        }
        
        // Collect all imports
        auto allImports = result.allImports();
        
        // Resolve imports to dependencies
        result.dependencies = resolveImports(allImports, target.language);
        
        // Add explicit dependencies
        foreach (dep; target.deps)
        {
            auto resolved = resolver.resolve(dep, target.name);
            if (!resolved.empty && !result.dependencies.canFind!(d => d.targetName == resolved))
            {
                result.dependencies ~= Dependency.direct(resolved, dep);
            }
        }
        
        // Compute metrics
        result.metrics = AnalysisMetrics(
            result.files.length,
            allImports.length,
            result.dependencies.length,
            sw.peek().total!"msecs",
            0
        );
        
        return result;
    }
    
    /// Resolve imports to dependencies (uses compile-time generated code)
    mixin(generateImportResolver());
    
    /// Check if target matches filter pattern
    private bool matchesFilter(string name, string pattern) const pure
    {
        import std.string : indexOf;
        
        if (pattern.empty)
            return true;
        
        // Simple pattern matching
        if (pattern.endsWith("..."))
        {
            auto prefix = pattern[0 .. $ - 3];
            return name.indexOf(prefix) == 0;
        }
        
        return name == pattern;
    }
}

/// Compile-time verification
static assert(is(typeof(DependencyAnalyzer.init.analyzeFile(TargetLanguage.Python, "", ""))),
              "Generated analyzeFile function is invalid");

/// Import for string conversion
import std.conv : to;
