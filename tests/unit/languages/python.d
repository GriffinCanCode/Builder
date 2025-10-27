module tests.unit.languages.python;

import std.stdio;
import std.path;
import std.regex;
import std.algorithm;
import std.array;
import languages.scripting.python;
import config.schema.schema;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.python - Import detection");
    
    auto tempDir = scoped(new TempDir("python-test"));
    
    string pythonCode = `
import os
import sys
from pathlib import Path
from mypackage import utils
`;
    
    tempDir.createFile("test.py", pythonCode);
    auto filePath = buildPath(tempDir.getPath(), "test.py");
    
    // Test import analysis
    auto handler = new PythonHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notEmpty(imports);
    
    // Verify standard library imports detected
    auto importNames = imports.map!(i => i.moduleName).array;
    Assert.isTrue(importNames.canFind!(name => name.canFind("os") || 
                                               name.canFind("sys") || 
                                               name.canFind("pathlib")));
    
    writeln("\x1b[32m  ✓ Python import detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.python - Syntax validation");
    
    auto tempDir = scoped(new TempDir("python-test"));
    
    // Create valid Python file
    tempDir.createFile("valid.py", `
def greet(name):
    print(f"Hello, {name}!")

if __name__ == "__main__":
    greet("World")
`);
    
    // Create invalid Python file
    tempDir.createFile("invalid.py", `
def broken(
    print "missing syntax"
`);
    
    auto validPath = buildPath(tempDir.getPath(), "valid.py");
    auto invalidPath = buildPath(tempDir.getPath(), "invalid.py");
    
    // Test validation using PyValidator
    import utils.python.pycheck;
    
    auto validResult = PyValidator.validate([validPath]);
    Assert.isTrue(validResult.success, "Valid Python should pass");
    
    auto invalidResult = PyValidator.validate([invalidPath]);
    Assert.isFalse(invalidResult.success, "Invalid Python should fail");
    Assert.notEmpty(invalidResult.firstError());
    
    writeln("\x1b[32m  ✓ Python syntax validation works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.python - Build executable");
    
    auto tempDir = scoped(new TempDir("python-test"));
    
    tempDir.createFile("app.py", `
#!/usr/bin/env python3
def main():
    print("Hello from app")

if __name__ == "__main__":
    main()
`);
    
    // Create target and config
    auto target = TargetBuilder.create("//app:main")
        .withType(TargetType.Executable)
        .withSources([buildPath(tempDir.getPath(), "app.py")])
        .build();
    target.language = TargetLanguage.Python;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    config.options.outputDir = buildPath(tempDir.getPath(), "bin");
    
    auto handler = new PythonHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk);
    if (result.isOk)
    {
        auto outputHash = result.unwrap();
        Assert.notEmpty(outputHash);
    }
    
    writeln("\x1b[32m  ✓ Python executable build works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.python - Build library");
    
    auto tempDir = scoped(new TempDir("python-test"));
    
    tempDir.createFile("lib.py", `
def utility_function():
    return 42

class Helper:
    def __init__(self):
        self.value = 100
`);
    
    auto target = TargetBuilder.create("//lib:utils")
        .withType(TargetType.Library)
        .withSources([buildPath(tempDir.getPath(), "lib.py")])
        .build();
    target.language = TargetLanguage.Python;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    
    auto handler = new PythonHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk);
    if (result.isOk)
    {
        auto outputHash = result.unwrap();
        Assert.notEmpty(outputHash);
    }
    
    writeln("\x1b[32m  ✓ Python library build works\x1b[0m");
}

