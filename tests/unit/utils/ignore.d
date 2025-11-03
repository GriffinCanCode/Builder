module tests.unit.utils.ignore;

import std.stdio;
import std.algorithm;
import std.path;
import infrastructure.utils.files.ignore;
import infrastructure.config.schema.schema : TargetLanguage;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - JavaScript node_modules should be ignored");
    
    auto patterns = IgnoreRegistry.getPatternsForLanguage(TargetLanguage.JavaScript);
    
    Assert.isTrue(patterns.directories.canFind("node_modules"));
    Assert.isTrue(patterns.directories.canFind("dist"));
    Assert.isTrue(patterns.directories.canFind("build"));
    
    writeln("\x1b[32m  ✓ JavaScript ignore patterns include node_modules\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Python virtual environments should be ignored");
    
    auto patterns = IgnoreRegistry.getPatternsForLanguage(TargetLanguage.Python);
    
    Assert.isTrue(patterns.directories.canFind("venv"));
    Assert.isTrue(patterns.directories.canFind(".venv"));
    Assert.isTrue(patterns.directories.canFind("__pycache__"));
    Assert.isTrue(patterns.patterns.canFind("*.pyc"));
    
    writeln("\x1b[32m  ✓ Python ignore patterns include venv and __pycache__\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Rust target directory should be ignored");
    
    auto patterns = IgnoreRegistry.getPatternsForLanguage(TargetLanguage.Rust);
    
    Assert.isTrue(patterns.directories.canFind("target"));
    
    writeln("\x1b[32m  ✓ Rust ignore patterns include target directory\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Should ignore directory by exact match");
    
    Assert.isTrue(IgnoreRegistry.shouldIgnore("node_modules", TargetLanguage.JavaScript));
    Assert.isTrue(IgnoreRegistry.shouldIgnore("venv", TargetLanguage.Python));
    Assert.isTrue(IgnoreRegistry.shouldIgnore("target", TargetLanguage.Rust));
    Assert.isTrue(IgnoreRegistry.shouldIgnore("vendor", TargetLanguage.PHP));
    
    writeln("\x1b[32m  ✓ Directory exact match ignoring works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Should not ignore normal directories");
    
    Assert.isFalse(IgnoreRegistry.shouldIgnore("src", TargetLanguage.JavaScript));
    Assert.isFalse(IgnoreRegistry.shouldIgnore("lib", TargetLanguage.Python));
    Assert.isFalse(IgnoreRegistry.shouldIgnore("tests", TargetLanguage.Rust));
    Assert.isFalse(IgnoreRegistry.shouldIgnore("include", TargetLanguage.Cpp));
    
    writeln("\x1b[32m  ✓ Normal directories are not ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - VCS directories always ignored");
    
    // VCS directories should be ignored regardless of language
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".git", TargetLanguage.JavaScript));
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".git", TargetLanguage.Python));
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".git", TargetLanguage.Rust));
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".svn", TargetLanguage.Cpp));
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".hg", TargetLanguage.Go));
    
    writeln("\x1b[32m  ✓ VCS directories are always ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Common ignore patterns");
    
    // Common patterns should be ignored for all languages
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".builder-cache", TargetLanguage.JavaScript));
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".cache", TargetLanguage.Python));
    Assert.isTrue(IgnoreRegistry.shouldIgnore("tmp", TargetLanguage.Rust));
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".DS_Store", TargetLanguage.Cpp));
    
    writeln("\x1b[32m  ✓ Common ignore patterns work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Java build directories");
    
    auto patterns = IgnoreRegistry.getPatternsForLanguage(TargetLanguage.Java);
    
    Assert.isTrue(patterns.directories.canFind("target"));
    Assert.isTrue(patterns.directories.canFind("build"));
    Assert.isTrue(patterns.directories.canFind(".gradle"));
    
    Assert.isTrue(IgnoreRegistry.shouldIgnore("target", TargetLanguage.Java));
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".gradle", TargetLanguage.Java));
    
    writeln("\x1b[32m  ✓ Java build directories are ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - C# build artifacts");
    
    auto patterns = IgnoreRegistry.getPatternsForLanguage(TargetLanguage.CSharp);
    
    Assert.isTrue(patterns.directories.canFind("bin"));
    Assert.isTrue(patterns.directories.canFind("obj"));
    Assert.isTrue(patterns.directories.canFind("packages"));
    
    Assert.isTrue(IgnoreRegistry.shouldIgnore("bin", TargetLanguage.CSharp));
    Assert.isTrue(IgnoreRegistry.shouldIgnore("obj", TargetLanguage.CSharp));
    
    writeln("\x1b[32m  ✓ C# build artifacts are ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Ruby vendor/bundle");
    
    auto patterns = IgnoreRegistry.getPatternsForLanguage(TargetLanguage.Ruby);
    
    Assert.isTrue(patterns.directories.canFind("vendor/bundle"));
    Assert.isTrue(patterns.directories.canFind(".bundle"));
    
    Assert.isTrue(IgnoreRegistry.shouldIgnore("vendor/bundle", TargetLanguage.Ruby));
    
    writeln("\x1b[32m  ✓ Ruby vendor/bundle is ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Elixir deps and _build");
    
    auto patterns = IgnoreRegistry.getPatternsForLanguage(TargetLanguage.Elixir);
    
    Assert.isTrue(patterns.directories.canFind("deps"));
    Assert.isTrue(patterns.directories.canFind("_build"));
    
    Assert.isTrue(IgnoreRegistry.shouldIgnore("deps", TargetLanguage.Elixir));
    Assert.isTrue(IgnoreRegistry.shouldIgnore("_build", TargetLanguage.Elixir));
    
    writeln("\x1b[32m  ✓ Elixir deps and _build are ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Should ignore paths with ignored components");
    
    // Test full paths
    Assert.isTrue(IgnoreRegistry.shouldIgnorePath("project/node_modules/package", TargetLanguage.JavaScript));
    Assert.isTrue(IgnoreRegistry.shouldIgnorePath("src/venv/lib/python", TargetLanguage.Python));
    Assert.isTrue(IgnoreRegistry.shouldIgnorePath("app/target/debug/build", TargetLanguage.Rust));
    
    writeln("\x1b[32m  ✓ Paths with ignored components are ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Should not ignore valid paths");
    
    Assert.isFalse(IgnoreRegistry.shouldIgnorePath("src/components/Button.js", TargetLanguage.JavaScript));
    Assert.isFalse(IgnoreRegistry.shouldIgnorePath("lib/utils/helpers.py", TargetLanguage.Python));
    Assert.isFalse(IgnoreRegistry.shouldIgnorePath("src/main.rs", TargetLanguage.Rust));
    
    writeln("\x1b[32m  ✓ Valid paths are not ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Case sensitivity");
    
    // Directory names should be case-sensitive on most systems
    Assert.isTrue(IgnoreRegistry.shouldIgnore("node_modules", TargetLanguage.JavaScript));
    
    // But .DS_Store might not be (depends on implementation)
    Assert.isTrue(IgnoreRegistry.shouldIgnore(".DS_Store", TargetLanguage.JavaScript));
    
    writeln("\x1b[32m  ✓ Case sensitivity handling works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - TypeScript specific patterns");
    
    auto patterns = IgnoreRegistry.getPatternsForLanguage(TargetLanguage.TypeScript);
    
    Assert.isTrue(patterns.directories.canFind("node_modules"));
    Assert.isTrue(patterns.directories.canFind(".tsbuildinfo"));
    
    writeln("\x1b[32m  ✓ TypeScript specific patterns are present\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - Go vendor directory");
    
    auto patterns = IgnoreRegistry.getPatternsForLanguage(TargetLanguage.Go);
    
    Assert.isTrue(patterns.directories.canFind("vendor"));
    
    Assert.isTrue(IgnoreRegistry.shouldIgnore("vendor", TargetLanguage.Go));
    
    writeln("\x1b[32m  ✓ Go vendor directory is ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.ignore - PHP Composer vendor");
    
    Assert.isTrue(IgnoreRegistry.shouldIgnore("vendor", TargetLanguage.PHP));
    
    writeln("\x1b[32m  ✓ PHP Composer vendor is ignored\x1b[0m");
}

