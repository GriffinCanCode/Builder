# Analysis Package

The analysis package provides dependency resolution and build graph analysis capabilities for the Builder system.

## Modules

- **scanner.d** - File and dependency scanning utilities
- **resolver.d** - Dependency resolution algorithms
- **types.d** - Type definitions for analysis operations
- **analyzer.d** - Build target analysis and optimization
- **spec.d** - Build specification handling
- **metagen.d** - Metadata generation for build artifacts

## Usage

```d
import analysis;

auto scanner = new DependencyScanner();
auto deps = scanner.scan(sourceFiles);

auto resolver = new DependencyResolver();
auto resolved = resolver.resolve(deps);
```

## Key Features

- Fast dependency scanning with parallel file processing
- Intelligent dependency resolution with cycle detection
- Type-safe analysis operations
- Build specification validation
- Metadata generation for caching

