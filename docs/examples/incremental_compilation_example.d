/// Example: Module-Level Incremental Compilation
/// 
/// Demonstrates how to use Builder's incremental compilation system
/// to achieve minimal rebuilds based on file-level dependency tracking.

module examples.incremental_compilation_example;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.process;
import caching.incremental.dependency;
import caching.actions.action;
import compilation.incremental.engine;
import compilation.incremental.analyzer;
import languages.compiled.cpp.analysis.incremental;
import utils.files.hash;

/// Example 1: Basic C++ Incremental Compilation
void example1_basic_cpp_incremental()
{
    writeln("\n=== Example 1: Basic C++ Incremental Compilation ===\n");
    
    // Setup: Create caches
    auto depCache = new DependencyCache(".builder-cache/incremental/cpp");
    auto actionCache = new ActionCache(".builder-cache/actions/cpp");
    auto engine = new IncrementalEngine(depCache, actionCache);
    
    // Setup: Create C++ dependency analyzer
    auto analyzer = new CppDependencyAnalyzer(["include", "src"]);
    
    // Simulated project structure:
    // src/main.cpp (includes: header.h, utils.h)
    // src/module.cpp (includes: header.h)
    // src/standalone.cpp (includes: other.h)
    
    string[] allSources = [
        "src/main.cpp",
        "src/module.cpp",
        "src/standalone.cpp"
    ];
    
    // First build - everything needs compilation
    writeln("First build (all files):");
    
    foreach (source; allSources)
    {
        // Analyze dependencies
        auto depsResult = analyzer.analyzeDependencies(source);
        if (depsResult.isErr)
        {
            writeln("  [Error] Failed to analyze: ", source);
            continue;
        }
        
        auto deps = depsResult.unwrap();
        writeln("  ", source, " depends on: ", deps);
        
        // Compile (simulated)
        bool success = compileFile(source);
        
        // Record compilation
        ActionId actionId;
        actionId.targetId = "myproject";
        actionId.type = ActionType.Compile;
        actionId.subId = baseName(source);
        actionId.inputHash = FastHash.hashFile(source);
        
        string[string] metadata;
        metadata["compiler"] = "g++";
        metadata["flags"] = "-O2 -std=c++17";
        
        string objFile = source.stripExtension ~ ".o";
        
        engine.recordCompilation(
            source,
            deps,
            actionId,
            [objFile],
            metadata
        );
        
        writeln("  [Compiled] ", source);
    }
    
    // Second build - header.h changed
    writeln("\nSecond build (header.h changed):");
    
    string[] changedFiles = ["include/header.h"];
    
    auto result = engine.determineRebuildSet(
        allSources,
        changedFiles,
        (file) {
            ActionId id;
            id.targetId = "myproject";
            id.type = ActionType.Compile;
            id.subId = baseName(file);
            id.inputHash = FastHash.hashFile(file);
            return id;
        },
        (file) {
            string[string] meta;
            meta["compiler"] = "g++";
            meta["flags"] = "-O2 -std=c++17";
            return meta;
        }
    );
    
    writeln("  Files to compile: ", result.filesToCompile);
    writeln("  Cached files: ", result.cachedFiles);
    writeln("  Compiled: ", result.compiledFiles, "/", result.totalFiles);
    writeln("  Reduction: ", result.reductionRate, "%");
    
    // Only main.cpp and module.cpp need recompilation (depend on header.h)
    // standalone.cpp uses cached result (depends on other.h, not header.h)
}

