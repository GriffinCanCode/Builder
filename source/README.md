# Builder Source Code

This directory contains the complete source code for the Builder build system, organized into modular packages.

## Package Structure

### 📦 [analysis/](analysis/)
Dependency resolution and build graph analysis
- Dependency scanning and resolution
- Type definitions and build specifications
- Metadata generation

### 🎨 [cli/](cli/)
Event-driven terminal rendering system
- Build events and progress tracking
- Terminal control and formatting
- Multi-stream output management

### ⚙️ [config/](config/)
Build configuration and workspace management
- Builderfile parsing (DSL and JSON)
- Configuration schema and validation
- Workspace management

### 🔧 [core/](core/)
Core build system engine
- Dependency graph construction
- Parallel task execution
- Build cache and artifact storage
- Cache eviction policies

### ⚠️ [errors/](errors/)
Type-safe error handling system
- Result<T, E> monad
- Error codes and types
- Rich error formatting
- Recovery strategies

### 🌐 [languages/](languages/)
Multi-language support
- 17+ programming languages
- Language-specific dependency analysis
- Build command generation

### 🛠️ [utils/](utils/)
Common utilities
- File operations (glob, hash, metadata)
- Parallel processing and thread pools
- Logging infrastructure
- Benchmarking tools

## Main Entry Point

**app.d** - Main application entry point that orchestrates all packages

## Usage

Each package can be imported individually or as a whole:

```d
// Import entire package
import analysis;

// Import specific module
import analysis.scanner;

// Import multiple packages
import core, config, errors;
```

## Package Organization

Each package follows the D package.d convention:
- `package.d` - Public imports and package documentation
- `README.md` - Detailed package documentation
- Module files - Individual implementation files

This structure allows for clean imports and modular architecture while maintaining clear separation of concerns.

## Building

The source is built using the Builder system itself. See the root `Builderfile` for build configuration.

## Testing

Tests are located in the `tests/` directory at the project root, mirroring the source structure.

