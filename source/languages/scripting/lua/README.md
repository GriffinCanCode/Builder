# Lua Language Support

Comprehensive, modular Lua language support for the Builder build system with first-class support for Lua's unique features and ecosystem.

## Architecture

This module follows a clean, modular architecture inspired by the Go/JavaScript/TypeScript patterns in the codebase:

```
lua/
├── core/
│   ├── config.d         # Configuration types, enums, and JSON parsing
│   ├── handler.d        # Main orchestrator - delegates to specialized components
│   └── package.d        # Public exports
├── managers/
│   ├── luarocks.d       # LuaRocks package manager integration
│   └── package.d        # Public exports
├── tooling/
│   ├── detection.d      # Runtime and tool detection
│   ├── builders/        # Build strategy implementations
│   │   ├── base.d       # Builder interface and factory
│   │   ├── script.d     # Script execution with wrapper generation
│   │   ├── bytecode.d   # Bytecode compilation with luac
│   │   ├── luajit.d     # LuaJIT JIT compilation and bytecode
│   │   └── package.d    # Public exports
│   ├── formatters/      # Code formatting
│   │   ├── base.d       # Formatter interface and factory
│   │   ├── stylua.d     # StyLua formatter implementation
│   │   └── package.d    # Public exports
│   ├── checkers/        # Static analysis and linting
│   │   ├── base.d       # Checker interface and factory
│   │   ├── luacheck.d   # Luacheck linter implementation
│   │   └── package.d    # Public exports
│   ├── testers/         # Test frameworks
│   │   ├── base.d       # Tester interface and factory
│   │   ├── busted.d     # Busted test framework (BDD-style)
│   │   ├── luaunit.d    # LuaUnit test framework (xUnit-style)
│   │   └── package.d    # Public exports
│   └── package.d        # Public exports
├── analysis/
│   ├── dependencies.d   # require() analysis and dependency resolution
│   └── package.d        # Public exports
├── package.d            # Main public exports
└── README.md            # This file
```

## Features

### 🎯 Core Capabilities

- **Multiple Runtimes**: Lua 5.1, 5.2, 5.3, 5.4, LuaJIT with auto-detection
- **Build Modes**: Script, Bytecode, Library, Rock, Application
- **Package Management**: Full LuaRocks integration
- **Bytecode Compilation**: Standard luac and LuaJIT bytecode support
- **Dependency Analysis**: Automatic require() detection and resolution

### 🛠️ Tooling Integration

- **StyLua**: Modern, opinionated code formatter
- **Luacheck**: Comprehensive static analyzer and linter
- **Busted**: Elegant BDD-style test framework
- **LuaUnit**: xUnit-style test framework
- **LuaRocks**: Package manager with rockspec support

### 🚀 Advanced Features

- **Runtime Detection**: Auto-detect best available Lua interpreter
- **Wrapper Generation**: Automatic executable wrapper scripts
- **Coverage Support**: Test coverage with luacov
- **FFI Support**: LuaJIT Foreign Function Interface
- **Optimization**: Bytecode optimization levels and JIT tuning

## Configuration

### DSL Format

```dsl
target("my-app") {
    type: executable;
    language: lua;
    sources: ["main.lua", "utils.lua"];
    
    lua: {
        mode: "script",
        runtime: "luajit",
        
        // LuaJIT options
        luajit: {
            enabled: true,
            optLevel: 3,
            enableFFI: true
        },
        
        // Code quality
        lint: {
            enabled: true,
            linter: "luacheck",
            luacheck: {
                std: "lua54",
                maxLineLength: 120
            }
        },
        
        format: {
            autoFormat: true,
            formatter: "stylua"
        },
        
        // Testing
        test: {
            framework: "busted",
            coverage: true
        },
        
        // LuaRocks dependencies
        luarocks: {
            enabled: true,
            autoInstall: true,
            dependencies: ["lpeg", "luasocket"]
        }
    };
}
```

### JSON Format

```json
{
    "name": "my-app",
    "type": "executable",
    "language": "lua",
    "sources": ["main.lua"],
    "lua": {
        "mode": "script",
        "runtime": "luajit",
        "luajit": {
            "enabled": true,
            "optLevel": 3,
            "enableFFI": true
        },
        "lint": {
            "enabled": true,
            "linter": "luacheck"
        },
        "format": {
            "autoFormat": true
        }
    }
}
```

## Configuration Options

### Build Modes

- `script` - Interpreted execution with wrapper (default)
- `bytecode` - Compiled bytecode with luac
- `library` - Reusable Lua module
- `rock` - LuaRocks package
- `application` - Multi-file application with dependencies

