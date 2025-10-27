module analysis.inference.analyzer;

import std.stdio;
import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.string;
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
    /// Note: Uses target.id for type-safe identification where possible
    BuildGraph analyze(in string targetFilter = "") @trusted
    {
        Logger.info("Analyzing dependencies...");
        auto sw = StopWatch(AutoStart.yes);
        
        auto graph = new BuildGraph();
        
        // Add all targets to graph
        // Uses TargetId for filtering when available
        foreach (ref target; config.targets)
        {
            // Use TargetId.matches() for more flexible filtering
            bool shouldInclude = targetFilter.empty || 
                                matchesFilter(target.name, targetFilter) ||
                                target.id.matches(targetFilter);
            
            if (shouldInclude)
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
                    auto addResult = graph.addDependency(target.name, dep.targetName);
                    if (addResult.isErr)
                    {
                        auto error = addResult.unwrapErr();
                        Logger.error("Failed to add dependency: " ~ format(error));
                        // Continue processing other dependencies
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
        import std.string : indexOf, startsWith, endsWith;
        
        if (pattern.empty)
            return true;
        
        // Handle :target pattern (matches any //path:target)
        if (pattern.startsWith(":"))
        {
            return name.endsWith(pattern);
        }
        
        // Simple pattern matching with wildcards
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

/// Build inference result
struct InferenceResult
{
    string buildType;
    double confidence;
}

/// Simple build inference analyzer for zero-config builds
class BuildInferenceAnalyzer
{
    this() {}
    
    /// Infer build type (executable, library, test)
    string inferBuildType(string basePath, TargetLanguage language)
    {
        // Check for test patterns first (tests can have main functions)
        if (hasTestPatterns(basePath, language))
            return "test";
        
        // Check for main function indicating executable
        if (hasMainFunction(basePath, language))
            return "executable";
        
        // Check for library patterns
        if (hasLibraryPatterns(basePath, language))
            return "library";
        
        // Default to library if no main found
        return "library";
    }
    
    /// Infer dependencies from imports/requires
    string[] inferDependencies(string basePath, TargetLanguage language)
    {
        string[] dependencies;
        
        try
        {
            // For JavaScript/TypeScript, also check package.json
            if (language == TargetLanguage.JavaScript || language == TargetLanguage.TypeScript)
            {
                auto packageJsonPath = buildPath(basePath, "package.json");
                if (exists(packageJsonPath) && isFile(packageJsonPath))
                {
                    auto packageJson = readText(packageJsonPath);
                    auto packageDeps = extractPackageJsonDependencies(packageJson);
                    
                    foreach (dep; packageDeps)
                    {
                        if (!dependencies.canFind(dep))
                            dependencies ~= dep;
                    }
                }
            }
            
            auto files = getSourceFiles(basePath, language);
            
            foreach (file; files)
            {
                if (!exists(file) || !isFile(file))
                    continue;
                
                auto content = readText(file);
                auto fileDeps = extractDependencies(content, language);
                
                foreach (dep; fileDeps)
                {
                    if (!dependencies.canFind(dep))
                        dependencies ~= dep;
                }
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to infer dependencies from " ~ basePath ~ ": " ~ e.msg);
        }
        
        return dependencies;
    }
    
    /// Infer compiler flags from source code
    string[] inferCompilerFlags(string basePath, TargetLanguage language)
    {
        string[] flags;
        
        try
        {
            auto files = getSourceFiles(basePath, language);
            
            foreach (file; files)
            {
                if (!exists(file) || !isFile(file))
                    continue;
                
                auto content = readText(file);
                
                // Check for C++17/20 features
                if (language == TargetLanguage.Cpp)
                {
                    if (content.canFind("<optional>") || 
                        content.canFind("std::optional") ||
                        content.canFind("<variant>") ||
                        content.canFind("<filesystem>"))
                    {
                        if (!flags.canFind("-std=c++17"))
                            flags ~= "-std=c++17";
                    }
                }
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to infer compiler flags from " ~ basePath ~ ": " ~ e.msg);
        }
        
        return flags;
    }
    
    /// Infer output name from directory or project files
    string inferOutputName(string basePath)
    {
        import std.path : baseName;
        return baseName(basePath);
    }
    
    /// Infer source files for a language
    string[] inferSourceFiles(string basePath, TargetLanguage language)
    {
        return getSourceFiles(basePath, language);
    }
    
    /// Infer include directories from project structure
    string[] inferIncludeDirectories(string basePath)
    {
        import std.path : buildPath;
        import std.file : dirEntries, SpanMode, isDir;
        
        string[] includes;
        
        try
        {
            // Common include directory names
            immutable dirs = ["include", "inc", "headers"];
            
            foreach (dir; dirs)
            {
                auto path = buildPath(basePath, dir);
                if (exists(path) && isDir(path))
                    includes ~= path;
            }
            
            // Also check subdirectories
            foreach (entry; dirEntries(basePath, SpanMode.shallow))
            {
                if (entry.isDir && entry.name.baseName == "include")
                    includes ~= entry.name;
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to infer include directories from " ~ basePath ~ ": " ~ e.msg);
        }
        
        return includes;
    }
    
    /// Analyze with confidence scoring
    InferenceResult analyzeWithConfidence(string basePath, TargetLanguage language)
    {
        InferenceResult result;
        result.buildType = inferBuildType(basePath, language);
        
        // Calculate confidence based on evidence
        double confidence = 0.5;  // Base confidence
        
        // Increase confidence for clear indicators
        if (hasMainFunction(basePath, language))
            confidence += 0.3;
        
        // Check for manifest files (increases confidence)
        if (hasManifestFile(basePath, language))
            confidence += 0.2;
        
        result.confidence = confidence > 1.0 ? 1.0 : confidence;
        return result;
    }
    
    // Helper methods
    
    private bool hasMainFunction(string basePath, TargetLanguage language)
    {
        try
        {
            auto files = getSourceFiles(basePath, language);
            
            foreach (file; files)
            {
                if (!exists(file) || !isFile(file))
                    continue;
                
                auto content = readText(file);
                
                // Check for main function patterns
                if (content.canFind("int main(") || 
                    content.canFind("fn main()") ||
                    content.canFind("func main()") ||
                    content.canFind("def main(") ||
                    content.canFind("public static void main"))
                {
                    return true;
                }
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to check for main function in " ~ basePath ~ ": " ~ e.msg);
        }
        
        return false;
    }
    
    private bool hasTestPatterns(string basePath, TargetLanguage language)
    {
        import std.path : baseName;
        
        try
        {
            auto files = getSourceFiles(basePath, language);
            
            foreach (file; files)
            {
                auto name = baseName(file);
                
                if (name.startsWith("test_") || name.startsWith("Test"))
                    return true;
                
                if (!exists(file) || !isFile(file))
                    continue;
                
                auto content = readText(file);
                
                // Check for test framework imports
                if (content.canFind("gtest") || 
                    content.canFind("unittest") ||
                    content.canFind("pytest") ||
                    content.canFind("@Test"))
                {
                    return true;
                }
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to check for test patterns in " ~ basePath ~ ": " ~ e.msg);
        }
        
        return false;
    }
    
    private bool hasLibraryPatterns(string basePath, TargetLanguage language)
    {
        try
        {
            // Check for package/library manifest files
            if (language == TargetLanguage.Python)
            {
                if (exists(buildPath(basePath, "setup.py")) ||
                    exists(buildPath(basePath, "__init__.py")))
                    return true;
            }
            else if (language == TargetLanguage.JavaScript || language == TargetLanguage.TypeScript)
            {
                if (exists(buildPath(basePath, "package.json")))
                    return true;
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to check for library patterns in " ~ basePath ~ ": " ~ e.msg);
        }
        
        return false;
    }
    
    private bool hasManifestFile(string basePath, TargetLanguage language)
    {
        try
        {
            immutable manifests = [
                "package.json", "Cargo.toml", "go.mod", "setup.py", 
                "pom.xml", "build.gradle", "Makefile"
            ];
            
            foreach (manifest; manifests)
            {
                if (exists(buildPath(basePath, manifest)))
                    return true;
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to check for manifest files in " ~ basePath ~ ": " ~ e.msg);
        }
        
        return false;
    }
    
    private string[] getSourceFiles(string basePath, TargetLanguage language)
    {
        import std.file : dirEntries, SpanMode;
        import std.path : extension;
        
        string[] files;
        
        try
        {
            auto extensions = languageExtensions(language);
            
            foreach (entry; dirEntries(basePath, SpanMode.depth))
            {
                if (!entry.isFile)
                    continue;
                
                auto ext = entry.name.extension;
                if (extensions.canFind(ext))
                    files ~= entry.name;
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to get source files from " ~ basePath ~ ": " ~ e.msg);
        }
        
        return files;
    }
    
    private string[] extractDependencies(string content, TargetLanguage language)
    {
        import std.regex;
        
        string[] deps;
        
        try
        {
            if (language == TargetLanguage.Python)
            {
                // Match: import numpy, from pandas import ...
                auto re = regex(`^(?:import|from)\s+([a-zA-Z_][a-zA-Z0-9_]*)`, "m");
                foreach (match; matchAll(content, re))
                {
                    auto dep = match[1];
                    if (!deps.canFind(dep))
                        deps ~= dep;
                }
            }
            else if (language == TargetLanguage.JavaScript || language == TargetLanguage.TypeScript)
            {
                // Match: import React from 'react', require('express')
                auto re = regex(`(?:import|require)\s*\(?\s*['"]([^'"]+)['"]`, "m");
                foreach (match; matchAll(content, re))
                {
                    auto dep = match[1];
                    if (!deps.canFind(dep))
                        deps ~= dep;
                }
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to extract dependencies from content: " ~ e.msg);
        }
        
        return deps;
    }
    
    private string[] extractPackageJsonDependencies(string packageJsonContent)
    {
        import std.regex;
        import std.json;
        
        string[] deps;
        
        try
        {
            auto json = parseJSON(packageJsonContent);
            
            // Extract from dependencies
            if ("dependencies" in json)
            {
                foreach (string key, value; json["dependencies"].object)
                {
                    if (!deps.canFind(key))
                        deps ~= key;
                }
            }
            
            // Extract from devDependencies
            if ("devDependencies" in json)
            {
                foreach (string key, value; json["devDependencies"].object)
                {
                    if (!deps.canFind(key))
                        deps ~= key;
                }
            }
        }
        catch (Exception e)
        {
            Logger.debug_("Failed to parse package.json dependencies: " ~ e.msg);
        }
        
        return deps;
    }
    
    private string[] languageExtensions(TargetLanguage language)
    {
        switch (language)
        {
            case TargetLanguage.Python: return [".py"];
            case TargetLanguage.JavaScript: return [".js", ".mjs", ".cjs", ".jsx"];
            case TargetLanguage.TypeScript: return [".ts", ".tsx"];
            case TargetLanguage.Cpp: return [".cpp", ".cc", ".cxx", ".hpp", ".h"];
            case TargetLanguage.C: return [".c", ".h"];
            case TargetLanguage.Rust: return [".rs"];
            case TargetLanguage.Go: return [".go"];
            case TargetLanguage.Java: return [".java"];
            case TargetLanguage.Ruby: return [".rb"];
            default: return [];
        }
    }
}
