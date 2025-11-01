# TypeScript Language Support

Comprehensive TypeScript build support with type-first architecture, separate from JavaScript, for Builderspace.

## Architecture

The TypeScript handler is built with these core principles:
- **Type checking is first-class**: Always validates types before compilation
- **Compiler flexibility**: Choose between tsc, swc, esbuild, webpack, rollup, or vite based on your needs
- **Bundler ecosystem**: Full support for modern bundlers (Webpack, Rollup, Vite)
- **Declaration files**: Automatic .d.ts generation for libraries
- **tsconfig.json**: Full support for TypeScript configuration files
- **Speed optimization**: Intelligent compiler selection (swc > esbuild > tsc)
- **Framework support**: Native React/Vue/Svelte support via Vite

## Key Components

### 1. Handler (`handler.d`)
Main orchestrator that:
- Parses TypeScript configuration
- Detects TSX/JSX usage
- Routes to appropriate build mode
- Manages type checking workflow
- Handles dependency installation

### 2. Type Checker (`checker.d`)
Standalone type checker that:
- Runs `tsc --noEmit` for pure type validation
- Validates `tsconfig.json` files
- Loads configuration from tsconfig.json
- Provides detailed error reporting
- Can run independently or before compilation

### 3. Config (`config.d`)
Comprehensive configuration with:
- **Build modes**: Check, Compile, Bundle, Library
- **Compiler selection**: Auto, TSC, SWC, ESBuild, Webpack, Rollup, Vite
- **Module formats**: CommonJS, ESM, UMD, AMD, System, Node16, NodeNext
- **Type checking options**: All strict mode flags
- **Source maps**: Standard, inline, declaration maps
- **JSX modes**: Preserve, React, ReactJSX, ReactJSXDev, ReactNative

### 4. Bundlers (`bundlers/`)

#### TSC Bundler (`tsc.d`)
- Official TypeScript compiler
- Best for: Libraries with declaration files
- Features: Complete type checking, accurate .d.ts generation
- Speed: Moderate

#### SWC Bundler (`swc.d`)
- Ultra-fast Rust-based compiler
- Best for: Large projects, fast iteration
- Features: Transpilation only, uses tsc for .d.ts
- Speed: Fastest (10-20x faster than tsc)

#### ESBuild Bundler (`esbuild.d`)
- Fast Go-based bundler
- Best for: Bundling applications
- Features: Bundle mode, tree-shaking, minification
- Speed: Very fast (10x faster than tsc)

#### Webpack Bundler (`webpack.d`)
- Industry-standard bundler with rich plugin ecosystem
- Best for: Complex projects with custom loaders, legacy projects
- Features: Advanced optimization, code splitting, extensive plugins
- Speed: Moderate
- Plugin: Uses ts-loader for TypeScript compilation

#### Rollup Bundler (`rollup.d`)
- Tree-shaking optimized bundler
- Best for: Library development, minimal bundle sizes
- Features: Excellent tree-shaking, multiple output formats
- Speed: Fast
- Plugin: Uses @rollup/plugin-typescript

#### Vite Bundler (`vite.d`)
- Modern development server with lightning-fast HMR
- Best for: Modern frameworks (React, Vue, Svelte), TypeScript apps
- Features: Framework plugins, optimized dev/build, native ESM
- Speed: Very fast (esbuild-powered)
- Framework: Auto-detects React/Vue/Svelte from file extensions

## Usage Examples

### Basic TypeScript Compilation

```d
target("app") {
    type: executable;
    language: typescript;
    sources: ["src/**/*.ts"];
    
    config: {
        "compiler": "auto",
        "target": "es2020",
        "module": "esm",
        "strict": true
    };
}
```

### Library with Declaration Files

```d
target("my-library") {
    type: library;
    language: typescript;
    sources: ["src/**/*.ts"];
    
    config: {
        "mode": "library",
        "compiler": "tsc",
        "declaration": true,
        "declarationMap": true,
        "outDir": "dist",
        "target": "es2020",
        "module": "esm"
    };
}
```

