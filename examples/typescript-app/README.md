# TypeScript Application Example

This example demonstrates the comprehensive TypeScript support in Builderspace with multiple build configurations.

## Project Structure

```
typescript-app/
├── Builderfile        # Build configurations
├── Builderspace       # Workspace definition
├── tsconfig.json     # TypeScript configuration
├── README.md         # This file
└── src/
    ├── app.ts        # Main entry point
    ├── math.ts       # Math utilities library
    └── utils.ts      # General utilities
```

## Build Targets

### Development Build (`dev`)
Fast compilation with SWC for rapid iteration:
```bash
builderspace build //typescript-app:dev
```
- **Compiler**: SWC (20x faster than tsc)
- **Features**: Source maps, strict mode
- **Best for**: Active development, hot reloading

### Production Build (`prod`)
Bundled and minified with esbuild:
```bash
builderspace build //typescript-app:prod
```
- **Compiler**: esbuild (bundled)
- **Features**: Minification, tree-shaking, external dependencies
- **Best for**: Deployment, optimal bundle size

### Library Build (`lib`)
Complete library with declaration files:
```bash
builderspace build //typescript-app:lib
```
- **Compiler**: tsc (official TypeScript)
- **Features**: .d.ts files, declaration maps
- **Best for**: Publishing to npm, type-safe libraries

### Type Check (`check`)
Validation without compilation:
```bash
builderspace build //typescript-app:check
```
- **Mode**: Type check only
- **Features**: Strict type checking, all lint options
- **Best for**: CI/CD pipelines, pre-commit hooks

## Configuration Comparison

| Target | Compiler | Speed | Output | Type Check | Bundle |
|--------|----------|-------|--------|------------|--------|
| dev    | swc      | ⚡⚡⚡   | Separate files | Via tsc | ✗ |
| prod   | esbuild  | ⚡⚡     | Single bundle | Via tsc | ✓ |
| lib    | tsc      | ⚡       | + .d.ts files | ✓ | ✗ |
| check  | tsc      | ⚡       | None | ✓ | ✗ |

## TypeScript Features Demonstrated

### Strong Typing
```typescript
// math.ts - Generic functions with type constraints
export function add<T extends number>(a: T, b: T): T
```

### Module System
```typescript
// app.ts - ES6 imports
import { add, multiply } from './math';
import { formatResult } from './utils';
```

### Strict Mode
All targets use strict type checking:
- No implicit any
- Strict null checks
- Strict function types
- No unused variables

## Advanced Configuration

### Using tsconfig.json
You can reference an existing `tsconfig.json`:
```d
target("configured") {
    config: {
        "tsconfig": "./tsconfig.json",
        // Override specific options
        "outDir": "custom-dist"
    };
}
```

### Custom Compiler Options
```d
target("custom") {
    config: {
        "target": "es2022",
        "moduleResolution": "bundler",
        "paths": {
            "@/*": ["src/*"]
        },
        "baseUrl": ".",
        "experimentalDecorators": true,
        "emitDecoratorMetadata": true
    };
}
```

## Performance Tips

1. **Development**: Use `swc` for fastest iteration
2. **Production**: Use `esbuild` for smallest bundles
3. **Libraries**: Use `tsc` for best type definitions
4. **CI**: Run `check` first, then build

## Integration Examples

### With React/TSX
```d
target("react-app") {
    sources: ["src/**/*.tsx", "src/**/*.ts"];
    config: {
        "jsx": "react-jsx",
        "jsxImportSource": "react"
    };
}
```

### With Node.js
```d
target("node-app") {
    config: {
        "module": "commonjs",
        "target": "es2020",
        "esModuleInterop": true
    };
}
```

### Monorepo Support
```d
target("package-a") {
    sources: ["packages/a/src/**/*.ts"];
    config: {
        "rootDir": "packages/a/src",
        "outDir": "packages/a/dist"
    };
}
```

## Build and Run

```bash
# Build all targets
builderspace build //typescript-app:*

# Build specific target
builderspace build //typescript-app:dev

# Run the application
node bin/app-dev.js
# or
node bin/app.js
```

## Compiler Comparison

### When to use TSC
- Publishing libraries to npm
- Need accurate type definitions
- Complex type transformations
- Maximum TypeScript compatibility

### When to use SWC
- Active development
- Large codebases (100k+ lines)
- Fast iteration cycles
- Don't need .d.ts immediately

### When to use ESBuild
- Production builds
- Need bundling
- Tree-shaking important
- Small bundle sizes critical

## Next Steps

- Add more build configurations for different environments
- Integrate with testing frameworks (Jest, Vitest)
- Set up watch mode for development
- Configure path aliases and module resolution
- Add linting with ESLint
