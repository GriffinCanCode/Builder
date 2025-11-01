/**
 * Example benchmark configuration
 * Copy and customize this file for your specific benchmarking needs
 */

module tests.bench.benchmark_config;

import tests.bench.target_generator;
import tests.bench.scale_benchmark;

/// Example 1: Standard 50K target benchmark
GeneratorConfig standardBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 50_000;
    config.projectType = ProjectType.Monorepo;
    config.avgDepsPerTarget = 3.5;
    config.libToExecRatio = 0.7;
    config.generateSources = true;
    config.outputDir = "bench-50k";
    return config;
}

/// Example 2: Large-scale 100K target benchmark
GeneratorConfig largeBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 100_000;
    config.projectType = ProjectType.Monorepo;
    config.avgDepsPerTarget = 3.5;
    config.libToExecRatio = 0.7;
    config.generateSources = true;
    config.outputDir = "bench-100k";
    return config;
}

/// Example 3: Microservices architecture
GeneratorConfig microservicesBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 75_000;
    config.projectType = ProjectType.Microservices;
    config.avgDepsPerTarget = 2.5;  // Services have fewer direct deps
    config.libToExecRatio = 0.3;    // More executables (services)
    config.generateSources = true;
    config.outputDir = "bench-microservices";
    return config;
}

/// Example 4: Library-heavy project
GeneratorConfig libraryBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 50_000;
    config.projectType = ProjectType.Library;
    config.avgDepsPerTarget = 4.5;  // Libraries have more deps
    config.libToExecRatio = 0.9;    // Mostly libraries
    config.generateSources = true;
    config.outputDir = "bench-library";
    return config;
}

/// Example 5: Fast test (no source generation)
GeneratorConfig fastTestBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 50_000;
    config.projectType = ProjectType.Monorepo;
    config.avgDepsPerTarget = 3.5;
    config.libToExecRatio = 0.7;
    config.generateSources = false;  // Skip source file generation
    config.outputDir = "bench-fast";
    return config;
}

/// Example 6: TypeScript-heavy project
GeneratorConfig typescriptBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 60_000;
    config.projectType = ProjectType.Monorepo;
    config.avgDepsPerTarget = 3.5;
    config.libToExecRatio = 0.7;
    config.generateSources = true;
    config.outputDir = "bench-typescript";
    
    // TypeScript dominant
    config.languages.typescript = 0.80;
    config.languages.python = 0.10;
    config.languages.rust = 0.05;
    config.languages.go = 0.03;
    config.languages.cpp = 0.01;
    config.languages.java = 0.01;
    
    return config;
}

/// Example 7: Multi-language balanced
GeneratorConfig multiLanguageBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 50_000;
    config.projectType = ProjectType.Mixed;
    config.avgDepsPerTarget = 3.5;
    config.libToExecRatio = 0.7;
    config.generateSources = true;
    config.outputDir = "bench-multilang";
    
    // Balanced distribution
    config.languages.typescript = 0.20;
    config.languages.python = 0.20;
    config.languages.rust = 0.20;
    config.languages.go = 0.20;
    config.languages.cpp = 0.10;
    config.languages.java = 0.10;
    
    return config;
}

/// Example 8: Deep dependency tree
GeneratorConfig deepDependencyBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 50_000;
    config.projectType = ProjectType.Library;
    config.avgDepsPerTarget = 5.0;  // More dependencies
    config.maxDepth = 30;           // Deeper tree
    config.libToExecRatio = 0.85;
    config.generateSources = true;
    config.outputDir = "bench-deep-deps";
    return config;
}

/// Example 9: Shallow dependency tree (more parallelizable)
GeneratorConfig shallowDependencyBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 50_000;
    config.projectType = ProjectType.Application;
    config.avgDepsPerTarget = 2.0;  // Fewer dependencies
    config.maxDepth = 10;           // Shallow tree
    config.libToExecRatio = 0.5;
    config.generateSources = true;
    config.outputDir = "bench-shallow-deps";
    return config;
}

/// Example 10: Stress test - maximum scale
GeneratorConfig stressTestBenchmark()
{
    auto config = GeneratorConfig();
    config.targetCount = 150_000;  // Push the limits!
    config.projectType = ProjectType.Monorepo;
    config.avgDepsPerTarget = 4.0;
    config.libToExecRatio = 0.75;
    config.generateSources = false;  // Recommended for this scale
    config.outputDir = "bench-stress";
    return config;
}

// Usage example in a custom benchmark script:
/*
#!/usr/bin/env dub
/+ dub.sdl:
    name "my-benchmark"
    dependency "builder" path="../../"
+/

import std.stdio;
import tests.bench.target_generator;
import tests.bench.benchmark_config;

void main()
{
    // Use a predefined config
    auto config = standardBenchmark();
    
    // Or customize it
    config.targetCount = 75_000;
    config.outputDir = "my-custom-bench";
    
    // Generate
    auto generator = new TargetGenerator(config);
    auto targets = generator.generate();
    
    writeln("Generated ", targets.length, " targets");
}
*/