### Fast Development Build (SWC)

```d
target("dev-app") {
    type: executable;
    language: typescript;
    sources: ["src/**/*.ts"];
    
    config: {
        "compiler": "swc",
        "sourceMap": true,
        "target": "es2020",
        "strict": true
    };
}
```

### Bundled Application (ESBuild)

```d
target("web-app") {
    type: executable;
    language: typescript;
    sources: ["src/**/*.ts"];
    
    config: {
        "mode": "bundle",
        "compiler": "esbuild",
        "entry": "src/index.ts",
        "minify": true,
        "sourceMap": true,
        "target": "es2020",
        "module": "esm"
    };
}
```

### Type Check Only

```d
target("check") {
    type: custom;
    language: typescript;
    sources: ["src/**/*.ts"];
    
    config: {
        "mode": "check",
        "strict": true,
        "noUnusedLocals": true,
        "noUnusedParameters": true
    };
}
```

### React/TSX Application (Vite)

```d
target("react-app") {
    type: executable;
    language: typescript;
    sources: ["src/**/*.tsx", "src/**/*.ts"];
    
    config: {
        "mode": "bundle",
        "compiler": "vite",
        "entry": "src/index.tsx",
        "jsx": "react-jsx",
        "jsxImportSource": "react",
        "minify": true,
        "sourceMap": true
    };
}
```

### Library with Rollup (Tree-Shaking)

```d
target("my-lib") {
    type: library;
    language: typescript;
    sources: ["src/**/*.ts"];
    
    config: {
        "mode": "library",
        "compiler": "rollup",
        "entry": "src/index.ts",
        "declaration": true,
        "module": "esm",
        "target": "es2020",
        "minify": true,
        "external": ["react", "react-dom"]
    };
}
```

### Webpack Bundle (Complex Projects)

```d
target("complex-app") {
    type: executable;
    language: typescript;
    sources: ["src/**/*.ts"];
    
    config: {
        "mode": "bundle",
        "compiler": "webpack",
        "entry": "src/index.ts",
        "minify": true,
        "sourceMap": true,
        "target": "es2020",
        "module": "esm"
    };
}
```

### Using tsconfig.json

```d
target("configured-app") {
    type: executable;
    language: typescript;
    sources: ["src/**/*.ts"];
    
    config: {
        "tsconfig": "./tsconfig.json",
        // Override specific options
        "outDir": "dist",
        "sourceMap": true
    };
}
```

## Configuration Options

### Build Modes

- `check`: Type check only, no compilation
- `compile`: Transpile to JavaScript
- `bundle`: Bundle with dependencies
- `library`: Library mode with declarations

### Compiler Selection

- `auto`: Intelligently choose best available (default)
  - Library mode: prefers `rollup` (tree-shaking) or `tsc` (declarations)
  - Bundle mode: prefers `vite` (frameworks) or `webpack` (complex)
  - Compile mode: prefers `swc` > `esbuild` > `tsc` (speed)
- `tsc`: Official TypeScript compiler
- `swc`: Ultra-fast Rust-based compiler
- `esbuild`: Fast Go-based bundler
- `webpack`: Industry-standard bundler
- `rollup`: Tree-shaking optimized bundler
- `vite`: Modern dev server and bundler
- `none`: Type check only

### Module Formats

- `commonjs`: Node.js CommonJS
- `esm`/`es2015`: ES Modules
- `umd`: Universal Module Definition
- `amd`: Asynchronous Module Definition
- `system`: SystemJS format
- `node16`/`nodenext`: Node.js 16+ ESM

### Type Checking Options

All TypeScript `strict` mode options are supported:
- `strict`: Enable all strict checks
- `strictNullChecks`: Null/undefined checking
- `strictFunctionTypes`: Function type contravariance
- `strictBindCallApply`: Strict bind/call/apply
- `strictPropertyInitialization`: Class property initialization
- `noImplicitAny`: No implicit any types
- `noImplicitThis`: No implicit this
- `noImplicitReturns`: All code paths return
- `noUnusedLocals`: Unused local variables
- `noUnusedParameters`: Unused parameters

