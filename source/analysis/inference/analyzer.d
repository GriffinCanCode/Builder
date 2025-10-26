module analysis.inference.analyzer;

import std.stdio;
import std.algorithm;
import std.array;
import std.file;
import std.datetime.stopwatch;
import core.graph.graph;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import analysis.metadata.metagen;
import analysis.scanning.scanner;
import analysis.resolution.resolver;
import utils.logging.logger;
import utils.files.hash;
import errors;

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
            
            auto analysisResult = analyzeTarget(target);
            
            if (analysisResult.isErr)
            {
                auto error = analysisResult.unwrapErr();
                Logger.warning("Analysis failed for " ~ target.name);
                Logger.error(format(error));
                continue;
            }
            
            auto analysis = analysisResult.unwrap();
            
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
                        auto error = new AnalysisError(target.name, e.msg, ErrorCode.MissingDependency);
                        error.addContext(ErrorContext("adding dependency to graph", dep.targetName));
                        Logger.error(format(error));
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
    
    /// Analyze a single target with error aggregation
    /// Returns Result with TargetAnalysis, collecting all file analysis errors
    Result!(TargetAnalysis, BuildError) analyzeTarget(
        ref Target target,
        AggregationPolicy policy = AggregationPolicy.CollectAll)
    {
        auto sw = StopWatch(AutoStart.yes);
        
        TargetAnalysis result;
        result.targetName = target.name;
        
        // Aggregate file analysis results
        auto aggregated = aggregateMap(
            target.sources,
            (string source) {
                // Check file exists
                if (!exists(source) || !isFile(source))
                {
                    auto error = new IOError(source, "Source file not found", ErrorCode.FileNotFound);
                    error.addContext(ErrorContext("analyzing target", target.name));
                    return Err!(FileAnalysis, BuildError)(error);
                }
                
                try
                {
                    auto content = readText(source);
                    auto hash = FastHash.hashString(content);
                    
                    // Use compile-time generated analyzer
                    auto fileAnalysis = analyzeFile(target.language, source, content);
                    fileAnalysis.contentHash = hash;
                    
                    return Ok!(FileAnalysis, BuildError)(fileAnalysis);
                }
                catch (Exception e)
                {
                    auto error = new AnalysisError(target.name, e.msg, ErrorCode.AnalysisFailed);
                    error.addContext(ErrorContext("analyzing file", source));
                    return Err!(FileAnalysis, BuildError)(error);
                }
            },
            policy
        );
        
        // Log analysis results
        if (aggregated.hasErrors)
        {
            Logger.warning(
                "Failed to analyze " ~ aggregated.errors.length.to!string ~
                " source file(s) in " ~ target.name
            );
            
            foreach (error; aggregated.errors)
            {
                Logger.error(format(error));
            }
        }
        
        // Store successfully analyzed files
        result.files = aggregated.successes;
        
        // If all files failed to analyze, return error
        if (aggregated.isFailed)
        {
            return Err!(TargetAnalysis, BuildError)(aggregated.errors[0]);
        }
        
        // Collect all imports
        auto allImports = result.allImports();
        
        // Resolve imports to dependencies
        result.dependencies = resolveImports(allImports, target.language, config);
        
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
        
        return Ok!(TargetAnalysis, BuildError)(result);
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
