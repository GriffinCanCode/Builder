# Protocol Buffer Language Support

Comprehensive support for Protocol Buffer (.proto) files in the Builder build system.

## Overview

This module provides build support for Protocol Buffer files, enabling code generation for multiple target languages using `protoc` or the modern `buf` CLI.

## Features

- **Multi-Language Code Generation**: Generate code for C++, Java, Python, Go, Rust, JavaScript, TypeScript, and more
- **Compiler Support**: Works with both `protoc` (standard Google compiler) and `buf` (modern alternative)
- **Import Path Management**: Configure custom import paths for proto dependencies
- **Plugin Support**: Use protoc plugins for advanced code generation
- **Descriptor Sets**: Generate descriptor sets for runtime reflection
- **Linting & Formatting**: Optional integration with `buf lint` and `buf format`

## Configuration

Configure protobuf targets in your Builderfile using the `protobuf` or `proto` key:

```json
{
  "name": "my-protos",
  "type": "library",
  "language": "protobuf",
  "sources": ["src/**/*.proto"],
  "protobuf": {
    "compiler": "protoc",
    "outputLanguage": "cpp",
    "outputDir": "generated",
    "importPaths": ["third_party/protobuf"],
    "plugins": ["protoc-gen-grpc"],
    "generateDescriptor": true,
    "lint": true,
    "format": true
  }
}
```

## Configuration Options

### Compiler Options

- `compiler`: Compiler to use (`"auto"`, `"protoc"`, or `"buf"`) - default: `"auto"`
- `outputLanguage`: Target language for code generation - default: `"cpp"`
  - Supported: `cpp`, `csharp`, `java`, `kotlin`, `objc`, `php`, `python`, `ruby`, `go`, `rust`, `javascript`, `typescript`, `dart`, `swift`
- `outputDir`: Directory for generated code - default: workspace output directory
- `importPaths`: Additional import paths for proto files
- `plugins`: List of protoc plugins to use
- `pluginOptions`: Key-value options passed to plugins

### Descriptor Options

- `generateDescriptor`: Generate descriptor set file - default: `false`
- `descriptorPath`: Output path for descriptor set

### Quality Tools

- `lint`: Run buf linting (requires buf CLI) - default: `false`
- `format`: Run buf formatting (requires buf CLI) - default: `false`

## Output Languages

The following output languages are supported:

| Language | `outputLanguage` Value | Generated Extension |
|----------|----------------------|-------------------|
| C++ | `"cpp"` | `.pb.cc`, `.pb.h` |
| C# | `"csharp"` | `.cs` |
| Java | `"java"` | `.java` |
| Kotlin | `"kotlin"` | `.kt` |
| Objective-C | `"objc"` | `.pbobjc.h`, `.pbobjc.m` |
| PHP | `"php"` | `.php` |
| Python | `"python"` | `_pb2.py` |
| Ruby | `"ruby"` | `_pb.rb` |
| Go | `"go"` | `.pb.go` |
| Rust | `"rust"` | `.rs` |
| JavaScript | `"javascript"` | `.js` |
| TypeScript | `"typescript"` | `.ts` |
| Dart | `"dart"` | `.pb.dart` |
| Swift | `"swift"` | `.pb.swift` |

## Examples

### Basic C++ Generation

```json
{
  "name": "messages",
  "type": "library",
  "language": "protobuf",
  "sources": ["proto/messages.proto"],
  "protobuf": {
    "outputLanguage": "cpp",
    "outputDir": "generated/cpp"
  }
}
```

### Python with gRPC

```json
{
  "name": "api-protos",
  "type": "library",
  "language": "protobuf",
  "sources": ["api/**/*.proto"],
  "protobuf": {
    "outputLanguage": "python",
    "outputDir": "generated/python",
    "plugins": ["grpc_python_plugin"],
    "importPaths": ["third_party/googleapis"]
  }
}
```

### Go with Multiple Plugins

```json
{
  "name": "services",
  "type": "library",
  "language": "protobuf",
  "sources": ["services/**/*.proto"],
  "protobuf": {
    "outputLanguage": "go",
    "outputDir": "pkg/pb",
    "plugins": [
      "protoc-gen-go",
      "protoc-gen-go-grpc"
    ],
    "pluginOptions": {
      "go_opt": "paths=source_relative",
      "go-grpc_opt": "paths=source_relative"
    }
  }
}
```

### With Linting and Formatting

```json
{
  "name": "validated-protos",
  "type": "library",
  "language": "protobuf",
  "sources": ["proto/**/*.proto"],
  "protobuf": {
    "compiler": "buf",
    "outputLanguage": "java",
    "outputDir": "src/generated/java",
    "lint": true,
    "format": true
  }
}
```

## Installation

### Install protoc

**macOS (Homebrew):**
```bash
brew install protobuf
```

**Linux (apt):**
```bash
sudo apt install protobuf-compiler
```

**From source:**
Visit https://protobuf.dev/downloads/

### Install buf (Optional)

**macOS/Linux:**
```bash
brew install bufbuild/buf/buf
```

Or see: https://buf.build/docs/installation

## Import Analysis

The protobuf handler automatically analyzes proto imports for dependency tracking:

```protobuf
import "google/protobuf/timestamp.proto";  // External (well-known type)
import "common/types.proto";                // Relative import
import "/absolute/path/file.proto";        // Absolute import
```

## Architecture

```
protobuf/
├── core/
│   ├── config.d       # Configuration structures
│   ├── handler.d      # Main build handler
│   └── package.d
├── tooling/
│   ├── protoc.d       # protoc and buf compiler wrappers
│   └── package.d
├── analysis/
│   └── package.d      # Import analysis utilities
├── package.d
└── README.md
```

## Notes

- Proto files are compiled to generate code in the target language
- Generated files are placed in the configured output directory
- Import paths should include any directories containing imported proto files
- Plugins must be installed separately and available in PATH
- Descriptor sets are useful for runtime reflection and dynamic message handling

