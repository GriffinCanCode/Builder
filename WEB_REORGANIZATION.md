# Web Languages Reorganization

## Summary

Reorganized JavaScript, TypeScript, and added CSS support into a unified `web/` package with shared infrastructure.

## Structure

### Before
```
source/languages/
├── scripting/
│   ├── javascript/
│   │   ├── core/
│   │   ├── bundlers/
│   │   └── package.d
│   └── typescript/
│       ├── core/
│       ├── tooling/
│       └── package.d
```

### After
```
source/languages/
├── web/
│   ├── shared/          # NEW - Common utilities
│   │   ├── managers/    # Package manager abstraction
│   │   ├── utils.d      # Shared functions (findPackageJson, etc.)
│   │   └── package.d
│   ├── javascript/      # MOVED from scripting/
│   │   ├── core/
│   │   ├── bundlers/
│   │   └── package.d
│   ├── typescript/      # MOVED from scripting/
│   │   ├── core/
│   │   ├── tooling/
│   │   └── package.d
│   ├── css/             # NEW - CSS support
│   │   ├── core/
│   │   ├── processors/  # PostCSS, SCSS, Less
│   │   └── package.d
│   ├── package.d
│   └── README.md
```

## Changes Made

### 1. Created Shared Infrastructure
- `web/shared/utils.d` - Extracted duplicate utility functions:
  - `findPackageJson()` - Find package.json in directory tree
  - `detectTestCommand()` - Detect test scripts
  - `installDependencies()` - Install npm/yarn/pnpm dependencies
  - `isCommandAvailable()` - Check for CLI tools

- `web/shared/managers/base.d` - Package manager abstraction interface

**Code Reduction**: ~200 lines of duplication removed

### 2. Moved Existing Languages
- Moved `scripting/javascript/` → `web/javascript/`
- Moved `scripting/typescript/` → `web/typescript/`
- Updated all module paths from `languages.scripting.*` to `languages.web.*`
- Updated handlers to use shared utilities

### 3. Added CSS Support
New CSS language handler with:
- **Processors**: None (pure CSS), PostCSS, SCSS, Less, Stylus
- **Frameworks**: Tailwind, Bootstrap, Bulma integration  
- **Features**: Minification, source maps, autoprefixing, purging
- **Auto-detection**: Detects processor from file extensions and config files

### 4. Updated Imports
Files updated:
- `source/languages/package.d` - Export `languages.web` instead of individual JS/TS
- `source/core/execution/executor.d` - Import from `languages.web.*`
- All files in `web/javascript/` and `web/typescript/` - Updated module declarations

## Benefits

1. **Reduced Tech Debt**: Eliminated ~200 lines of duplicated code
2. **Better Organization**: Web languages grouped by ecosystem (like JVM package)
3. **Shared Infrastructure**: Common utilities for all web languages
4. **First-Class CSS**: CSS now a build target with processor support
5. **Extensibility**: Easy to add Deno, Bun, HTML processors, etc.

## Breaking Changes

### Module Paths
- Old: `languages.scripting.javascript`
- New: `languages.web.javascript`

- Old: `languages.scripting.typescript`
- New: `languages.web.typescript`

### Import Statements
```d
// Before
import languages.scripting.javascript;
import languages.scripting.typescript;

// After
import languages.web.javascript;
import languages.web.typescript;
import languages.web.css;  // NEW
```

## New Capabilities

### CSS Target Example
```d
target("styles") {
    type: library;
    language: css;
    sources: ["src/styles.scss"];
    
    config: {
        "css": "{
            \"processor\": \"scss\",
            \"mode\": \"production\",
            \"minify\": true,
            \"sourcemap\": true
        }"
    };
}
```

### Tailwind CSS Example
```d
target("tailwind") {
    type: library;
    language: css;
    sources: ["src/styles.css"];
    
    config: {
        "css": "{
            \"processor\": \"postcss\",
            \"framework\": \"tailwind\",
            \"purge\": true,
            \"contentPaths\": [\"src/**/*.{js,jsx,ts,tsx}\"]
        }"
    };
}
```

## Design Philosophy

Following the successful JVM package pattern:

1. **Ecosystem Grouping**: Languages that share tooling belong together
2. **Shared Infrastructure**: Extract common patterns to reduce duplication
3. **Separation of Concerns**: Each language maintains distinct configuration
4. **Extensibility**: Easy to add new languages/tools to the ecosystem

## Future Enhancements

Potential additions:
- Deno runtime support
- Bun runtime support
- WebAssembly compilation
- HTML template processing
- SVG optimization
- Image processing pipelines

## Documentation

Full documentation available at:
- `source/languages/web/README.md` - Comprehensive guide
- `docs/EXAMPLES.md` - Usage examples
- `docs/DSL.md` - Configuration syntax

## Testing

Ensure to test:
1. JavaScript builds (with all bundlers)
2. TypeScript compilation (all compilers)
3. CSS processing (all processors)
4. Package manager operations
5. Cross-language imports

## Migration Guide

For existing projects using old paths:

1. Update imports in D source files
2. Rebuild the project
3. No changes needed to Builderfiles

The handlers are backward compatible - only D import statements need updating.
