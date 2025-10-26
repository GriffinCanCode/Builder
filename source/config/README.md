# Config Package

The config package handles build configuration parsing, workspace management, and DSL interpretation for the Builder system.

## Modules

- **lexer.d** - Lexical analysis for the BUILD DSL
- **parser.d** - Parsing BUILD and BUILD.json files
- **ast.d** - Abstract syntax tree representations
- **dsl.d** - DSL interpretation and evaluation
- **schema.d** - Configuration schema definitions
- **workspace.d** - Workspace and project management

## Usage

```d
import config;

auto workspace = new Workspace("path/to/project");
auto buildConfig = parseConfig("BUILD.json");
auto targets = buildConfig.getTargets();
```

## Key Features

- Support for both BUILD and BUILD.json formats
- Type-safe configuration schema
- Workspace-level configuration management
- DSL with variable expansion and functions
- Validation and error reporting

