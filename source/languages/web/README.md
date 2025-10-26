##  Web Languages Package

Unified support for web development languages and technologies in the Builder build system. This package provides integrated implementations for JavaScript, TypeScript, and CSS with shared infrastructure for package managers, bundlers, and build orchestration.

## Overview

The Web languages package consolidates front-end and Node.js development tools with a focus on:
- **Shared Infrastructure** - Common utilities for package managers (npm, yarn, pnpm, bun)
- **Build Orchestration** - Unified handling of JavaScript, TypeScript, and CSS compilation
- **Modern Tooling** - Support for latest bundlers, compilers, and processors
- **Framework Detection** - Automatic integration with React, Vue, Angular, Tailwind, etc.

## Architecture

```
web/
├── shared/                    # Common infrastructure
│   ├── managers/              # Package manager abstraction
│   ├── utils.d                # Shared utilities
│   └── package.d              # Module exports
├── javascript/                # JavaScript support
│   ├── core/                  # Handler and configuration
│   ├── bundlers/              # esbuild, webpack, rollup, vite
│   └── package.d              # JavaScript module exports
├── typescript/                # TypeScript support  
│   ├── core/                  # Handler and configuration
│   ├── tooling/               # Compilers (tsc, swc, esbuild)
│   └── package.d              # TypeScript module exports
├── css/                       # CSS support
│   ├── core/                  # Handler and configuration
│   ├── processors/            # PostCSS, SCSS, Less, Stylus
│   ├── frameworks/            # Tailwind, Bootstrap integration
│   └── package.d              # CSS module exports
├── package.d                  # Web package exports
└── README.md                  # This file
```

## Supported Technologies

### JavaScript
Full-featured JavaScript support for Node.js and browser environments.

**Key Features:**
- **Build Modes**: Node scripts, browser bundles, libraries
- **Bundlers**: esbuild (fastest), webpack (most features), rollup (libraries), vite (modern)
- **Package Managers**: npm, yarn, pnpm, bun
- **Platforms**: Node.js, Browser, Neutral (universal)
- **Output Formats**: ESM, CommonJS, IIFE, UMD
- **Features**: JSX support, minification, source maps, tree-shaking

### TypeScript
Type-first TypeScript support with multiple compiler options.

**Key Features:**
- **Build Modes**: Type check only, compile, bundle, library
- **Compilers**: tsc (official), swc (fastest), esbuild (balanced)
- **Declaration Files**: Automatic .d.ts generation for libraries
- **Type Checking**: Strict mode options, tsconfig.json support
- **Module Formats**: CommonJS, ESM, UMD, AMD, System, Node16, NodeNext
- **JSX Modes**: React, ReactJSX, Preserve, ReactNative
- **Features**: Source maps, declaration maps, incremental compilation

### CSS
Comprehensive CSS preprocessing and optimization.

**Key Features:**
- **Processors**: None (pure CSS), PostCSS, SCSS/Sass, Less, Stylus
- **Frameworks**: Tailwind CSS, Bootstrap, Bulma integration
- **Build Modes**: Compile, production (minified), watch
- **Features**: Minification, autoprefixing, source maps, purging
- **Optimization**: Unused CSS removal, browser targeting

## Common Features

### 📦 Package Manager Support

All web languages share unified package manager handling:
- **npm** - Node Package Manager (default)
- **yarn** - Fast, reliable package manager
- **pnpm** - Efficient disk space usage
- **bun** - Ultra-fast all-in-one toolkit

The system auto-detects package managers from lockfiles and provides consistent interfaces for dependency installation.

### 🔧 Build Orchestration

Integrated build pipeline coordination:
- **Dependency Installation** - Automatic npm/yarn/pnpm/bun execution
- **Config Detection** - Automatic discovery of package.json, tsconfig.json, postcss.config.js
- **Framework Detection** - React, Vue, Angular, Svelte auto-detection
- **Test Integration** - Jest, Vitest, Mocha runner support
- **Watch Mode** - File watching for development

