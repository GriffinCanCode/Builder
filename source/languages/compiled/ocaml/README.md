# OCaml Language Support

Comprehensive support for OCaml builds in the Builder build system.

## Overview

This module provides build support for OCaml projects, supporting multiple build systems including dune, ocamlopt, ocamlc, and ocamlbuild.

## Features

- **Multiple Build Systems**:
  - **dune**: Modern build system (auto-detected from `dune-project` or `dune` files)
  - **ocamlopt**: Native code compiler for optimized binaries
  - **ocamlc**: Bytecode compiler for portable executables
  - **ocamlbuild**: Traditional OCaml build system

- **Package Manager Integration**: opam integration for dependency management
- **Code Formatting**: Optional ocamlformat integration
- **Optimization Levels**: Support for O0, O1, O2, O3 optimization
- **Cross-compilation**: Native and bytecode targets
- **Library Support**: Static and dynamic library compilation

## Configuration

Configure OCaml targets in your Builderfile using the `ocaml` key:

```d
target("my-ocaml-app") {
    type: executable;
    language: ocaml;
    sources: ["src/**/*.ml"];
    
    config: {
        "compiler": "dune",           // auto, dune, ocamlopt, ocamlc, ocamlbuild
        "optimize": "2",              // 0, 1, 2, 3
        "outputType": "executable",   // executable, library, bytecode, native
        "profile": "release",         // dev, release (for dune)
        "libs": ["str", "unix"],     // Libraries to link
        "runFormat": true,            // Run ocamlformat
        "debugInfo": false            // Include debug symbols
    };
}
```

## Configuration Options

### Compiler Selection

- `compiler`: Choose the build system
  - `"auto"`: Auto-detect (prefer dune if available)
  - `"dune"`: Use dune build system
  - `"ocamlopt"`: Use native compiler directly
  - `"ocamlc"`: Use bytecode compiler
  - `"ocamlbuild"`: Use ocamlbuild

### Optimization

- `optimize`: Optimization level (0-3)
  - `"0"` or `"none"`: No optimization
  - `"1"`: Basic optimization
  - `"2"`: Standard optimization (default)
  - `"3"`: Aggressive optimization

### Output Configuration

- `outputType`: Type of output to generate
  - `"executable"`: Native executable (default)
  - `"library"`: Library file
  - `"bytecode"`: Bytecode executable
  - `"native"`: Native code

- `outputDir`: Output directory (default: `_build` for dune, `bin` for others)
- `outputName`: Custom output filename

### Build Options

- `entry`: Entry point file (auto-detected as `main.ml` if not specified)
- `includeDirs`: Include directories (`-I` flags)
- `libDirs`: Library directories (`-L` flags)
- `libs`: Libraries to link
- `compilerFlags`: Additional compiler flags
- `linkerFlags`: Additional linker flags

### Tooling

- `runFormat`: Run ocamlformat before building (default: `false`)
- `debugInfo`: Include debug information (default: `false`)
- `warnings`: Enable warnings (default: `true`)
- `warningsAsErrors`: Treat warnings as errors (default: `false`)
- `verbose`: Verbose output (default: `false`)

### Dune-Specific Options

- `profile`: Build profile (`"dev"` or `"release"`)
- `duneTargets`: Specific dune targets to build
- `duneWatch`: Enable watch mode (default: `false`)

### Package Management

- `useOpam`: Use opam environment (default: `true`)
- `installDeps`: Install dependencies before building (default: `false`)

## Examples

### Simple Executable with Auto-Detection

```d
target("hello") {
    type: executable;
    language: ocaml;
    sources: ["main.ml"];
}
```

### Dune Project

```d
target("my-app") {
    type: executable;
    language: ocaml;
    sources: ["src/**/*.ml"];
    
    config: {
        "compiler": "dune",
        "profile": "release",
        "runFormat": true
    };
}
```

### Native Compiler with Libraries

```d
target("network-tool") {
    type: executable;
    language: ocaml;
    sources: ["src/*.ml"];
    
    config: {
        "compiler": "ocamlopt",
        "optimize": "3",
        "libs": ["unix", "str", "threads"],
        "compilerFlags": ["-thread"]
    };
}
```

### Library Target

```d
target("mylib") {
    type: library;
    language: ocaml;
    sources: ["lib/**/*.ml"];
    
    config: {
        "compiler": "dune",
        "outputType": "library"
    };
}
```

## Prerequisites

### Installing OCaml

**Ubuntu/Debian:**
```bash
sudo apt install ocaml opam
opam init
opam install dune ocamlformat
```

**macOS:**
```bash
brew install ocaml opam
opam init
opam install dune ocamlformat
```

**Windows:**
Download from https://ocaml.org/docs/install.html or use WSL

### Recommended Tools

- **opam**: OCaml package manager
- **dune**: Modern build system (`opam install dune`)
- **ocamlformat**: Code formatter (`opam install ocamlformat`)
- **merlin**: Editor integration (`opam install merlin`)
- **utop**: Enhanced REPL (`opam install utop`)

## Build System Detection

The handler automatically detects the appropriate build system:

1. If `dune-project` or `dune` file exists → use dune
2. If `_tags` file exists → use ocamlbuild
3. Otherwise, prefer ocamlopt if available
4. Fallback to ocamlc for bytecode compilation

You can override detection by explicitly setting the `compiler` config option.

## File Extensions

Supported OCaml file extensions:
- `.ml`: Implementation files
- `.mli`: Interface files
- `.mll`: Lexer files (ocamllex)
- `.mly`: Parser files (ocamlyacc/menhir)

## Common Issues

### "dune not found"
Install dune: `opam install dune`

### "ocamlopt not available"
The native compiler may not be installed. Install it with opam or use bytecode compiler:
```json
{
    "compiler": "ocamlc"
}
```

### Missing Libraries
Install libraries via opam: `opam install <library-name>`

### Format Issues
Install ocamlformat: `opam install ocamlformat`
Create `.ocamlformat` file in project root with formatting preferences

## Resources

- [OCaml Official Website](https://ocaml.org/)
- [Dune Documentation](https://dune.readthedocs.io/)
- [OCaml Manual](https://ocaml.org/manual/)
- [Real World OCaml](https://dev.realworldocaml.org/)
- [opam Package Manager](https://opam.ocaml.org/)


