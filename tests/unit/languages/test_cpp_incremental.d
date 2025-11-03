module tests.unit.languages.test_cpp_incremental;

import std.file;
import std.path;
import std.algorithm;
import std.conv;
import languages.compiled.cpp.analysis.incremental;
import testframework.execution.executor;
import testframework.assertions.asserts;
import errors;

/// Test C++ dependency analyzer
class TestCppDependencyAnalyzer : TestCase
{
    private string testDir;
    private CppDependencyAnalyzer analyzer;
    
    this()
    {
        super("C++ Dependency Analyzer");
    }
    
    override void setup()
    {
        testDir = buildPath(tempDir(), "test-cpp-deps-" ~ randomUUID().to!string);
        mkdirRecurse(testDir);
        
        // Create test files
        std.file.write(buildPath(testDir, "main.cpp"), 
            "#include \"header.h\"\n#include <iostream>\nint main() {}");
        std.file.write(buildPath(testDir, "header.h"), 
            "#ifndef HEADER_H\n#define HEADER_H\nvoid func();\n#endif");
        std.file.write(buildPath(testDir, "utils.h"), 
            "#ifndef UTILS_H\n#define UTILS_H\nvoid util();\n#endif");
        
        analyzer = new CppDependencyAnalyzer([testDir]);
    }
    
    override void teardown()
    {
        if (exists(testDir))
            rmdirRecurse(testDir);
    }
    
    override void run()
    {
        auto mainPath = buildPath(testDir, "main.cpp");
        auto headerPath = buildPath(testDir, "header.h");
        
        auto result = analyzer.analyzeDependencies(mainPath);
        assertTrue(result.isOk, "Should analyze dependencies");
        
        auto deps = result.unwrap();
        assertTrue(deps.length > 0, "Should find dependencies");
        assertTrue(deps.canFind(headerPath), "Should find header.h");
        assertFalse(deps.canFind("iostream"), "Should not include system headers");
    }
}

/// Test C++ external dependency detection
class TestCppExternalDependencies : TestCase
{
    private CppDependencyAnalyzer analyzer;
    
    this()
    {
        super("C++ External Dependency Detection");
    }
    
    override void setup()
    {
        analyzer = new CppDependencyAnalyzer();
    }
    
    override void run()
    {
        // Standard library headers
        assertTrue(analyzer.isExternalDependency("iostream"),
                  "iostream should be external");
        assertTrue(analyzer.isExternalDependency("vector"),
                  "vector should be external");
        assertTrue(analyzer.isExternalDependency("string.h"),
                  "string.h should be external");
        
        // Local headers
        assertFalse(analyzer.isExternalDependency("myheader.h"),
                   "myheader.h should not be external");
        assertFalse(analyzer.isExternalDependency("utils/helper.h"),
                   "utils/helper.h should not be external");
    }
}

/// Test C++ affected sources detection
class TestCppAffectedSources : TestCase
{
    private string testDir;
    private CppDependencyAnalyzer analyzer;
    
    this()
    {
        super("C++ Affected Sources Detection");
    }
    
    override void setup()
    {
        testDir = buildPath(tempDir(), "test-cpp-affected-" ~ randomUUID().to!string);
        mkdirRecurse(testDir);
        
        // Create source files with dependencies
        std.file.write(buildPath(testDir, "main.cpp"),
            "#include \"shared.h\"\nint main() {}");
        std.file.write(buildPath(testDir, "utils.cpp"),
            "#include \"shared.h\"\nvoid util() {}");
        std.file.write(buildPath(testDir, "other.cpp"),
            "#include \"other.h\"\nvoid other() {}");
        std.file.write(buildPath(testDir, "shared.h"),
            "void shared();");
        std.file.write(buildPath(testDir, "other.h"),
            "void other_func();");
        
        analyzer = new CppDependencyAnalyzer([testDir]);
    }
    
    override void teardown()
    {
        if (exists(testDir))
            rmdirRecurse(testDir);
    }
    
    override void run()
    {
        auto sharedHeader = buildPath(testDir, "shared.h");
        auto mainCpp = buildPath(testDir, "main.cpp");
        auto utilsCpp = buildPath(testDir, "utils.cpp");
        auto otherCpp = buildPath(testDir, "other.cpp");
        
        auto allSources = [mainCpp, utilsCpp, otherCpp];
        
        auto affected = CppIncrementalHelper.findAffectedSources(
            sharedHeader,
            allSources,
            analyzer
        );
        
        assertTrue(affected.canFind(mainCpp),
                  "main.cpp should be affected by shared.h");
        assertTrue(affected.canFind(utilsCpp),
                  "utils.cpp should be affected by shared.h");
        assertFalse(affected.canFind(otherCpp),
                   "other.cpp should not be affected by shared.h");
    }
}

/// Test suite for C++ incremental compilation
class CppIncrementalTestSuite : TestSuite
{
    this()
    {
        super("C++ Incremental Compilation");
        
        addTest(new TestCppDependencyAnalyzer());
        addTest(new TestCppExternalDependencies());
        addTest(new TestCppAffectedSources());
    }
}

private string randomUUID()
{
    import std.random;
    import std.format;
    
    return format("%08x-%04x-%04x-%04x-%012x",
                 uniform!uint(),
                 uniform!ushort(),
                 uniform!ushort(),
                 uniform!ushort(),
                 uniform!ulong() & 0xFFFF_FFFF_FFFF);
}