### ⚡ Performance Features

- **Incremental Builds** - Only rebuild changed files
- **Parallel Execution** - Multi-threaded processing
- **Build Caching** - BLAKE3-based content hashing
- **Smart Bundling** - Optimized chunk splitting
- **Tree Shaking** - Dead code elimination

## Usage

### Import Web Languages

```d
import languages.web;

// All web languages are now available
auto jsHandler = new JavaScriptHandler();
auto tsHandler = new TypeScriptHandler();
auto cssHandler = new CSSHandler();
```

### Import Specific Language

```d
import languages.web.javascript;
import languages.web.typescript;
import languages.web.css;
```

### Import Shared Utilities

```d
import languages.web.shared.utils;

// Use shared utilities
string packageJsonPath = findPackageJson(sources);
installDependencies(sources, "npm");
bool hasNode = isCommandAvailable("node");
```

## Example Configurations

### JavaScript React App

```d
target("react-app") {
    type: executable;
    language: javascript;
    sources: ["src/**/*.jsx", "src/**/*.js"];
    output: "bundle.js";
    
    config: {
        "javascript": "{
            \"mode\": \"bundle\",
            \"bundler\": \"vite\",
            \"entry\": \"src/main.jsx\",
            \"platform\": \"browser\",
            \"format\": \"esm\",
            \"minify\": true,
            \"sourcemap\": true,
            \"jsx\": true
        }"
    };
}
```

### TypeScript Library

```d
target("ts-lib") {
    type: library;
    language: typescript;
    sources: ["src/**/*.ts"];
    output: "lib.js";
    
    config: {
        "typescript": "{
            \"mode\": \"library\",
            \"compiler\": \"tsc\",
            \"target\": \"es2020\",
            \"module\": \"esm\",
            \"declaration\": true,
            \"declarationMap\": true,
            \"strict\": true
        }"
    };
}
```

### CSS with Tailwind

```d
target("styles") {
    type: library;
    language: css;
    sources: ["src/styles.css"];
    output: "bundle.css";
    
    config: {
        "css": "{
            \"processor\": \"postcss\",
            \"framework\": \"tailwind\",
            \"mode\": \"production\",
            \"minify\": true,
            \"purge\": true,
            \"contentPaths\": [\"src/**/*.{js,jsx,ts,tsx,html}\"]
        }"
    };
}
```

### SCSS Compilation

```d
target("scss-styles") {
    type: library;
    language: css;
    sources: ["src/**/*.scss"];
    output: "styles.css";
    
    config: {
        "css": "{
            \"processor\": \"scss\",
            \"mode\": \"production\",
            \"minify\": true,
            \"sourcemap\": true,
            \"includePaths\": [\"node_modules\"]
        }"
    };
}
```

## Bundler Comparison

| Bundler | Speed | Features | Best For |
|---------|-------|----------|----------|
| **esbuild** | ⚡⚡⚡ Fastest | Basic | Quick builds, simple apps |
| **vite** | ⚡⚡ Very Fast | Modern | Development, HMR, modern frameworks |
| **rollup** | ⚡ Fast | Tree-shaking | Libraries, optimal bundles |
| **webpack** | 🐢 Slower | Most complete | Complex apps, legacy projects |

## Compiler Comparison (TypeScript)

| Compiler | Speed | Type Check | Declarations | Best For |
|----------|-------|------------|--------------|----------|
| **tsc** | 🐢 Baseline | Full | Perfect | Libraries, accuracy |
| **swc** | ⚡⚡⚡ 20x faster | Via tsc | Via tsc | Large projects, iteration |
| **esbuild** | ⚡⚡ 10x faster | Minimal | No | Quick builds, prototypes |

## CSS Processor Comparison

| Processor | Speed | Features | Best For |
|-----------|-------|----------|----------|
| **None** | ⚡⚡⚡ Instant | Concat + minify | Pure CSS |
| **PostCSS** | ⚡⚡ Fast | Plugins, autoprefixer | Modern CSS, Tailwind |
| **SCSS** | ⚡ Moderate | Variables, nesting | Traditional preprocessor |
| **Less** | ⚡ Moderate | Variables, mixins | Bootstrap projects |

