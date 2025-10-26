<!-- Comprehensive Ruby Language Support for Builder -->

# Ruby Language Support

Sophisticated, modular Ruby language handler with first-class support for Ruby's rich ecosystem and modern development practices.

## Architecture

Clean, testable architecture inspired by Python's module organization:

```
ruby/
├── core/           # Core orchestration
│   ├── handler.d   # RubyHandler - main build orchestrator
│   └── config.d    # Configuration types and enums
├── managers/       # Package and version management
│   ├── base.d      # PackageManager interface
│   ├── factory.d   # Auto-detection and factories
│   ├── bundler.d   # Bundler implementation
│   ├── rubygems.d  # RubyGems implementation
│   └── environments.d # Ruby version managers (rbenv, rvm, chruby, asdf)
├── analysis/       # Dependency analysis
│   └── dependencies.d # Gemfile/Gemfile.lock parsing
└── tooling/        # Development tools
    ├── info.d      # Tool availability detection
    ├── detection.d # Project type detection
    ├── results.d   # Result structures
    ├── checkers.d  # Type checkers (Sorbet, RBS, Steep)
    ├── formatters/ # Linting and formatting
    │   ├── base.d
    │   ├── rubocop.d
    │   └── standard.d
    └── builders/   # Build strategies
        ├── base.d
        ├── script.d
        ├── gem.d
        └── rails.d
```

## Features

### 📦 Package Management

Multiple package managers with intelligent auto-detection:

- **Bundler** - Industry standard (Gemfile/Gemfile.lock)
- **RubyGems** - Direct gem installation
- Auto-detection from project structure
- Gemfile/Gemfile.lock parsing
- Dependency resolution

### 🔧 Ruby Version Management

Support for all major Ruby version managers:

- **rbenv** - Lightweight, shim-based (most popular)
- **rvm** - Full-featured, function-based
- **chruby** - Minimal, elegant
- **asdf** - Multi-language version manager
- System Ruby fallback
- `.ruby-version` file support

### 🎯 Type Checking

Modern Ruby type systems:

- **Sorbet** - Stripe's gradual type checker (fast, production-ready)
- **RBS** - Ruby 3.0+ built-in type signatures
- **Steep** - RBS-based type checker
- Auto-detection and configuration

### ✨ Code Quality

Comprehensive formatting and linting:

- **RuboCop** - Configurable style guide enforcement
- **StandardRB** - Zero-config, opinionated formatter
- **Reek** - Code smell detection
- Auto-fix capabilities
- Custom rule configuration

### 🧪 Testing Frameworks

All major Ruby test frameworks:

- **RSpec** - BDD-style testing (most popular)
- **Minitest** - Standard library testing
- **Test::Unit** - Classic Ruby testing
- **Cucumber** - BDD with Gherkin
- Coverage analysis (SimpleCov)
- Parallel test execution

### 📚 Documentation Generation

Professional documentation tools:

- **YARD** - Modern, tag-based documentation
- **RDoc** - Standard library documentation
- Multiple output formats (HTML, Markdown)
- API documentation generation

### 🏗️ Build Modes

Specialized builders for different project types:

- **Script** - Single-file and simple applications
- **Gem** - Ruby library/gem building
- **Rails** - Ruby on Rails applications
- **Rack** - Rack-based web applications
- **CLI** - Command-line tools
- **Library** - Reusable Ruby code

### 🚂 Rails Integration

First-class Rails support:

- Database migrations
- Asset precompilation
- Environment management
- Test suite execution
- Rake task integration

## Usage Examples

### Basic Script

```d
target("ruby-script") {
    type: executable;
    language: ruby;
    sources: ["main.rb"];
}
```

### Rails Application

```d
target("rails-app") {
    type: executable;
    language: ruby;
    ruby: {
        mode: "rails",
        installDeps: true,
        rails: {
            environment: "production",
            precompileAssets: true,
            runMigrations: true
        }
    };
}
```

### Gem with Type Checking

