# Python Language Support

Comprehensive, modular Python language support for Builder with modern tooling integration.

## Architecture

### Core Modules

- **handler.d** - Main `PythonHandler` class implementing build logic
- **config.d** - Configuration structs and enums for all Python features
- **tools.d** - Tool detection and availability checking
- **environments.d** - Virtual environment management (venv, virtualenv, conda, poetry)
- **packages.d** - Package manager abstraction (pip, uv, poetry, PDM, hatch, conda)
- **checker.d** - Type checking integration (mypy, pyright, pytype, pyre)
- **formatter.d** - Code formatting and linting (ruff, black, pylint, flake8)
- **dependencies.d** - Dependency analysis from various file formats

## Features

### Build Modes

- **Script** - Single file or simple module (default)
- **Library** - Importable package with validation
- **Package** - Distributable package with setup
- **Wheel** - Built wheel distribution
- **Application** - Standalone application with executable wrapper

### Package Managers

Automatic detection and support for:
- **uv** - Ultra-fast Rust-based package installer (recommended for speed)
- **pip** - Standard package manager
- **poetry** - Modern dependency management with lock files
- **PDM** - PEP 582 support
- **hatch** - Modern project management
- **conda** - Scientific computing environments
- **pipenv** - Pipfile-based workflow

Priority: uv > poetry (if detected) > pip

### Virtual Environments

- **Automatic detection and creation**
- **venv** (standard library)
- **virtualenv** (extended features)
- **conda** environments
- **poetry** managed environments
- **Intelligent activation** with proper PATH and environment setup

### Type Checking

Integrated type checking with:
- **mypy** - Most comprehensive, standard
- **pyright** - Microsoft's fast type checker
- **pytype** - Google's inference-based checker
- **pyre** - Facebook's performance-focused checker

Configurable strictness, ignore patterns, and error handling.

### Code Quality

**Formatters:**
- **ruff** - Fastest (Rust-based, recommended)
- **black** - Most popular, opinionated
- **blue** - Less strict black fork
- **yapf** - Google's configurable formatter
- **autopep8** - PEP 8 focused

**Linters:**
- **ruff** - Fastest, most comprehensive (Rust-based, recommended)
- **pylint** - Most comprehensive
- **flake8** - Combines multiple tools
- **bandit** - Security-focused
- **pyflakes** - Simple and fast

### Testing

Support for:
- **pytest** - Most popular (default if available)
- **unittest** - Standard library
- **nose2** - Extended unittest
- **tox** - Multi-environment testing

Features:
- Coverage reporting (HTML, XML, JSON)
- Parallel test execution
- Verbose/quiet modes
- Minimum coverage enforcement

### Dependency Analysis

Parse dependencies from:
- **requirements.txt**
- **pyproject.toml** (PEP 621, Poetry, PDM, Hatch)
- **setup.py**
- **Pipfile**
- **environment.yml** (conda)

### Smart Entry Points

Automatic detection of:
- `if __name__ == "__main__"` guards
- `main()` function presence
- Direct script execution
- Intelligent wrapper generation for executables

### Performance Optimizations

- **Batch validation** using Python AST (single process, not per-file)
- **Fast package installation** with uv (10-100x faster than pip)
- **Bytecode compilation** support for production
- **Efficient environment reuse**

## Configuration Example

```d
target("app") {
    type: executable;
    language: python;
    sources: ["src/main.py", "src/utils.py"];
    
    python: {
        // Python version
        pythonVersion: "3.11",
        
        // Virtual environment
        venv: {
            enabled: true,
            path: ".venv",
            autoCreate: true
        },
        
        // Package manager (auto-detects best available)
        packageManager: "auto",  // or "uv", "poetry", "pip", etc.
        installDeps: true,
        
        // Type checking
        typeCheck: {
            enabled: true,
            checker: "auto",  // or "mypy", "pyright", etc.
            strict: true
        },
        
        // Code quality
        formatter: "ruff",  // or "black", "auto", etc.
        linter: "ruff",     // or "pylint", "flake8", etc.
        autoFormat: true,
        autoLint: true,
        
        // Testing
        test: {
            runner: "pytest",
            coverage: true,
            parallel: true,
            verbose: true
        },
        
        // Optimization
        compileBytecode: true,
        optimize: 2
    }
}
```

## Minimal Configuration

Most settings auto-detect intelligently:

```d
target("app") {
    type: executable;
    language: python;
    sources: ["main.py"];
    
    python: {
        installDeps: true  // Auto-detects package manager and requirements files
    }
}
```

## Design Principles

### 1. **Speed First**
- Prioritize fastest tools (uv, ruff, pyright)
- Batch operations where possible
- Minimal process spawning

### 2. **Smart Defaults**
- Auto-detection of project structure
- Intelligent fallbacks
- Minimal configuration required

### 3. **Comprehensive Coverage**
- Support all major package managers
- Support all popular tools
- Handle all project types

### 4. **Modular Architecture**
- Each module has single responsibility
- Easy to extend with new tools
- Clean separation of concerns

### 5. **Type Safety**
- Strong typing with enums
- Configuration validation
- Clear error messages

## Tool Detection Priority

**Package Managers:**
1. uv (fastest)
2. poetry (if pyproject.toml detected)
3. pip (default)

**Type Checkers:**
1. pyright (fastest)
2. mypy (most complete)
3. pytype

**Formatters:**
1. ruff (fastest)
2. black (most popular)

**Linters:**
1. ruff (fastest, most comprehensive)
2. pylint (most thorough)
3. flake8 (good default)

## Novel Features

### 1. **UV Integration**
First build system to integrate uv - the fastest Python package installer (10-100x faster than pip).

### 2. **Batch AST Validation**
Validates all Python files in single process using AST parsing, avoiding expensive per-file process spawning.

### 3. **Intelligent Wrapper Generation**
Analyzes entry point patterns to generate optimal executable wrappers.

### 4. **Unified Tool Abstraction**
Consistent interface across all package managers, type checkers, formatters, and linters.

### 5. **Smart Environment Detection**
Automatically detects and uses appropriate virtual environment tools based on project structure.

## Performance Characteristics

- **Validation**: O(1) process for N files (batch AST parsing)
- **Package Install**: 10-100x faster with uv vs pip
- **Type Checking**: Pyright is ~5x faster than mypy
- **Linting**: Ruff is 10-100x faster than pylint
- **Formatting**: Ruff is 10-100x faster than black

## Future Enhancements

- [ ] Integration with Python build backends (setuptools, hatch, poetry-core)
- [ ] Wheel building and distribution
- [ ] PyPI publishing
- [ ] Multi-version testing matrix
- [ ] Dependency resolution and lock file generation
- [ ] Integration with pyenv for version management
- [ ] Cython compilation support
- [ ] PyInstaller/py2exe executable generation
- [ ] Docker container generation
- [ ] Lambda/serverless packaging