## Integration with Builder

Web languages integrate seamlessly with Builder's core:
- **Dependency Graph** - Track file and package dependencies
- **Incremental Builds** - Rebuild only changed components
- **Caching** - Content-addressed artifact storage
- **Parallel Execution** - Multi-core utilization
- **Error Recovery** - Graceful failures with helpful messages

## Design Philosophy

The web package follows key architectural principles:

### 1. Shared Infrastructure
Eliminate duplication by extracting common utilities for:
- Package manager operations
- Config file detection
- Dependency resolution
- Test runner integration

### 2. Separation of Concerns
- **JavaScript**: Runtime-agnostic scripting with bundling
- **TypeScript**: Type-first compilation with declaration generation
- **CSS**: Style processing with framework integration

### 3. Extensibility
- Easy to add new bundlers (Parcel, Turbopack)
- Simple processor plugins (Tailwind, PostCSS plugins)
- Modular package manager support (Bun, Deno)

### 4. Developer Experience
- Auto-detection of configs and frameworks
- Sensible defaults for common use cases
- Clear error messages with actionable suggestions
- Fast iteration with watch modes

## Migration from Scripting

Previous structure:
```
languages/scripting/javascript/
languages/scripting/typescript/
```

New structure:
```
languages/web/javascript/
languages/web/typescript/
languages/web/css/
languages/web/shared/
```

**Breaking Changes:**
- Module paths changed from `languages.scripting.javascript` to `languages.web.javascript`
- Module paths changed from `languages.scripting.typescript` to `languages.web.typescript`
- Shared utilities moved to `languages.web.shared.utils`

**Benefits:**
- Reduced code duplication (~200 lines removed)
- Unified package manager handling
- CSS as first-class citizen
- Better organization for web-specific concerns

## Future Enhancements

Potential additions to the web package:
- **Deno** - Secure TypeScript runtime
- **Bun** - Ultra-fast JavaScript runtime
- **WebAssembly** - Compile to WASM
- **HTML** - Template processing (Handlebars, EJS)
- **SVG** - Optimization and sprite generation
- **Image Processing** - Optimization, responsive images

## Best Practices

### Choosing JavaScript vs TypeScript

**Use JavaScript when:**
- Rapid prototyping
- Small scripts or utilities
- No type safety requirements
- Maximum compatibility

**Use TypeScript when:**
- Large codebases
- Team collaboration
- API contracts important
- Refactoring safety needed

### CSS Strategy

1. **Pure CSS** - Simple projects, no build step needed
2. **PostCSS** - Modern CSS features, Tailwind projects
3. **SCSS** - Traditional approach, existing SCSS codebase
4. **Framework Integration** - Let Tailwind/Bootstrap handle styling

### Bundler Selection

1. **esbuild** - Default choice for speed
2. **vite** - Modern development with HMR
3. **rollup** - Libraries needing optimal tree-shaking
4. **webpack** - Complex projects needing advanced features

## Contributing

When extending web language support:
1. Follow shared utility patterns for common operations
2. Maintain consistency with existing language handlers
3. Add comprehensive error handling
4. Update documentation and examples
5. Ensure backward compatibility where possible

## See Also

- [Languages Package](../README.md) - Overview of all language support
- [JVM Package](../jvm/README.md) - Pattern for ecosystem grouping
- [Builder Architecture](../../../docs/ARCHITECTURE.md) - System design
- [Builder DSL](../../../docs/DSL.md) - Configuration syntax

## External Resources

- [Node.js](https://nodejs.org/)
- [TypeScript](https://www.typescriptlang.org/)
- [esbuild](https://esbuild.github.io/)
- [Vite](https://vitejs.dev/)
- [PostCSS](https://postcss.org/)
- [Sass](https://sass-lang.com/)
- [Tailwind CSS](https://tailwindcss.com/)