## Pain Points Addressed

1. **Type Checking Speed**: Separate type checking allows parallel builds
2. **Compiler Choice**: Pick the right tool for the job (speed vs accuracy)
3. **Declaration Files**: Automatic generation and validation for libraries
4. **tsconfig.json**: Full integration with existing TypeScript projects
5. **Incremental Builds**: Smart caching of type check results
6. **Error Reporting**: Clear, actionable type errors

## Performance Characteristics

| Compiler | Speed | Type Checking | Declaration Files | Bundling | Tree-Shaking | Frameworks |
|----------|-------|---------------|-------------------|----------|--------------|------------|
| tsc      | 1x    | ✓ Full        | ✓ Accurate       | ✗        | ✗            | ✗          |
| swc      | 20x   | ✗ (uses tsc)  | ✗ (uses tsc)     | ✗        | ✗            | ✗          |
| esbuild  | 10x   | ✗ (uses tsc)  | ✗ (uses tsc)     | ✓        | ✓            | ✗          |
| webpack  | 3x    | ✓ (ts-loader) | ✓ (ts-loader)    | ✓        | ✓            | ✓ (plugins)|
| rollup   | 5x    | ✗ (uses tsc)  | ✓ (plugin)       | ✓        | ✓✓✓ Best     | ✗          |
| vite     | 12x   | ✗ (uses tsc)  | ✗                | ✓        | ✓✓           | ✓✓✓ Best   |

## Best Practices

1. **Development**: Use `swc` for fast iteration (compile mode) or `vite` (bundle mode with HMR)
2. **Libraries**: Use `rollup` for optimal tree-shaking or `tsc` for accurate declarations
3. **Production Apps**: Use `vite` for modern frameworks or `webpack` for complex projects
4. **React/Vue/Svelte**: Use `vite` for best framework integration
5. **Bundle Size Critical**: Use `rollup` for smallest bundles with best tree-shaking
6. **CI/CD**: Use `check` mode first, then compile
7. **Monorepos**: Separate type checking from compilation
8. **Legacy Projects**: Use `webpack` if you have existing webpack configuration

## Integration with JavaScript

TypeScript and JavaScript handlers are separate but can work together:
- TypeScript can import JavaScript files with `allowJs`
- JavaScript bundlers (webpack, rollup) can be used for JS files
- Shared configuration patterns between both handlers
- Type checking can validate JS files with `checkJs`

## Bundler Comparison

### When to Use Each Bundler

**TSC** (`tsc`)
- ✓ Need accurate .d.ts files
- ✓ Library with full type safety
- ✓ Maximum type checking strictness
- ✗ Don't need bundling
- ✗ Speed is not critical

**SWC** (`swc`)
- ✓ Fast development iteration
- ✓ Large codebase
- ✓ Simple compilation without bundling
- ✗ Don't need declarations
- ✗ Bundle size not a concern

**ESBuild** (`esbuild`)
- ✓ Fast bundling
- ✓ Simple projects
- ✓ Good enough tree-shaking
- ✗ No framework-specific optimizations

**Webpack** (`webpack`)
- ✓ Complex build requirements
- ✓ Custom loaders/plugins needed
- ✓ Existing webpack configuration
- ✓ Legacy project migration
- ✗ Modern greenfield projects (use Vite)

**Rollup** (`rollup`)
- ✓ Library development
- ✓ Bundle size is critical
- ✓ Best tree-shaking needed
- ✓ Multiple output formats
- ✗ Application development (use Vite)

**Vite** (`vite`)
- ✓ Modern React/Vue/Svelte apps
- ✓ Development speed with HMR
- ✓ Production optimization
- ✓ Modern ESM-first approach
- ✗ Legacy browser support (use Webpack)

## Future Enhancements

- Incremental type checking with tsc --incremental
- Watch mode for continuous compilation
- Plugin system for custom transformers
- Better monorepo support with project references
- Integration with Deno's TypeScript compiler
- Custom Vite plugin configuration
- Advanced Webpack loader options

