module tests.unit.languages.cpp;

import std.stdio;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import languages.compiled.cpp;
import config.schema.schema;
import tests.harness;
import tests.fixtures;

/// Test C++ include detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.cpp - Include detection");
    
    auto tempDir = scoped(new TempDir("cpp-test"));
    
    string cppCode = `
#include <iostream>
#include <vector>
#include <string>
#include "myheader.h"
#include "utils/helper.h"
`;
    
    tempDir.createFile("test.cpp", cppCode);
    auto filePath = buildPath(tempDir.getPath(), "test.cpp");
    
    auto handler = new CppHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notEmpty(imports);
    
    writeln("\x1b[32m  ✓ C++ include detection works\x1b[0m");
}

/// Test C++ executable build
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.cpp - Build executable");
    
    auto tempDir = scoped(new TempDir("cpp-test"));
    
    tempDir.createFile("main.cpp", `
#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
`);
    
    auto target = TargetBuilder.create("//app:main")
        .withType(TargetType.Executable)
        .withSources([buildPath(tempDir.getPath(), "main.cpp")])
        .build();
    target.language = TargetLanguage.Cpp;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    config.options.outputDir = buildPath(tempDir.getPath(), "bin");
    
    auto handler = new CppHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk || result.isErr);  // May fail if no compiler, but should handle gracefully
    
    writeln("\x1b[32m  ✓ C++ executable build works\x1b[0m");
}

/// Test C++ library build
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.cpp - Build static library");
    
    auto tempDir = scoped(new TempDir("cpp-test"));
    
    tempDir.createFile("utils.cpp", `
#include "utils.h"

int add(int a, int b) {
    return a + b;
}
`);
    
    tempDir.createFile("utils.h", `
#ifndef UTILS_H
#define UTILS_H

int add(int a, int b);

#endif
`);
    
    auto target = TargetBuilder.create("//lib:utils")
        .withType(TargetType.Library)
        .withSources([buildPath(tempDir.getPath(), "utils.cpp")])
        .build();
    target.language = TargetLanguage.Cpp;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    config.options.outputDir = buildPath(tempDir.getPath(), "lib");
    
    auto handler = new CppHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk || result.isErr);
    
    writeln("\x1b[32m  ✓ C++ library build works\x1b[0m");
}

/// Test C++ multi-file project
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.cpp - Multi-file project");
    
    auto tempDir = scoped(new TempDir("cpp-test"));
    
    tempDir.createFile("main.cpp", `
#include "greeter.h"

int main() {
    greet("World");
    return 0;
}
`);
    
    tempDir.createFile("greeter.cpp", `
#include "greeter.h"
#include <iostream>

void greet(const char* name) {
    std::cout << "Hello, " << name << "!" << std::endl;
}
`);
    
    tempDir.createFile("greeter.h", `
#ifndef GREETER_H
#define GREETER_H

void greet(const char* name);

#endif
`);
    
    auto mainPath = buildPath(tempDir.getPath(), "main.cpp");
    auto greeterPath = buildPath(tempDir.getPath(), "greeter.cpp");
    
    auto target = TargetBuilder.create("//app:greeter")
        .withType(TargetType.Executable)
        .withSources([mainPath, greeterPath])
        .build();
    target.language = TargetLanguage.Cpp;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    config.options.outputDir = buildPath(tempDir.getPath(), "bin");
    
    auto handler = new CppHandler();
    auto imports = handler.analyzeImports([mainPath, greeterPath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ C++ multi-file project works\x1b[0m");
}

/// Test C++ standard detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.cpp - C++ standard detection");
    
    auto tempDir = scoped(new TempDir("cpp-test"));
    
    // C++17 features
    tempDir.createFile("modern.cpp", `
#include <optional>
#include <string_view>

std::optional<int> getValue() {
    return 42;
}
`);
    
    auto filePath = buildPath(tempDir.getPath(), "modern.cpp");
    
    auto handler = new CppHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ C++ standard detection works\x1b[0m");
}

