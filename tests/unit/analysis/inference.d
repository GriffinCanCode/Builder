module tests.unit.analysis.inference;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import infrastructure.analysis.inference.analyzer;
import infrastructure.config.schema.schema : TargetLanguage;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer build type from main function");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Create file with main function
    std.file.write(buildPath(basePath, "main.cpp"), "int main() { return 0; }");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto buildType = analyzer.inferBuildType(basePath, TargetLanguage.Cpp);
    
    // Should infer executable
    Assert.equal(buildType, "executable");
    
    writeln("\x1b[32m  ✓ Executable inference from main function works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer library from no main");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Create library files without main
    std.file.write(buildPath(basePath, "utils.cpp"), "void util() {}");
    std.file.write(buildPath(basePath, "helper.cpp"), "int helper() { return 42; }");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto buildType = analyzer.inferBuildType(basePath, TargetLanguage.Cpp);
    
    // Should infer library
    Assert.equal(buildType, "library");
    
    writeln("\x1b[32m  ✓ Library inference works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer test from test patterns");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Create test files
    std.file.write(buildPath(basePath, "test_utils.cpp"), "#include <gtest/gtest.h>\nTEST() {}");
    std.file.write(buildPath(basePath, "test_main.cpp"), "int main() { return 0; }");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto buildType = analyzer.inferBuildType(basePath, TargetLanguage.Cpp);
    
    // Should infer test
    Assert.equal(buildType, "test");
    
    writeln("\x1b[32m  ✓ Test inference from patterns works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer dependencies");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Create file with imports
    std.file.write(buildPath(basePath, "main.py"), 
        "import numpy\nimport pandas\nimport requests\n");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto deps = analyzer.inferDependencies(basePath, TargetLanguage.Python);
    
    // Should detect numpy, pandas, requests
    Assert.isTrue(deps.length >= 3);
    
    writeln("\x1b[32m  ✓ Dependency inference works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer compiler flags");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Create C++ file that needs C++17
    std.file.write(buildPath(basePath, "main.cpp"), 
        "#include <optional>\nint main() { std::optional<int> x; }");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto flags = analyzer.inferCompilerFlags(basePath, TargetLanguage.Cpp);
    
    // Should suggest C++17 flag
    Assert.isTrue(flags.length > 0);
    
    writeln("\x1b[32m  ✓ Compiler flag inference works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer output name from directory");
    
    auto tempDir = scoped(new TempDir("my-awesome-app"));
    auto basePath = tempDir.getPath();
    
    std.file.write(buildPath(basePath, "main.cpp"), "int main() {}");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto outputName = analyzer.inferOutputName(basePath);
    
    // Should use directory name
    import std.algorithm : canFind;
    Assert.isTrue(outputName.canFind("my-awesome-app") || outputName.canFind("app"));
    
    writeln("\x1b[32m  ✓ Output name inference works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer source files");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Create various files
    std.file.write(buildPath(basePath, "main.cpp"), "int main() {}");
    std.file.write(buildPath(basePath, "utils.cpp"), "void util() {}");
    std.file.write(buildPath(basePath, "README.md"), "# Project");
    std.file.write(buildPath(basePath, "Makefile"), "all:");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto sources = analyzer.inferSourceFiles(basePath, TargetLanguage.Cpp);
    
    // Should only include .cpp files
    Assert.equal(sources.length, 2);
    Assert.isTrue(sources.canFind!(s => s.endsWith("main.cpp")));
    Assert.isTrue(sources.canFind!(s => s.endsWith("utils.cpp")));
    
    writeln("\x1b[32m  ✓ Source file inference works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer include directories");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Create include directory
    auto includeDir = buildPath(basePath, "include");
    mkdir(includeDir);
    std.file.write(buildPath(includeDir, "header.h"), "#pragma once");
    
    // Create src directory
    auto srcDir = buildPath(basePath, "src");
    mkdir(srcDir);
    std.file.write(buildPath(srcDir, "main.cpp"), "#include \"header.h\"");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto includes = analyzer.inferIncludeDirectories(basePath);
    
    // Should find include directory
    Assert.isTrue(includes.canFind!(d => d.endsWith("include")));
    
    writeln("\x1b[32m  ✓ Include directory inference works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer Python project type");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Create Python package structure
    std.file.write(buildPath(basePath, "setup.py"), "from setuptools import setup");
    std.file.write(buildPath(basePath, "__init__.py"), "");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto buildType = analyzer.inferBuildType(basePath, TargetLanguage.Python);
    
    // Should infer library/package
    Assert.equal(buildType, "library");
    
    writeln("\x1b[32m  ✓ Python project type inference works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer JavaScript project type");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Create package.json with dependencies
    std.file.write(buildPath(basePath, "package.json"), 
        `{"name": "test", "dependencies": {"react": "^18.0.0"}}`);
    std.file.write(buildPath(basePath, "index.js"), "console.log('test');");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto deps = analyzer.inferDependencies(basePath, TargetLanguage.JavaScript);
    
    // Should detect React dependency
    Assert.isTrue(deps.length > 0);
    
    writeln("\x1b[32m  ✓ JavaScript dependency inference works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.inference - Infer confidence levels");
    
    auto tempDir = scoped(new TempDir("inference-test"));
    auto basePath = tempDir.getPath();
    
    // Clear project structure
    std.file.write(buildPath(basePath, "main.cpp"), "int main() { return 0; }");
    std.file.write(buildPath(basePath, "Makefile"), "all: main");
    
    auto analyzer = new BuildInferenceAnalyzer();
    auto result = analyzer.analyzeWithConfidence(basePath, TargetLanguage.Cpp);
    
    // High confidence for clear executable
    Assert.isTrue(result.confidence > 0.7);
    Assert.equal(result.buildType, "executable");
    
    writeln("\x1b[32m  ✓ Confidence level inference works\x1b[0m");
}

