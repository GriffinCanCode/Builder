# Languages Package

The languages package provides language-specific build handlers and dependency analysis for multiple programming languages.

## Modules

### Core
- **base.d** - Base language interface and factory

### Supported Languages
- **python.d** - Python with pip and virtual environments
- **javascript.d** - JavaScript/Node.js with npm/yarn
- **go.d** - Go with modules support
- **rust.d** - Rust with Cargo
- **java.d** - Java with Maven/Gradle
- **cpp.d** - C++ with various build systems
- **csharp.d** - C# with .NET
- **ruby.d** - Ruby with Bundler
- **php.d** - PHP with Composer
- **swift.d** - Swift with SPM
- **kotlin.d** - Kotlin with Gradle
- **scala.d** - Scala with sbt
- **elixir.d** - Elixir with Mix
- **lua.d** - Lua language support
- **nim.d** - Nim language support
- **zig.d** - Zig language support

## Usage

```d
import languages;

auto handler = LanguageFactory.create("python");
auto deps = handler.analyzeDependencies(sourceFile);
handler.build(target);
```

## Key Features

- Automatic dependency detection per language
- Language-specific build command generation
- Support for language-specific package managers
- Incremental compilation support
- Cross-language dependency handling