/// Example 2: Transitive Dependency Analysis
void example2_transitive_dependencies()
{
    writeln("\n=== Example 2: Transitive Dependency Analysis ===\n");
    
    auto analyzer = new CppDependencyAnalyzer(["include"]);
    
    // Project structure:
    // main.cpp includes base.h
    // base.h includes utils.h
    // utils.h includes types.h
    
    string sourceFile = "src/main.cpp";
    
    // Get direct dependencies
    auto directDeps = analyzer.analyzeDependencies(sourceFile);
    if (directDeps.isOk)
    {
        writeln("Direct dependencies of ", sourceFile, ":");
        foreach (dep; directDeps.unwrap())
            writeln("  - ", dep);
    }
    
    // Get transitive dependencies
    auto transitiveDeps = analyzer.getTransitiveDependencies(sourceFile);
    writeln("\nTransitive dependencies of ", sourceFile, ":");
    foreach (dep; transitiveDeps)
        writeln("  - ", dep);
    
    writeln("\nConclusion: If types.h changes, main.cpp needs recompilation");
    writeln("even though it doesn't directly include types.h!");
}

/// Example 3: Affected Sources Detection
void example3_affected_sources()
{
    writeln("\n=== Example 3: Affected Sources Detection ===\n");
    
    auto analyzer = new CppDependencyAnalyzer(["include", "src"]);
    
    string[] allSources = [
        "src/main.cpp",
        "src/module1.cpp",
        "src/module2.cpp",
        "src/module3.cpp",
        "src/standalone.cpp"
    ];
    
    // Find which sources are affected by a header change
    string changedHeader = "include/common.h";
    
    writeln("Analyzing impact of changing: ", changedHeader);
    
    auto affected = CppIncrementalHelper.findAffectedSources(
        changedHeader,
        allSources,
        analyzer
    );
    
    writeln("\nAffected source files:");
    foreach (source; affected)
        writeln("  [Rebuild Required] ", source);
    
    auto unaffected = allSources.filter!(s => !affected.canFind(s)).array;
    writeln("\nUnaffected source files (can use cached):");
    foreach (source; unaffected)
        writeln("  [Cached] ", source);
    
    float reduction = (unaffected.length * 100.0) / allSources.length;
    writeln("\nReduction: ", reduction, "%");
}

/// Example 4: Multi-Language Incremental Compilation
void example4_multi_language()
{
    writeln("\n=== Example 4: Multi-Language Incremental Compilation ===\n");
    
    import languages.compiled.d.analysis.incremental;
    import languages.compiled.rust.analysis.incremental;
    import languages.scripting.go.analysis.incremental;
    
    // C++ project
    {
        writeln("C++ Project:");
        auto analyzer = new CppDependencyAnalyzer(["include"]);
        auto deps = analyzer.analyzeDependencies("src/main.cpp");
        if (deps.isOk)
            writeln("  main.cpp dependencies: ", deps.unwrap().length);
    }
    
    // D project
    {
        writeln("\nD Project:");
        auto analyzer = new DDependencyAnalyzer(".", ["src"]);
        auto deps = analyzer.analyzeDependencies("src/app.d");
        if (deps.isOk)
            writeln("  app.d dependencies: ", deps.unwrap().length);
    }
    
    // Rust project
    {
        writeln("\nRust Project:");
        auto analyzer = new RustDependencyAnalyzer(".");
        auto deps = analyzer.analyzeDependencies("src/main.rs");
        if (deps.isOk)
            writeln("  main.rs dependencies: ", deps.unwrap().length);
    }
    
    // Go project
    {
        writeln("\nGo Project:");
        auto analyzer = new GoDependencyAnalyzer(".");
        auto deps = analyzer.analyzeDependencies("main.go");
        if (deps.isOk)
            writeln("  main.go dependencies: ", deps.unwrap().length);
    }
    
    writeln("\nConclusion: Incremental compilation works across all languages!");
}

