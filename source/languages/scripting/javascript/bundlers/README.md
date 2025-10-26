# JavaScript Bundlers

This directory contains JavaScript/TypeScript bundler implementations for the Builder system.

## Architecture

### Design Principles

1. **Abstraction**: All bundlers implement the `Bundler` interface
2. **Extensibility**: New bundlers can be added without modifying existing code
3. **Auto-detection**: Factory pattern with intelligent bundler selection
4. **Configuration**: Unified configuration via `JSConfig` struct
5. **Flexibility**: Support for both CLI and config file modes

### Files

- **`base.d`**: Core `Bundler` interface and `BundlerFactory`
- **`config.d`**: Configuration types and enums
- **`esbuild.d`**: esbuild bundler implementation
- **`webpack.d`**: Webpack bundler implementation
- **`rollup.d`**: Rollup bundler implementation
- **`vite.d`**: Vite bundler implementation
- **`package.d`**: Public module exports

## Bundler Interface

```d
interface Bundler
{
    /// Bundle JavaScript files
    BundleResult bundle(
        string[] sources,
        JSConfig config,
        Target target,
        WorkspaceConfig workspace
    );
    
    /// Check if bundler is available on system
    bool isAvailable();
    
    /// Get bundler name
    string name() const;
    
    /// Get bundler version
    string getVersion();
}
```

## Bundler Implementations

### ESBuild (`esbuild.d`)

**Philosophy**: Speed and simplicity

**Features**:
- Fastest bundler (10-100x faster than others)
- Built-in TypeScript/JSX support
- Tree-shaking
- Code splitting
- Minification via esbuild's native minifier

**Best For**:
- General-purpose bundling
- Fast iteration cycles
- TypeScript/JSX projects
- When speed is critical

**Trade-offs**:
- Less plugin ecosystem than Webpack
- No UMD support (uses IIFE as fallback)
- Limited custom transformation options

**Implementation Details**:
- Direct CLI invocation
- All configuration via command-line flags
- No config file generation (pure CLI mode)

---

### Webpack (`webpack.d`)

**Philosophy**: Maximum flexibility and ecosystem

**Features**:
- Mature plugin ecosystem
- Advanced code splitting
- Hot Module Replacement (HMR)
- Asset management (images, fonts, etc.)
- Complex loader chains

**Best For**:
- Enterprise applications
- Complex build requirements
- Projects with custom loaders
- When you need maximum configurability

**Trade-offs**:
- Slower build times
- More complex configuration
- Larger memory footprint

**Implementation Details**:
- Generates temporary webpack.config.js
- JavaScript-based configuration
- Automatic cleanup of temp config
- Supports custom config files

---

### Rollup (`rollup.d`)

**Philosophy**: Library-focused with optimal tree-shaking

**Features**:
- Best tree-shaking in the industry
- Multiple output formats (ESM, CJS, UMD, IIFE)
- Plugin-based architecture
- Small bundle sizes

**Best For**:
- npm package distribution
- Library development
- When bundle size is critical
- Multiple output formats needed

**Trade-offs**:
- Slower than esbuild
- Less suited for applications
- Requires more configuration for complex apps

**Implementation Details**:
- Supports both CLI and config file modes
- Native UMD support
- Can auto-detect outputs from config

---

### Vite (`vite.d`)

**Philosophy**: Modern developer experience with framework-first approach

**Features**:
- Lightning-fast dev server with native ESM
- Instant Hot Module Replacement (HMR)
- Framework auto-detection (React, Vue, Svelte, Preact)
- Automatic plugin configuration
- Library mode with multiple formats
- Uses Rollup for production builds

**Best For**:
- React, Vue, Svelte applications
- Modern ESM-first projects
- Development with fast HMR
- Library development
- When developer experience is priority

**Trade-offs**:
- Requires npm dependencies for framework plugins
- Dev server mode not used in Builder (build-only)
- Slightly slower than esbuild for simple bundles

**Implementation Details**:
- Auto-detects vite.config.js/ts in project
- Generates temporary config when needed
- Framework detection via file extensions and package.json
- Automatic plugin injection based on framework
- Collects multiple outputs (JS, CSS, maps)

**Framework Detection**:
```d
// Detected via file extensions
.vue     → Vue plugin
.svelte  → Svelte plugin
.jsx/.tsx → React/Preact (checks package.json)

// Auto-configures appropriate Vite plugin
React   → @vitejs/plugin-react
Vue     → @vitejs/plugin-vue
Svelte  → @sveltejs/vite-plugin-svelte
Preact  → @preact/preset-vite
```

