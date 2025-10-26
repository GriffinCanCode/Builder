# PHP Language Support

Comprehensive, modular PHP language support for Builder with first-class support for modern PHP ecosystem tools and patterns.

## Architecture

This module follows a clean, modular architecture matching the Python/TypeScript patterns in the codebase:

```
php/
├── core/            # Core handler and configuration
│   ├── handler.d    # Main PHPHandler orchestrator
│   ├── config.d     # Configuration types and enums
│   └── package.d    # Public exports
├── managers/        # Package and dependency management
│   ├── composer.d   # Composer.json parsing and PSR-4 validation
│   └── package.d    # Public exports
├── tooling/         # Development tools and utilities
│   ├── detection.d  # Tool detection and availability
│   ├── info.d       # PHP version and capability detection
│   ├── formatters/  # Code formatting
│   │   ├── base.d           # Formatter interface and factory
│   │   ├── phpcsfixer.d     # PHP-CS-Fixer integration
│   │   ├── phpcs.d          # PHP_CodeSniffer integration
│   │   └── package.d        # Public exports
│   ├── packagers/   # Distribution and PHAR creation
│   │   ├── base.d           # Packager interface and factory
│   │   ├── box.d            # Box PHAR builder (modern)
│   │   ├── pharcc.d         # pharcc standalone binary
│   │   ├── phar.d           # Native PHP Phar class
│   │   └── package.d        # Public exports
│   └── package.d    # Public exports
├── analysis/        # Static analysis
│   ├── base.d       # Analyzer interface and factory
│   ├── phpstan.d    # PHPStan integration (levels 0-9)
│   ├── psalm.d      # Psalm integration (security-focused)
│   ├── phan.d       # Phan integration (advanced inference)
│   └── package.d    # Public exports
├── package.d        # Main module exports
└── README.md        # This file
```

## Design Philosophy

### Modularity