### Runtime Selection

- `auto` - Auto-detect best available (default)
- `lua51` - Lua 5.1
- `lua52` - Lua 5.2
- `lua53` - Lua 5.3
- `lua54` - Lua 5.4 (latest standard)
- `luajit` - LuaJIT (fastest)
- `system` - System default Lua

### Bytecode Configuration

```json
{
    "bytecode": {
        "compile": true,
        "optLevel": "full",
        "stripDebug": true,
        "outputFile": "app.luac"
    }
}
```

### LuaJIT Configuration

```json
{
    "luajit": {
        "enabled": true,
        "optLevel": 3,
        "enableFFI": true,
        "bytecode": true,
        "jitOptions": ["opt.start(3)"]
    }
}
```

### Linting Configuration

```json
{
    "lint": {
        "enabled": true,
        "linter": "luacheck",
        "failOnWarning": false,
        "luacheck": {
            "std": "lua54",
            "globals": ["app", "config"],
            "maxLineLength": 120,
            "maxComplexity": 15
        }
    }
}
```

### Formatting Configuration

```json
{
    "format": {
        "autoFormat": true,
        "formatter": "stylua",
        "checkOnly": false,
        "stylua": {
            "columnWidth": 120,
            "indentType": "Spaces",
            "indentWidth": 4,
            "quoteStyle": "AutoPreferDouble"
        }
    }
}
```

### Testing Configuration

```json
{
    "test": {
        "framework": "busted",
        "verbose": true,
        "coverage": true,
        "coverageTool": "luacov",
        "minCoverage": 80.0,
        "busted": {
            "format": "default",
            "shuffle": false,
            "failFast": false,
            "tags": ["unit", "integration"]
        }
    }
}
```

### LuaRocks Configuration

```json
{
    "luarocks": {
        "enabled": true,
        "autoInstall": true,
        "local": true,
        "tree": "./lua_modules",
        "dependencies": [
            "lpeg",
            "luasocket >= 3.0",
            "luafilesystem"
        ],
        "devDependencies": [
            "busted",
            "luacheck"
        ]
    }
}
```

## Usage Examples

### Simple Script

```dsl
target("hello") {
    type: executable;
    language: lua;
    sources: ["hello.lua"];
}
```

### LuaJIT Optimized Application

```dsl
target("fast-app") {
    type: executable;
    language: lua;
    sources: ["main.lua", "lib.lua"];
    
    lua: {
        runtime: "luajit",
        luajit: {
            enabled: true,
            optLevel: 3,
            enableFFI: true
        }
    };
}
```

### Bytecode Compilation

```dsl
target("compiled-app") {
    type: executable;
    language: lua;
    sources: ["main.lua"];
    
    lua: {
        mode: "bytecode",
        bytecode: {
            compile: true,
            optLevel: "full",
            stripDebug: true
        }
    };
}
```

### Library with Quality Tools

```dsl
target("mylib") {
    type: library;
    language: lua;
    sources: ["lib.lua", "utils.lua"];
    
    lua: {
        mode: "library",
        
        lint: {
            enabled: true,
            linter: "luacheck",
            failOnWarning: true
        },
        
        format: {
            autoFormat: true,
            formatter: "stylua"
        }
    };
}

target("mylib-test") {
    type: test;
    language: lua;
    sources: ["test_lib.lua"];
    deps: [":mylib"];
    
    lua: {
        test: {
            framework: "busted",
            coverage: true,
            verbose: true
        }
    };
}
```

### Rock with LuaRocks

```dsl
target("myrock") {
    type: library;
    language: lua;
    sources: ["src/myrock.lua"];
    
    lua: {
        mode: "rock",
        luarocks: {
            enabled: true,
            rockspecFile: "myrock-1.0-1.rockspec",
            dependencies: ["lpeg", "luasocket"]
        }
    };
}
```

### Production Build

```dsl
target("prod-app") {
    type: executable;
    language: lua;
    sources: ["main.lua"];
    
    lua: {
        runtime: "luajit",
        mode: "bytecode",
        
        luajit: {
            enabled: true,
            bytecode: true,
            optLevel: 3
        },
        
        bytecode: {
            stripDebug: true,
            optLevel: "full"
        },
        
        lint: {
            enabled: true,
            failOnWarning: true
        },
        
        format: {
            autoFormat: true
        },
        
        luarocks: {
            enabled: true,
            autoInstall: true,
            local: false
        }
    };
}
```

## Design Principles

