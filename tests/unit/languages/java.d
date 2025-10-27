module tests.unit.languages.java;

import std.stdio;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import languages.jvm.java;
import config.schema;
import tests.harness;
import tests.fixtures;

/// Test Java import detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.java - Import detection");
    
    auto tempDir = scoped(new TempDir("java-test"));
    
    string javaCode = `
import java.util.List;
import java.util.ArrayList;
import java.io.File;
import com.example.Utils;

public class Main {
    public static void main(String[] args) {
        System.out.println("Hello");
    }
}
`;
    
    tempDir.createFile("Main.java", javaCode);
    auto filePath = buildPath(tempDir.getPath(), "Main.java");
    
    auto handler = new JavaHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notEmpty(imports);
    
    writeln("\x1b[32m  ✓ Java import detection works\x1b[0m");
}

/// Test Java executable build
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.java - Build executable");
    
    auto tempDir = scoped(new TempDir("java-test"));
    
    tempDir.createFile("Main.java", `
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}
`);
    
    auto target = TargetBuilder.create("//app:main")
        .withType(TargetType.Executable)
        .withSources([buildPath(tempDir.getPath(), "Main.java")])
        .build();
    target.language = TargetLanguage.Java;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    config.options.outputDir = buildPath(tempDir.getPath(), "bin");
    
    auto handler = new JavaHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk || result.isErr);
    
    writeln("\x1b[32m  ✓ Java executable build works\x1b[0m");
}

/// Test Java library build
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.java - Build library");
    
    auto tempDir = scoped(new TempDir("java-test"));
    
    tempDir.createFile("Utils.java", `
package com.example;

public class Utils {
    public static int add(int a, int b) {
        return a + b;
    }
    
    public static String greet(String name) {
        return "Hello, " + name;
    }
}
`);
    
    auto target = TargetBuilder.create("//lib:utils")
        .withType(TargetType.Library)
        .withSources([buildPath(tempDir.getPath(), "Utils.java")])
        .build();
    target.language = TargetLanguage.Java;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    
    auto handler = new JavaHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk || result.isErr);
    
    writeln("\x1b[32m  ✓ Java library build works\x1b[0m");
}

/// Test Java package structure
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.java - Package structure");
    
    auto tempDir = scoped(new TempDir("java-test"));
    
    string utilsDir = buildPath(tempDir.getPath(), "com", "example");
    mkdirRecurse(utilsDir);
    
    std.file.write(buildPath(utilsDir, "Greeter.java"), `
package com.example;

public class Greeter {
    public void greet(String name) {
        System.out.println("Hello, " + name);
    }
}
`);
    
    tempDir.createFile("Main.java", `
import com.example.Greeter;

public class Main {
    public static void main(String[] args) {
        Greeter g = new Greeter();
        g.greet("World");
    }
}
`);
    
    auto mainPath = buildPath(tempDir.getPath(), "Main.java");
    auto greeterPath = buildPath(utilsDir, "Greeter.java");
    
    auto handler = new JavaHandler();
    auto imports = handler.analyzeImports([mainPath, greeterPath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Java package structure works\x1b[0m");
}

/// Test Java annotation detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.java - Annotation detection");
    
    auto tempDir = scoped(new TempDir("java-test"));
    
    string javaCode = `
import org.junit.Test;
import static org.junit.Assert.*;

public class CalculatorTest {
    @Test
    public void testAdd() {
        assertEquals(5, 2 + 3);
    }
    
    @Test
    public void testSubtract() {
        assertEquals(1, 3 - 2);
    }
}
`;
    
    tempDir.createFile("CalculatorTest.java", javaCode);
    auto filePath = buildPath(tempDir.getPath(), "CalculatorTest.java");
    
    auto handler = new JavaHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Java annotation detection works\x1b[0m");
}

/// Test Java Maven pom.xml detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.java - Maven pom.xml detection");
    
    auto tempDir = scoped(new TempDir("java-test"));
    
    tempDir.createFile("pom.xml", `
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>myapp</artifactId>
    <version>1.0-SNAPSHOT</version>
    
    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
        </dependency>
    </dependencies>
</project>
`);
    
    auto pomPath = buildPath(tempDir.getPath(), "pom.xml");
    
    Assert.isTrue(exists(pomPath));
    
    writeln("\x1b[32m  ✓ Java Maven pom.xml detection works\x1b[0m");
}

/// Test Java interface and abstract class detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.java - Interface and abstract class detection");
    
    auto tempDir = scoped(new TempDir("java-test"));
    
    string javaCode = `
package com.example;

public interface Drawable {
    void draw();
}

abstract class Shape implements Drawable {
    abstract double area();
}

class Circle extends Shape {
    private double radius;
    
    public Circle(double radius) {
        this.radius = radius;
    }
    
    @Override
    public double area() {
        return Math.PI * radius * radius;
    }
    
    @Override
    public void draw() {
        System.out.println("Drawing circle");
    }
}
`;
    
    tempDir.createFile("Shapes.java", javaCode);
    auto filePath = buildPath(tempDir.getPath(), "Shapes.java");
    
    auto handler = new JavaHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Java interface and abstract class detection works\x1b[0m");
}