The architecture separates concerns into distinct, focused modules:
- **core/** - Essential handler and configuration logic
- **managers/** - External dependency management (Composer)
- **tooling/** - Development and build tools
- **analysis/** - Static analysis and type checking

### Extensibility

Each component uses interfaces and factory patterns:
- New analyzers can be added without modifying existing code
- Tool detection is automatic with fallback strategies
- Configuration supports auto-detection and explicit specification

### Auto-Detection

Intelligent detection of project configuration:
- Scan for tool configuration files (e.g., `phpstan.neon`, `.php-cs-fixer.php`)
- Check tool availability (global vs vendor/bin)
- Detect project structure and conventions

### Type Safety

Strong typing throughout:
- Comprehensive enums for all option types
- Structured configuration with validation
- Result types with detailed error information

## Features

### 🎯 Build Modes

- **Script** - Single file execution with syntax validation
- **Application** - Multi-file with Composer autoloading
- **Library** - Reusable package with PSR-4 validation
- **PHAR** - Single executable archive
- **Package** - Composer distributable with validation
- **FrankenPHP** - Standalone binary with embedded server

### 🔍 Static Analysis

Three major static analyzers with auto-detection:

**PHPStan** - Most popular, level-based analysis (0-9)
- Progressive strictness levels
- Baseline support for incremental adoption
- Memory limit configuration
- Project-wide analysis

**Psalm** - Security-focused with advanced type inference
- Security vulnerability detection
- Advanced type system
- Auto-initialization support

**Phan** - Advanced inference engine
- Deep type inference
- Dead code detection
- Cross-file analysis

### ✨ Code Formatting

**PHP-CS-Fixer** - Modern, configurable (recommended)
- PSR-1, PSR-2, PSR-12 standards
- Custom rule configuration
- Dry-run mode for CI/CD
- Risky rule support

**PHP_CodeSniffer** - Traditional PSR compliance
- Multiple PSR standards
- Auto-fixing with phpcbf
- Custom rulesets
- Detailed violation reports

### 📦 PHAR Packaging

**Box** - Modern PHAR builder (recommended)
- JSON configuration
- Advanced compression (GZ, BZ2)
- Multiple signature algorithms
- Compactors and optimization

**pharcc** - Compile to standalone binary
- No PHP required on target
- Self-contained executables
- Cross-platform support

**Native** - Built-in PHP Phar class
- Always available
- Direct control
- Simple configuration

### 🧪 Testing Frameworks

- **PHPUnit** - Industry standard unit testing
- **Pest** - Modern, elegant testing DSL
- **Codeception** - Full-stack testing
- **Behat** - Behavior-driven development

### 🔧 Composer Integration

Full Composer support:
- Auto-install dependencies
- Lock file validation
- Autoloader optimization (authoritative, APCu)
- PSR-4 validation
- Extension requirement checking

### 🚀 Modern PHP Features

Version-aware capability detection:
- PHP 8.0+: Attributes, union types, named arguments, match
- PHP 8.1+: Enums, fibers, readonly properties
- PHP 8.2+: DNF types, true type, readonly classes
- PHP 8.3+: Typed class constants, deep cloning

## Configuration

### Basic Example

```json
{
  "php": {
    "mode": "application",
    "phpVersion": "8.3",
    "composer": {
      "autoInstall": true,
      "optimizeAutoloader": true
    }
  }
}
```

### Full Configuration Example

```json
{
  "php": {
    "mode": "phar",
    "phpVersion": {
      "major": 8,
      "minor": 3
    },
    "composer": {
      "autoInstall": true,
      "optimizeAutoloader": true,
      "authoritative": true
    },
    "analysis": {
      "enabled": true,
      "analyzer": "phpstan",
      "level": 8
    },
    "formatter": {
      "enabled": true,
      "formatter": "php-cs-fixer",
      "psrStandard": "PSR-12"
    },
    "test": {
      "framework": "phpunit",
      "coverage": true
    },
    "phar": {
      "tool": "box",
      "outputFile": "app.phar",
      "compression": "gz"
    }
  }
}
```

## Usage Examples

### Application with Composer

```
target("php-app") {
    type: executable;
    language: php;
    sources: ["src/app.php"];
    php: {
        mode: "application",
        composer: { autoInstall: true }
    };
}
```

### Library with Analysis

```
target("php-lib") {
    type: library;
    language: php;
    sources: ["src/**/*.php"];
    php: {
        mode: "library",
        analysis: { enabled: true, level: 8 },
        formatter: { enabled: true }
    };
}
```

### PHAR Distribution

```
target("php-phar") {
    type: executable;
    language: php;
    sources: ["src/**/*.php"];
    php: {
        mode: "phar",
        phar: {
            tool: "box",
            outputFile: "app.phar",
            compression: "gz"
        }
    };
}
```

## Module Organization

Following the Python/TypeScript pattern, the PHP module is organized by responsibility:

- **core/** - Core functionality that other modules depend on
- **managers/** - External system integration (Composer)
- **tooling/** - Development and build tools
- **analysis/** - Code quality and static analysis

This structure makes it easy to:
- Find related functionality
- Add new tools without modifying existing code
- Test components in isolation
- Understand dependencies between modules

## Installation

Recommended tools:

```bash
# Static analysis
composer require --dev phpstan/phpstan

# Code formatting
composer require --dev friendsofphp/php-cs-fixer

# Testing
composer require --dev phpunit/phpunit

# PHAR packaging
composer require --dev humbug/box
```

## Best Practices

1. **Use Composer autoloading** for any non-trivial project
2. **Enable static analysis** to catch bugs early
3. **Validate PSR-4 structure** for libraries
4. **Use Box for PHAR creation** (most feature-rich)
5. **Enable strict types** for better type safety
6. **Optimize autoloader** for production builds

## Comparison to Python Module

The PHP module structure mirrors the Python module for consistency:

| Python | PHP | Purpose |
|--------|-----|---------|
| `core/` | `core/` | Handler and configuration |
| `managers/` | `managers/` | Package managers (pip/uv → Composer) |
| `tooling/` | `tooling/` | Formatters, linters, detection |
| `analysis/` | `analysis/` | Dependency analysis → Static analysis |

This consistent structure makes it easier for contributors familiar with one language module to work with others.
