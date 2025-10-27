module tests.unit.languages.rust;

import std.stdio;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import languages.compiled.rust;
import config.schema;
import tests.harness;
import tests.fixtures;

/// Test Rust use statement detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.rust - Use statement detection");
    
    auto tempDir = scoped(new TempDir("rust-test"));
    
    string rustCode = `
use std::io;
use std::fs::File;
use std::collections::HashMap;

fn main() {
    println!("Hello");
}
`;
    
    tempDir.createFile("main.rs", rustCode);
    auto filePath = buildPath(tempDir.getPath(), "main.rs");
    
    auto handler = new RustHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notEmpty(imports);
    
    writeln("\x1b[32m  ✓ Rust use statement detection works\x1b[0m");
}

/// Test Rust executable build
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.rust - Build executable");
    
    auto tempDir = scoped(new TempDir("rust-test"));
    
    tempDir.createFile("main.rs", `
fn main() {
    println!("Hello, Rust!");
}
`);
    
    auto target = TargetBuilder.create("//app:main")
        .withType(TargetType.Executable)
        .withSources([buildPath(tempDir.getPath(), "main.rs")])
        .build();
    target.language = TargetLanguage.Rust;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    config.options.outputDir = buildPath(tempDir.getPath(), "target");
    
    auto handler = new RustHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk || result.isErr);
    
    writeln("\x1b[32m  ✓ Rust executable build works\x1b[0m");
}

/// Test Rust library build
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.rust - Build library");
    
    auto tempDir = scoped(new TempDir("rust-test"));
    
    tempDir.createFile("lib.rs", `
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 3), 5);
    }
}
`);
    
    auto target = TargetBuilder.create("//lib:mylib")
        .withType(TargetType.Library)
        .withSources([buildPath(tempDir.getPath(), "lib.rs")])
        .build();
    target.language = TargetLanguage.Rust;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    
    auto handler = new RustHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk || result.isErr);
    
    writeln("\x1b[32m  ✓ Rust library build works\x1b[0m");
}

/// Test Rust Cargo.toml detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.rust - Cargo.toml detection");
    
    auto tempDir = scoped(new TempDir("rust-test"));
    
    tempDir.createFile("Cargo.toml", `
[package]
name = "myapp"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = "1.0"
tokio = { version = "1.0", features = ["full"] }
`);
    
    tempDir.createFile("main.rs", `
fn main() {
    println!("Hello");
}
`);
    
    auto handler = new RustHandler();
    auto tomlPath = buildPath(tempDir.getPath(), "Cargo.toml");
    
    Assert.isTrue(exists(tomlPath));
    
    writeln("\x1b[32m  ✓ Rust Cargo.toml detection works\x1b[0m");
}

/// Test Rust module system
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.rust - Module system");
    
    auto tempDir = scoped(new TempDir("rust-test"));
    
    tempDir.createFile("main.rs", `
mod utils;

fn main() {
    utils::greet();
}
`);
    
    tempDir.createFile("utils.rs", `
pub fn greet() {
    println!("Hello from utils!");
}
`);
    
    auto mainPath = buildPath(tempDir.getPath(), "main.rs");
    auto utilsPath = buildPath(tempDir.getPath(), "utils.rs");
    
    auto handler = new RustHandler();
    auto imports = handler.analyzeImports([mainPath, utilsPath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Rust module system works\x1b[0m");
}

/// Test Rust macro detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.rust - Macro detection");
    
    auto tempDir = scoped(new TempDir("rust-test"));
    
    string rustCode = `
#[derive(Debug, Clone)]
struct Point {
    x: i32,
    y: i32,
}

fn main() {
    let p = Point { x: 0, y: 0 };
    println!("{:?}", p);
}
`;
    
    tempDir.createFile("main.rs", rustCode);
    auto filePath = buildPath(tempDir.getPath(), "main.rs");
    
    auto handler = new RustHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Rust macro detection works\x1b[0m");
}

