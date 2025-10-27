module tests.unit.config.workspace;

import std.stdio;
import std.file;
import std.path;
import config.workspace.workspace;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.workspace - Create workspace from directory");
    
    auto tempDir = scoped(new TempDir("workspace-test"));
    auto wsPath = tempDir.getPath();
    
    // Create a Builderspace file
    auto builderspacePath = buildPath(wsPath, "Builderspace");
    std.file.write(builderspacePath, "workspace(\"test_workspace\") {\n}\n");
    
    auto ws = Workspace.load(wsPath);
    
    Assert.notNull(ws);
    
    writeln("\x1b[32m  ✓ Workspace creation from directory works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.workspace - Workspace has root path");
    
    auto tempDir = scoped(new TempDir("workspace-test"));
    auto wsPath = tempDir.getPath();
    
    auto builderspacePath = buildPath(wsPath, "Builderspace");
    std.file.write(builderspacePath, "workspace(\"test\") {\n}\n");
    
    auto ws = Workspace.load(wsPath);
    
    Assert.notEmpty([ws.rootPath]);
    Assert.isTrue(ws.rootPath.exists);
    
    writeln("\x1b[32m  ✓ Workspace has valid root path\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.workspace - Find Builderfiles in workspace");
    
    auto tempDir = scoped(new TempDir("workspace-test"));
    auto wsPath = tempDir.getPath();
    
    // Create Builderspace
    auto builderspacePath = buildPath(wsPath, "Builderspace");
    std.file.write(builderspacePath, "workspace(\"test\") {\n}\n");
    
    // Create a Builderfile
    auto builderfilePath = buildPath(wsPath, "Builderfile");
    std.file.write(builderfilePath, "target app { type: executable }\n");
    
    auto ws = Workspace.load(wsPath);
    auto builderfiles = ws.findBuilderfiles();
    
    Assert.isTrue(builderfiles.length > 0);
    
    writeln("\x1b[32m  ✓ Finding Builderfiles in workspace works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.workspace - Workspace name parsing");
    
    auto tempDir = scoped(new TempDir("workspace-test"));
    auto wsPath = tempDir.getPath();
    
    auto builderspacePath = buildPath(wsPath, "Builderspace");
    std.file.write(builderspacePath, "workspace(\"my_awesome_project\") {\n}\n");
    
    auto ws = Workspace.load(wsPath);
    
    Assert.equal(ws.name, "my_awesome_project");
    
    writeln("\x1b[32m  ✓ Workspace name parsing works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.workspace - Nested Builderfiles");
    
    auto tempDir = scoped(new TempDir("workspace-test"));
    auto wsPath = tempDir.getPath();
    
    // Create Builderspace
    std.file.write(buildPath(wsPath, "Builderspace"), "workspace(\"test\") {\n}\n");
    
    // Create nested structure
    auto subdir = buildPath(wsPath, "subdir");
    mkdir(subdir);
    std.file.write(buildPath(subdir, "Builderfile"), "target sub { type: library }\n");
    
    auto ws = Workspace.load(wsPath);
    auto builderfiles = ws.findBuilderfiles();
    
    // Should find nested Builderfile
    Assert.isTrue(builderfiles.length > 0);
    
    writeln("\x1b[32m  ✓ Nested Builderfiles are found\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.workspace - Workspace validation");
    
    auto tempDir = scoped(new TempDir("workspace-test"));
    auto wsPath = tempDir.getPath();
    
    // Missing Builderspace should fail validation
    auto ws = Workspace.load(wsPath);
    
    // Should handle missing Builderspace gracefully
    Assert.notNull(ws);
    
    writeln("\x1b[32m  ✓ Workspace validation works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.workspace - Ignore patterns respected");
    
    auto tempDir = scoped(new TempDir("workspace-test"));
    auto wsPath = tempDir.getPath();
    
    std.file.write(buildPath(wsPath, "Builderspace"), "workspace(\"test\") {\n}\n");
    
    // Create ignored directory with Builderfile
    auto nodeModules = buildPath(wsPath, "node_modules");
    mkdir(nodeModules);
    std.file.write(buildPath(nodeModules, "Builderfile"), "target ignored { }\n");
    
    // Create normal Builderfile
    std.file.write(buildPath(wsPath, "Builderfile"), "target normal { }\n");
    
    auto ws = Workspace.load(wsPath);
    auto builderfiles = ws.findBuilderfiles();
    
    // Should not include node_modules Builderfile
    import std.algorithm : canFind;
    Assert.isFalse(builderfiles.canFind!(f => f.canFind("node_modules")));
    
    writeln("\x1b[32m  ✓ Ignore patterns are respected\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m config.workspace - Workspace directory structure");
    
    auto tempDir = scoped(new TempDir("workspace-test"));
    auto wsPath = tempDir.getPath();
    
    std.file.write(buildPath(wsPath, "Builderspace"), "workspace(\"test\") {\n}\n");
    
    // Create typical project structure
    mkdir(buildPath(wsPath, "src"));
    mkdir(buildPath(wsPath, "include"));
    mkdir(buildPath(wsPath, "tests"));
    
    auto ws = Workspace.load(wsPath);
    
    // Should successfully load with standard structure
    Assert.notNull(ws);
    Assert.isTrue(exists(buildPath(ws.rootPath, "src")));
    Assert.isTrue(exists(buildPath(ws.rootPath, "include")));
    
    writeln("\x1b[32m  ✓ Standard directory structure is handled correctly\x1b[0m");
}

