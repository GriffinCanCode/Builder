# Builder Documentation

This directory contains all documentation for the Builder project, organized into the following categories:

## 📚 Directory Structure

### [`user-guides/`](./user-guides)
User-facing documentation and guides:
- **cli.md** - Command-line interface reference
- **examples.md** - Usage examples and tutorials
- **ignore.md** - Configuration for ignoring files
- **lsp.md** - Language Server Protocol integration
- **testing.md** - Testing guide for users
- **watch.md** - Watch mode documentation
- **wizard.md** - Interactive wizard guide

### [`architecture/`](./architecture)
Design and architecture documentation:
- **overview.md** - Overall system architecture
- **dsl.md** - Domain-specific language specification
- **plugins.md** - Plugin system design
- **cachedesign.md** - Action cache design principles
- **workstealing.md** - Work-stealing scheduler design

### [`features/`](./features)
Specific feature implementations and technical details:
- **caching.md** - Action caching implementation
- **coordinator.md** - Cache coordinator system
- **graphcache.md** - Graph caching mechanism
- **parsecache.md** - Parse result caching
- **remotecache.md** - Remote caching support
- **distributed.md** - Distributed builds
- **observability.md** - Observability and monitoring
- **health.md** - Health check system
- **telemetry.md** - Telemetry collection
- **watch.md** - Watch mode implementation
- **recovery.md** - Error recovery mechanisms
- **performance.md** - Performance optimizations
- **concurrency.md** - Concurrency and parallelization
- **simd.md** - SIMD optimizations
- **simdhash.md** - SIMD hashing implementation
- **blake3.md** - BLAKE3 hashing details
- **languages.md** - Language separation (JS/TS)

### [`security/`](./security)
Security and safety documentation:
- **security.md** - Security guidelines and practices

### [`api/`](./api)
Auto-generated API documentation (HTML)

### [`examples/`](./examples)
Code examples and samples

### [`ddoc/`](./ddoc)
DDoc documentation templates

## 🚀 Quick Start

New to Builder? Start here:
1. [CLI Guide](./user-guides/cli.md) - Learn the command-line interface
2. [Examples](./user-guides/examples.md) - See Builder in action
3. [Architecture](./architecture/overview.md) - Understand how it works

## 🔍 Finding Documentation

- **For Users**: Check the `user-guides/` directory
- **For Contributors**: See `architecture/` for design docs
- **For Security Researchers**: Review `security/` documentation
- **For Feature Details**: Explore `features/` for technical implementations