```d
target("my-gem") {
    type: library;
    language: ruby;
    ruby: {
        mode: "gem",
        typeCheck: {
            enabled: true,
            checker: "sorbet",
            sorbet: {
                level: "strict"
            }
        },
        format: {
            formatter: "rubocop",
            autoFormat: true,
            autoCorrect: true
        }
    };
}
```

### RSpec Tests with Coverage

```d
target("tests") {
    type: test;
    language: ruby;
    sources: ["spec/**/*_spec.rb"];
    ruby: {
        test: {
            framework: "rspec",
            coverage: true,
            parallel: true,
            rspec: {
                format: "documentation",
                color: true,
                profile: true
            }
        }
    };
}
```

## Configuration

Comprehensive configuration options:

```d
ruby: {
    // Build mode
    mode: "script" | "gem" | "rails" | "rack" | "cli" | "library",
    
    // Ruby version
    rubyVersion: "3.3.0",
    versionManager: "auto" | "rbenv" | "rvm" | "chruby" | "asdf",
    
    // Package management
    packageManager: "auto" | "bundler" | "rubygems",
    installDeps: true,
    bundler: {
        path: "vendor/bundle",
        deployment: true,
        frozen: true,
        jobs: 4
    },
    
    // Type checking
    typeCheck: {
        enabled: true,
        checker: "sorbet" | "rbs" | "steep",
        strict: true
    },
    
    // Formatting and linting
    format: {
        formatter: "rubocop" | "standard" | "reek",
        autoFormat: true,
        autoCorrect: true,
        failOnWarning: false
    },
    
    // Testing
    test: {
        framework: "rspec" | "minitest" | "testunit" | "cucumber",
        coverage: true,
        parallel: true,
        verbose: true
    },
    
    // Documentation
    documentation: {
        generator: "yard" | "rdoc",
        outputDir: "doc"
    },
    
    // Rails-specific
    rails: {
        environment: "production",
        precompileAssets: true,
        runMigrations: true,
        seedDatabase: false
    }
}
```

## Design Philosophy

### 🎨 Elegance Through Modularity

- **Single Responsibility**: Each module has one clear purpose
- **Interface-Driven**: Abstract interfaces for extensibility
- **Factory Patterns**: Intelligent auto-detection and creation
- **Composition**: Build complex behavior from simple components

### ⚡ Performance Optimized

- Parallel gem installation (Bundler)
- Cached version manager detection
- Lazy tool initialization
- Efficient dependency parsing

### 🧪 Highly Testable

- Pure functions where possible
- Mockable interfaces
- Clear separation of concerns
- Minimal external dependencies

### 🔮 Future-Proof

- Support for emerging tools (Sorbet, RBS)
- Extensible architecture
- Backward compatible
- Version agnostic

## Advanced Features

### Intelligent Auto-Detection

The handler automatically detects:
- Project type (Rails, Gem, Script)
- Package manager (Bundler, RubyGems)
- Test framework (RSpec, Minitest)
- Ruby version manager
- Type checking system
- Code formatter preferences

### Bundler Integration

Full Bundler feature support:
- Gemfile/Gemfile.lock parsing
- Bundle exec integration
- Deployment mode
- Frozen lockfiles
- Without/with groups
- Path and git sources

### Version Manager Integration

Seamless integration with all major version managers:
- Automatic Ruby path resolution
- Version installation
- Local and global version setting
- `.ruby-version` file support

### Type System Support

Modern Ruby type checking:
- Sorbet RBI file generation
- RBS signature generation
- Steep configuration
- Gradual typing support

## Contributing

When extending Ruby support:

1. **Follow Python's Pattern**: Maintain the core/managers/tooling/analysis structure
2. **Use Interfaces**: Define interfaces before implementations
3. **Factory Pattern**: Use factories for auto-detection
4. **Result Types**: Return structured results (BuildResult, TypeCheckResult, etc.)
5. **Logging**: Use Logger for debug/info/warning/error messages
6. **Error Handling**: Graceful degradation, never crash

## See Also

- [Builder Architecture](../../ARCHITECTURE.md)
- [Python Module](../python/README.md) - Similar patterns
- [JavaScript Module](../javascript/README.md) - Bundler patterns
- [Go Module](../go/README.md) - Build strategies


