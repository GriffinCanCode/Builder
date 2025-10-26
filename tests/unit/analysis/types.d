module tests.unit.analysis.types;

import std.stdio;
import analysis.types;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.types - Import kind detection");
    
    auto relativeImport = Import("./utils", ImportKind.Relative, SourceLocation("", 0, 0));
    auto externalImport = Import("lodash", ImportKind.External, SourceLocation("", 0, 0));
    
    Assert.isFalse(relativeImport.isExternal());
    Assert.isTrue(externalImport.isExternal());
    
    writeln("\x1b[32m  ✓ Import kind detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.types - Import normalization");
    
    auto imp = Import("./path/../utils", ImportKind.Relative, SourceLocation("", 0, 0));
    auto normalized = imp.normalized();
    
    Assert.equal(normalized, "utils");
    
    writeln("\x1b[32m  ✓ Import path normalization works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.types - Dependency factory methods");
    
    auto direct = Dependency.direct("//lib:utils", "import utils");
    auto transitive = Dependency.transitive("//lib:core");
    
    Assert.equal(direct.kind, DependencyKind.Direct);
    Assert.equal(direct.sourceImports.length, 1);
    Assert.equal(transitive.kind, DependencyKind.Transitive);
    Assert.isEmpty(transitive.sourceImports);
    
    writeln("\x1b[32m  ✓ Dependency factory methods work\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.types - FileAnalysis validation");
    
    auto validAnalysis = FileAnalysis("test.py", [], "hash123", false, []);
    auto invalidAnalysis = FileAnalysis("bad.py", [], "", true, ["Syntax error"]);
    
    Assert.isTrue(validAnalysis.isValid());
    Assert.isFalse(invalidAnalysis.isValid());
    
    writeln("\x1b[32m  ✓ FileAnalysis validation works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.types - TargetAnalysis aggregation");
    
    auto import1 = Import("os", ImportKind.External, SourceLocation("", 0, 0));
    auto import2 = Import("sys", ImportKind.External, SourceLocation("", 0, 0));
    auto import3 = Import("os", ImportKind.External, SourceLocation("", 0, 0)); // duplicate
    
    auto file1 = FileAnalysis("a.py", [import1, import2], "hash1", false, []);
    auto file2 = FileAnalysis("b.py", [import3], "hash2", false, []);
    
    auto targetAnalysis = TargetAnalysis("test", [file1, file2], [], AnalysisMetrics());
    auto allImports = targetAnalysis.allImports();
    
    Assert.equal(allImports.length, 2); // os and sys, no duplicates
    Assert.isTrue(targetAnalysis.isValid());
    
    writeln("\x1b[32m  ✓ TargetAnalysis aggregates imports correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.types - SourceLocation formatting");
    
    auto loc = SourceLocation("test.py", 42, 10);
    auto str = loc.toString();
    
    Assert.equal(str, "test.py:42:10");
    
    writeln("\x1b[32m  ✓ SourceLocation formatting works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.types - AnalysisMetrics totals");
    
    auto metrics = AnalysisMetrics(10, 50, 5, 100, 50);
    
    Assert.equal(metrics.filesScanned, 10);
    Assert.equal(metrics.importsFound, 50);
    Assert.equal(metrics.totalTimeMs(), 150);
    
    writeln("\x1b[32m  ✓ AnalysisMetrics calculations work\x1b[0m");
}