### 1. **Modularity**
Each component has a single, well-defined responsibility:
- `core/`: Configuration and orchestration
- `managers/`: Package management (LuaRocks)
- `tooling/`: Builders, formatters, linters, testers
- `analysis/`: Dependency analysis

### 2. **Extensibility**
New tools can be added easily by implementing interfaces:
- New builders: Implement `LuaBuilder` interface
- New formatters: Implement `Formatter` interface
- New linters: Implement `Checker` interface
- New test frameworks: Implement `Tester` interface

### 3. **Type Safety**
Strong typing throughout with enums for all options. Configuration is validated at parse time.

### 4. **Auto-Detection**
Smart defaults based on available tools:
- Runtime detection (LuaJIT > Lua 5.4 > ... > System Lua)
- Formatter detection (StyLua > lua-format)
- Linter detection (Luacheck > Selene)
- Test framework detection (Busted > LuaUnit)

### 5. **Composability**
Components can be mixed and matched. Configuration is layered and overridable.

## Performance Considerations

- **LuaJIT**: Up to 10-50x faster than standard Lua
- **Bytecode**: Smaller files, faster loading
- **Optimization Levels**: Fine-grained control over compilation
- **Caching**: Leverage Builder's build cache for incremental builds

## Best Practices

1. **Use LuaJIT for production**: Significantly faster execution
2. **Enable linting**: Catch errors early with Luacheck
3. **Format code**: Use StyLua for consistent style
4. **Write tests**: Use Busted or LuaUnit with coverage
5. **Manage dependencies**: Use LuaRocks for third-party modules
6. **Compile bytecode**: For distribution and faster loading
7. **Version lock**: Specify exact Lua version requirements

## Tooling Requirements

### Required
- Lua interpreter (any version) or LuaJIT

### Optional (Auto-detected)
- `luac` - Standard Lua compiler (for bytecode mode)
- `luajit` - LuaJIT compiler (for luajit mode)
- `luarocks` - Package manager (for dependency management)
- `stylua` - Code formatter
- `luacheck` - Static analyzer/linter
- `busted` - Test framework
- `luacov` - Coverage tool

## Installation

### Lua/LuaJIT
```bash
# macOS
brew install lua luajit

# Ubuntu/Debian
sudo apt-get install lua5.4 luajit

# Arch
sudo pacman -S lua luajit
```

### LuaRocks
```bash
# macOS
brew install luarocks

# Ubuntu/Debian
sudo apt-get install luarocks

# Manual
wget https://luarocks.org/releases/luarocks-3.9.2.tar.gz
tar -xzf luarocks-3.9.2.tar.gz
cd luarocks-3.9.2
./configure && make && sudo make install
```

### Tooling
```bash
# Install via LuaRocks
luarocks install --server=https://luarocks.org/dev busted
luarocks install luacheck
luarocks install luacov

# Install StyLua (via cargo)
cargo install stylua
```

## Troubleshooting

**Problem**: Module not found
- **Solution**: Check package paths, install with LuaRocks, or specify custom paths

**Problem**: Bytecode compilation fails
- **Solution**: Ensure luac is installed, check Lua version compatibility

**Problem**: LuaJIT FFI errors
- **Solution**: Check C library availability, verify FFI is enabled

**Problem**: Tests not found
- **Solution**: Specify test paths explicitly, check test pattern matching

**Problem**: Luacheck reports false positives
- **Solution**: Configure globals, adjust warning levels, use .luacheckrc

## Integration with Builder

This module integrates seamlessly with Builder's:
- Dependency graph system
- Incremental builds and caching
- Parallel execution
- Error handling and recovery
- Cross-language dependency support

## Future Enhancements

Potential additions:
- Lua 5.5 support (when released)
- Additional test frameworks (Telescope, TestMore)
- Additional linters (Selene)
- Moonscript transpilation support
- Teal type checking integration
- Luau (Roblox Lua) support
- Lua Language Server integration

## Contributing

When extending this module:
1. Follow the established patterns (see core/, tooling/)
2. Keep files small and focused (<500 lines)
3. Add comprehensive configuration options
4. Maintain strong typing
5. Update this README
6. Add tests

## References

- [Lua Official](https://www.lua.org/)
- [LuaJIT](https://luajit.org/)
- [LuaRocks](https://luarocks.org/)
- [StyLua](https://github.com/JohnnyMorganz/StyLua)
- [Luacheck](https://github.com/mpeterv/luacheck)
- [Busted](https://olivinelabs.com/busted/)
- [LuaUnit](https://github.com/bluebird75/luaunit)