/// Example 5: Compilation Strategies
void example5_strategies()
{
    writeln("\n=== Example 5: Compilation Strategies ===\n");
    
    auto depCache = new DependencyCache(".builder-cache/incremental");
    auto actionCache = new ActionCache(".builder-cache/actions");
    
    string[] allSources = ["file1.cpp", "file2.cpp", "file3.cpp"];
    string[] changedFiles = ["file1.cpp"];
    
    auto makeActionId = (string file) {
        ActionId id;
        id.targetId = "test";
        id.type = ActionType.Compile;
        id.subId = baseName(file);
        return id;
    };
    
    auto makeMetadata = (string file) {
        string[string] meta;
        return meta;
    };
    
    // Strategy 1: Full
    {
        writeln("Strategy: Full");
        auto engine = new IncrementalEngine(
            depCache, actionCache, CompilationStrategy.Full
        );
        
        auto result = engine.determineRebuildSet(
            allSources, changedFiles, makeActionId, makeMetadata
        );
        
        writeln("  Files to compile: ", result.filesToCompile.length);
        writeln("  Use case: CI builds, untrusted caches");
    }
    
    // Strategy 2: Incremental
    {
        writeln("\nStrategy: Incremental");
        auto engine = new IncrementalEngine(
            depCache, actionCache, CompilationStrategy.Incremental
        );
        
        auto result = engine.determineRebuildSet(
            allSources, changedFiles, makeActionId, makeMetadata
        );
        
        writeln("  Files to compile: ", result.filesToCompile.length);
        writeln("  Use case: Development, optimal rebuild set");
    }
    
    // Strategy 3: Minimal
    {
        writeln("\nStrategy: Minimal");
        auto engine = new IncrementalEngine(
            depCache, actionCache, CompilationStrategy.Minimal
        );
        
        auto result = engine.determineRebuildSet(
            allSources, changedFiles, makeActionId, makeMetadata
        );
        
        writeln("  Files to compile: ", result.filesToCompile.length);
        writeln("  Use case: Quick iteration, fast feedback");
    }
}

/// Example 6: Custom Dependency Analyzer
void example6_custom_analyzer()
{
    writeln("\n=== Example 6: Custom Dependency Analyzer ===\n");
    
    class PythonDependencyAnalyzer : BaseDependencyAnalyzer
    {
        this() { super(); }
        
        override Result!(string[], BuildError) analyzeDependencies(
            string sourceFile,
            string[] searchPaths = []
        ) @system
        {
            import std.regex;
            
            // Parse Python imports
            auto content = readText(sourceFile);
            string[] deps;
            
            // Match: import module, from module import x
            auto importRegex = regex(r"(?:from|import)\s+([\w\.]+)");
            foreach (match; matchAll(content, importRegex))
            {
                if (match.length > 1)
                {
                    auto moduleName = match[1];
                    if (!isExternalDependency(moduleName))
                    {
                        // Convert module.name to module/name.py
                        auto path = moduleName.replace(".", "/") ~ ".py";
                        deps ~= path;
                    }
                }
            }
            
            return Result!(string[], BuildError).ok(deps);
        }
        
        override bool isExternalDependency(string moduleName) @system
        {
            // Python standard library and common packages
            return moduleName.startsWith("sys") ||
                   moduleName.startsWith("os") ||
                   moduleName.startsWith("numpy") ||
                   moduleName.startsWith("pandas");
        }
    }
    
    auto analyzer = new PythonDependencyAnalyzer();
    
    writeln("Created custom Python dependency analyzer");
    writeln("Can now track Python module dependencies for incremental builds!");
}

/// Helper: Simulate file compilation
bool compileFile(string source)
{
    // Simulated compilation
    return true;
}

/// Main example runner
void main()
{
    writeln("╔════════════════════════════════════════════════════════════╗");
    writeln("║    Module-Level Incremental Compilation Examples          ║");
    writeln("╚════════════════════════════════════════════════════════════╝");
    
    example1_basic_cpp_incremental();
    example2_transitive_dependencies();
    example3_affected_sources();
    example4_multi_language();
    example5_strategies();
    example6_custom_analyzer();
    
    writeln("\n╔════════════════════════════════════════════════════════════╗");
    writeln("║                    Examples Complete                       ║");
    writeln("╚════════════════════════════════════════════════════════════╝");
}

