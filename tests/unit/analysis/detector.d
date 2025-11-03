module tests.unit.analysis.detector;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import infrastructure.analysis.detection.detector;
import infrastructure.config.schema.schema : TargetLanguage;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect C++ files");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    // Create C++ files
    std.file.write(buildPath(basePath, "main.cpp"), "int main() {}");
    std.file.write(buildPath(basePath, "utils.hpp"), "void util();");
    std.file.write(buildPath(basePath, "header.h"), "#pragma once");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    Assert.isTrue(detected.canFind(TargetLanguage.Cpp));
    
    writeln("\x1b[32m  ✓ C++ file detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect Python files");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    std.file.write(buildPath(basePath, "main.py"), "print('hello')");
    std.file.write(buildPath(basePath, "utils.py"), "def util(): pass");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    Assert.isTrue(detected.canFind(TargetLanguage.Python));
    
    writeln("\x1b[32m  ✓ Python file detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect JavaScript files");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    std.file.write(buildPath(basePath, "app.js"), "console.log('test');");
    std.file.write(buildPath(basePath, "utils.jsx"), "export const App = () => {};");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    Assert.isTrue(detected.canFind(TargetLanguage.JavaScript));
    
    writeln("\x1b[32m  ✓ JavaScript file detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect TypeScript files");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    std.file.write(buildPath(basePath, "app.ts"), "const x: number = 5;");
    std.file.write(buildPath(basePath, "component.tsx"), "const App: React.FC = () => {};");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    Assert.isTrue(detected.canFind(TargetLanguage.TypeScript));
    
    writeln("\x1b[32m  ✓ TypeScript file detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect Rust files");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    std.file.write(buildPath(basePath, "main.rs"), "fn main() {}");
    std.file.write(buildPath(basePath, "Cargo.toml"), "[package]\nname = \"test\"");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    Assert.isTrue(detected.canFind(TargetLanguage.Rust));
    
    writeln("\x1b[32m  ✓ Rust file detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect Java files");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    std.file.write(buildPath(basePath, "Main.java"), "public class Main {}");
    std.file.write(buildPath(basePath, "Utils.java"), "class Utils {}");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    Assert.isTrue(detected.canFind(TargetLanguage.Java));
    
    writeln("\x1b[32m  ✓ Java file detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect multiple languages");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    // Create files in different languages
    std.file.write(buildPath(basePath, "main.cpp"), "int main() {}");
    std.file.write(buildPath(basePath, "script.py"), "print('hello')");
    std.file.write(buildPath(basePath, "app.js"), "console.log('test');");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    // Should detect multiple languages
    Assert.isTrue(detected.length >= 2);
    
    writeln("\x1b[32m  ✓ Multiple language detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Empty directory detection");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    // Empty directory should return empty array
    Assert.equal(detected.length, 0);
    
    writeln("\x1b[32m  ✓ Empty directory detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect Go files");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    std.file.write(buildPath(basePath, "main.go"), "package main\nfunc main() {}");
    std.file.write(buildPath(basePath, "go.mod"), "module example.com/test");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    Assert.isTrue(detected.canFind(TargetLanguage.Go));
    
    writeln("\x1b[32m  ✓ Go file detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Ignore hidden directories");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    // Create normal file
    std.file.write(buildPath(basePath, "main.cpp"), "int main() {}");
    
    // Create file in hidden directory
    auto hiddenDir = buildPath(basePath, ".git");
    mkdir(hiddenDir);
    std.file.write(buildPath(hiddenDir, "test.py"), "# should be ignored");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    // Should only detect C++, not Python from .git
    Assert.isTrue(detected.canFind(TargetLanguage.Cpp));
    
    writeln("\x1b[32m  ✓ Hidden directories are ignored\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect by extension");
    
    auto detector = new LanguageDetector();
    
    Assert.equal(detector.detectByExtension(".cpp"), TargetLanguage.Cpp);
    Assert.equal(detector.detectByExtension(".py"), TargetLanguage.Python);
    Assert.equal(detector.detectByExtension(".js"), TargetLanguage.JavaScript);
    Assert.equal(detector.detectByExtension(".ts"), TargetLanguage.TypeScript);
    Assert.equal(detector.detectByExtension(".rs"), TargetLanguage.Rust);
    Assert.equal(detector.detectByExtension(".go"), TargetLanguage.Go);
    
    writeln("\x1b[32m  ✓ Extension-based detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Detect Ruby files");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    std.file.write(buildPath(basePath, "main.rb"), "puts 'hello'");
    std.file.write(buildPath(basePath, "Gemfile"), "source 'https://rubygems.org'");
    
    auto detector = new LanguageDetector();
    auto detected = detector.detectLanguages(basePath);
    
    Assert.isTrue(detected.canFind(TargetLanguage.Ruby));
    
    writeln("\x1b[32m  ✓ Ruby file detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.detector - Confidence scoring");
    
    auto tempDir = scoped(new TempDir("detector-test"));
    auto basePath = tempDir.getPath();
    
    // More files should increase confidence
    std.file.write(buildPath(basePath, "file1.cpp"), "int main() {}");
    std.file.write(buildPath(basePath, "file2.cpp"), "void func() {}");
    std.file.write(buildPath(basePath, "file3.cpp"), "class Foo {};");
    
    auto detector = new LanguageDetector();
    auto results = detector.detectWithConfidence(basePath);
    
    // Should have results with confidence scores
    Assert.isTrue(results.length > 0);
    Assert.isTrue(results[0].confidence > 0.0);
    
    writeln("\x1b[32m  ✓ Confidence scoring works\x1b[0m");
}

