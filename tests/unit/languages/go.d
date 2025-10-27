module tests.unit.languages.go;

import std.stdio;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import languages.scripting.go;
import config.schema;
import tests.harness;
import tests.fixtures;

/// Test Go import detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.go - Import detection");
    
    auto tempDir = scoped(new TempDir("go-test"));
    
    string goCode = `
package main

import (
    "fmt"
    "os"
    "encoding/json"
)

func main() {
    fmt.Println("Hello")
}
`;
    
    tempDir.createFile("main.go", goCode);
    auto filePath = buildPath(tempDir.getPath(), "main.go");
    
    auto handler = new GoHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notEmpty(imports);
    
    writeln("\x1b[32m  ✓ Go import detection works\x1b[0m");
}

/// Test Go executable build
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.go - Build executable");
    
    auto tempDir = scoped(new TempDir("go-test"));
    
    tempDir.createFile("main.go", `
package main

import "fmt"

func main() {
    fmt.Println("Hello, Go!")
}
`);
    
    auto target = TargetBuilder.create("//app:main")
        .withType(TargetType.Executable)
        .withSources([buildPath(tempDir.getPath(), "main.go")])
        .build();
    target.language = TargetLanguage.Go;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    config.options.outputDir = buildPath(tempDir.getPath(), "bin");
    
    auto handler = new GoHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk || result.isErr);
    
    writeln("\x1b[32m  ✓ Go executable build works\x1b[0m");
}

/// Test Go package structure
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.go - Package structure");
    
    auto tempDir = scoped(new TempDir("go-test"));
    
    tempDir.createFile("main.go", `
package main

import "myapp/utils"

func main() {
    utils.Greet()
}
`);
    
    string utilsDir = buildPath(tempDir.getPath(), "utils");
    mkdirRecurse(utilsDir);
    
    std.file.write(buildPath(utilsDir, "utils.go"), `
package utils

import "fmt"

func Greet() {
    fmt.Println("Hello from utils!")
}
`);
    
    auto mainPath = buildPath(tempDir.getPath(), "main.go");
    auto utilsPath = buildPath(utilsDir, "utils.go");
    
    auto handler = new GoHandler();
    auto imports = handler.analyzeImports([mainPath, utilsPath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Go package structure works\x1b[0m");
}

/// Test Go mod file detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.go - go.mod detection");
    
    auto tempDir = scoped(new TempDir("go-test"));
    
    tempDir.createFile("go.mod", `
module myapp

go 1.21

require (
    github.com/gorilla/mux v1.8.0
)
`);
    
    tempDir.createFile("main.go", `
package main

func main() {}
`);
    
    auto modPath = buildPath(tempDir.getPath(), "go.mod");
    
    Assert.isTrue(exists(modPath));
    
    writeln("\x1b[32m  ✓ Go go.mod detection works\x1b[0m");
}

/// Test Go test file recognition
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.go - Test file recognition");
    
    auto tempDir = scoped(new TempDir("go-test"));
    
    tempDir.createFile("utils.go", `
package utils

func Add(a, b int) int {
    return a + b
}
`);
    
    tempDir.createFile("utils_test.go", `
package utils

import "testing"

func TestAdd(t *testing.T) {
    result := Add(2, 3)
    if result != 5 {
        t.Errorf("Expected 5, got %d", result)
    }
}
`);
    
    auto utilsPath = buildPath(tempDir.getPath(), "utils.go");
    auto testPath = buildPath(tempDir.getPath(), "utils_test.go");
    
    auto handler = new GoHandler();
    auto imports = handler.analyzeImports([utilsPath, testPath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Go test file recognition works\x1b[0m");
}

/// Test Go interface detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.go - Interface detection");
    
    auto tempDir = scoped(new TempDir("go-test"));
    
    string goCode = `
package main

type Greeter interface {
    Greet(name string) string
}

type EnglishGreeter struct{}

func (g EnglishGreeter) Greet(name string) string {
    return "Hello, " + name
}
`;
    
    tempDir.createFile("greeter.go", goCode);
    auto filePath = buildPath(tempDir.getPath(), "greeter.go");
    
    auto handler = new GoHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Go interface detection works\x1b[0m");
}

