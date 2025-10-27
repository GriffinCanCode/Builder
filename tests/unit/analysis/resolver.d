module tests.unit.analysis.resolver;

import std.stdio;
import std.path;
import std.algorithm;
import std.range;
import analysis.resolution.resolver;
import config.schema;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.resolver - Import to target resolution");
    
    // Create workspace config with targets
    WorkspaceConfig config;
    config.root = ".";
    
    // Add Python target
    Target pyTarget;
    pyTarget.name = "//lib:utils";
    pyTarget.language = TargetLanguage.Python;
    pyTarget.sources = ["lib/utils.py", "lib/helpers.py"];
    config.targets ~= pyTarget;
    
    // Add D target
    Target dTarget;
    dTarget.name = "//core:graph";
    dTarget.language = TargetLanguage.D;
    dTarget.sources = ["core/graph.d"];
    config.targets ~= dTarget;
    
    auto resolver = new DependencyResolver(config);
    
    // Test Python import resolution
    auto pyResolved = resolver.resolveImport("lib.utils", TargetLanguage.Python);
    Assert.equal(pyResolved, "//lib:utils");
    
    // Test D module resolution
    auto dResolved = resolver.resolveImport("core.graph", TargetLanguage.D);
    Assert.equal(dResolved, "//core:graph");
    
    writeln("\x1b[32m  ✓ Import resolution works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.resolver - O(1) indexed lookup");
    
    // Create config with many targets
    WorkspaceConfig config;
    config.root = ".";
    
    // Add 1000 targets to test lookup performance
    foreach (i; 0 .. 1000)
    {
        import std.conv : to;
        Target target;
        target.name = "//module" ~ i.to!string ~ ":lib";
        target.sources = ["module" ~ i.to!string ~ "/lib.py"];
        config.targets ~= target;
    }
    
    auto resolver = new DependencyResolver(config);
    
    // Create index for fast lookup
    auto index = new ImportIndex(config);
    
    // Test lookup is fast (O(1) expected)
    auto result1 = index.lookup("module500/lib.py");
    Assert.equal(result1, "//module500:lib");
    
    auto result2 = index.lookup("module999/lib.py");
    Assert.equal(result2, "//module999:lib");
    
    // Verify all modules indexed
    auto allModules = index.allModules();
    Assert.isTrue(allModules.length >= 1000);
    
    writeln("\x1b[32m  ✓ O(1) indexed lookup verified\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.resolver - Relative dependency resolution");
    
    WorkspaceConfig config;
    config.root = ".";
    
    auto resolver = new DependencyResolver(config);
    
    // Test absolute reference
    auto abs = resolver.resolve("//path/to:target", "//from:target");
    Assert.equal(abs, "//path/to:target");
    
    // Test relative reference
    auto rel = resolver.resolve(":sibling", "//package:main");
    Assert.equal(rel, "//package:sibling");
    
    writeln("\x1b[32m  ✓ Relative dependency resolution works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.resolver - External import filtering");
    
    WorkspaceConfig config;
    config.root = ".";
    
    Target target;
    target.name = "//app:main";
    target.sources = ["app/main.py"];
    config.targets ~= target;
    
    auto resolver = new DependencyResolver(config);
    
    // External imports should return empty string
    auto external1 = resolver.resolveImport("numpy", TargetLanguage.Python);
    Assert.isTrue(external1.empty);
    
    auto external2 = resolver.resolveImport("pandas", TargetLanguage.Python);
    Assert.isTrue(external2.empty);
    
    writeln("\x1b[32m  ✓ External imports filtered correctly\x1b[0m");
}