**Library Mode**:
Vite's library mode is automatically enabled when `mode: "library"`:
- Multiple format outputs (ESM, CJS, IIFE, UMD)
- External dependencies via `external` config
- Optimized for distribution

---

## Auto-Detection Strategy

The `BundlerFactory.createAuto()` method implements intelligent bundler selection:

```d
/// For library mode
if (config.mode == JSBuildMode.Library)
{
    // Priority: Vite → Rollup
    // Vite offers modern lib builds, Rollup for tree-shaking
}

/// For bundle/node mode
// Priority: esbuild → Vite → Webpack → Rollup
// esbuild fastest, Vite for frameworks, fallback to others
```

**Rationale**:
1. **esbuild first**: Fastest for general use
2. **Vite second**: Modern tooling, framework support
3. **Webpack third**: Mature, handles edge cases
4. **Rollup fourth**: Library-focused
5. **NullBundler**: Fallback (validation only)

## Configuration Mapping

### JSConfig → Bundler Options

All bundlers receive a unified `JSConfig` struct and map it to their specific CLI/config:

| JSConfig Field | esbuild | Webpack | Rollup | Vite |
|---------------|---------|---------|--------|------|
| `mode` | `--bundle` | `mode` | N/A | `build.lib` |
| `platform` | `--platform` | `target` | N/A | N/A |
| `format` | `--format` | `libraryTarget` | `--format` | `lib.formats` |
| `minify` | `--minify` | `mode: production` | Plugin | `build.minify` |
| `sourcemap` | `--sourcemap` | `devtool` | `--sourcemap` | `build.sourcemap` |
| `target` | `--target` | N/A | N/A | `esbuild.target` |
| `jsx` | `--jsx` | `module.rules` | Plugin | `esbuild.jsx` |
| `external` | `--external:*` | `externals` | `--external` | `rollupOptions.external` |
| `configFile` | N/A | `-c` | `-c` | `--config` |

## Adding a New Bundler

To add support for a new bundler (e.g., Parcel, Turbopack):

1. **Create implementation** (`newbundler.d`):
```d
module languages.scripting.javascript.bundlers.newbundler;

import languages.scripting.javascript.bundlers.base;
import languages.scripting.javascript.bundlers.config;

class NewBundler : Bundler
{
    BundleResult bundle(...) { /* implementation */ }
    bool isAvailable() { /* check if installed */ }
    string name() const { return "newbundler"; }
    string getVersion() { /* get version */ }
}
```

2. **Add to enum** (`config.d`):
```d
enum BundlerType
{
    // ... existing
    NewBundler,
}
```

3. **Update factory** (`base.d`):
```d
case BundlerType.NewBundler:
    return new NewBundler();
```

4. **Update parsing** (`config.d`):
```d
case "newbundler": config.bundler = BundlerType.NewBundler; break;
```

5. **Export module** (`package.d`):
```d
public import languages.scripting.javascript.bundlers.newbundler;
```

6. **Add tests** (`tests/unit/languages/javascript.d`)

## Testing

Test each bundler's:
- Availability detection
- Version retrieval
- Basic bundling
- Config file support
- Error handling
- Output generation

## Performance Characteristics

Based on typical 10MB project:

| Bundler | Cold Start | Hot Reload | Bundle Size | Memory |
|---------|-----------|-----------|-------------|--------|
| esbuild | ~100ms | N/A | Medium | Low |
| Vite | ~500ms | ~50ms HMR | Small | Medium |
| Webpack | ~3s | ~500ms | Medium | High |
| Rollup | ~2s | N/A | Smallest | Low |

## Future Enhancements

Potential improvements:

1. **Dev Server Integration**: Expose Vite's dev server through Builder CLI
2. **Watch Mode**: Implement file watching with auto-rebuild
3. **Incremental Builds**: Cache bundler state between builds
4. **Plugin System**: Allow custom bundler plugins via BUILD config
5. **Parallel Bundling**: Bundle multiple targets in parallel
6. **Smart Caching**: Hash-based caching of bundle outputs
7. **Bundle Analysis**: Generate bundle size reports
8. **Source Maps**: Enhanced source map handling
9. **Asset Optimization**: Image/font optimization integration
10. **Tree-Shaking Reports**: Visualize what code is removed

## References

- [esbuild Documentation](https://esbuild.github.io/)
- [Webpack Documentation](https://webpack.js.org/)
- [Rollup Documentation](https://rollupjs.org/)
- [Vite Documentation](https://vitejs.dev/)
- [Builder Architecture](../../../../docs/ARCHITECTURE.md)

