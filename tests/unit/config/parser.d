module tests.unit.config.parser;

import std.stdio;
import std.path;
import std.file;
import std.json;
import std.algorithm;
import config.parser;
import config.schema;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.parser - Parse valid BUILD.json");
    
    auto tempDir = scoped(new TempDir("config-test"));
    
    // Create a valid BUILD.json file
    JSONValue config;
    config["name"] = "test-app";
    config["type"] = "executable";
    config["language"] = "python";
    config["sources"] = ["main.py", "utils.py"];
    config["deps"] = ["//lib:helper"];
    
    tempDir.createFile("BUILD.json", config.toPrettyString());
    tempDir.createFile("main.py", "# Main file");
    tempDir.createFile("utils.py", "# Utils file");
    
    // Parse the workspace
    auto workspace = ConfigParser.parseWorkspace(tempDir.getPath());
    
    Assert.notEmpty(workspace.targets);
    auto target = workspace.targets[0];
    
    Assert.isTrue(target.name.canFind("test-app"));
    Assert.equal(target.type, TargetType.Executable);
    Assert.equal(target.language, TargetLanguage.Python);
    Assert.equal(target.sources.length, 2);
    Assert.equal(target.deps.length, 1);
    
    writeln("\x1b[32m  ✓ BUILD.json parsing works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.parser - Multiple targets");
    
    auto tempDir = scoped(new TempDir("config-test"));
    
    // Create BUILD.json with array of targets
    JSONValue targets;
    targets = JSONValue([
        JSONValue([
            "name": JSONValue("lib"),
            "type": JSONValue("library"),
            "sources": JSONValue(["lib.py"])
        ]),
        JSONValue([
            "name": JSONValue("app"),
            "type": JSONValue("executable"),
            "sources": JSONValue(["app.py"])
        ])
    ]);
    
    tempDir.createFile("BUILD.json", targets.toPrettyString());
    tempDir.createFile("lib.py", "# Library");
    tempDir.createFile("app.py", "# Application");
    
    auto workspace = ConfigParser.parseWorkspace(tempDir.getPath());
    
    Assert.equal(workspace.targets.length, 2);
    Assert.isTrue(workspace.targets[0].name.canFind("lib"));
    Assert.isTrue(workspace.targets[1].name.canFind("app"));
    
    writeln("\x1b[32m  ✓ Multiple targets parsed correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.parser - Language inference");
    
    auto tempDir = scoped(new TempDir("parser-test"));
    
    // Create BUILD.json without explicit language
    JSONValue config;
    config["name"] = "inferred";
    config["type"] = "executable";
    config["sources"] = ["main.py"];
    
    tempDir.createFile("BUILD.json", config.toPrettyString());
    tempDir.createFile("main.py", "# Python file");
    
    auto workspace = ConfigParser.parseWorkspace(tempDir.getPath());
    
    Assert.notEmpty(workspace.targets);
    auto target = workspace.targets[0];
    
    // Language should be inferred from .py extension
    Assert.equal(target.language, TargetLanguage.Python);
    
    writeln("\x1b[32m  ✓ Language inference works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.parser - Glob expansion");
    
    auto tempDir = scoped(new TempDir("parser-test"));
    
    // Create multiple source files
    tempDir.createFile("src/a.py", "# A");
    tempDir.createFile("src/b.py", "# B");
    tempDir.createFile("src/c.py", "# C");
    
    // Create BUILD.json with glob pattern
    JSONValue config;
    config["name"] = "globbed";
    config["type"] = "library";
    config["sources"] = ["src/*.py"];
    
    tempDir.createFile("BUILD.json", config.toPrettyString());
    
    auto workspace = ConfigParser.parseWorkspace(tempDir.getPath());
    
    Assert.notEmpty(workspace.targets);
    auto target = workspace.targets[0];
    
    // Glob should expand to all .py files
    Assert.isTrue(target.sources.length >= 3);
    
    writeln("\x1b[32m  ✓ Glob pattern expansion works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.parser - Invalid JSON handling");
    
    auto tempDir = scoped(new TempDir("parser-test"));
    
    // Create invalid JSON
    tempDir.createFile("BUILD.json", "{ invalid json }");
    
    // Parser should handle gracefully
    auto workspace = ConfigParser.parseWorkspace(tempDir.getPath());
    
    // Should have no targets due to parse error
    Assert.isEmpty(workspace.targets);
    
    writeln("\x1b[32m  ✓ Invalid JSON handled gracefully\x1b[0m");
}

