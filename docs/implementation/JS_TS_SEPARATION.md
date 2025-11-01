# JavaScript vs TypeScript Handler Separation

## Overview

The Builder system has **separate handlers** for JavaScript and TypeScript to ensure accurate language detection and prevent conflicts. While both languages share bundlers (Webpack, Rollup, Vite) and frameworks (React, Vue, Svelte), they are handled by distinct code paths.

## File Extension Mapping

The file extension mapping is defined in `source/languages/registry.d` and is **unambiguous**:

### JavaScript Files
- `.js` → `TargetLanguage.JavaScript`
- `.jsx` → `TargetLanguage.JavaScript`
- `.mjs` → `TargetLanguage.JavaScript`
- `.cjs` → `TargetLanguage.JavaScript`

### TypeScript Files
- `.ts` → `TargetLanguage.TypeScript`
- `.tsx` → `TargetLanguage.TypeScript`
- `.mts` → `TargetLanguage.TypeScript`
- `.cts` → `TargetLanguage.TypeScript`

## Handler Responsibilities

### JavaScript Handler (`languages.web.javascript.core.handler`)

**Processes:**
- `.js`, `.jsx`, `.mjs`, `.cjs` files

**Rejects:**
- `.ts`, `.tsx`, `.mts`, `.cts` files with clear error message

**Bundlers Available:**
- ESBuild (default, fast)
- Webpack (complex projects)
- Rollup (libraries)
- Vite (modern frameworks)

**Framework Detection:**
- Detects React/Vue/Svelte from `.jsx` files
- Auto-configures Vite plugins for frameworks

### TypeScript Handler (`languages.web.typescript.core.handler`)

**Processes:**
- `.ts`, `.tsx`, `.mts`, `.cts` files
- `.js`, `.jsx` files **only if** `allowJs: true` is configured

**Rejects:**
- `.js`, `.jsx` files if `allowJs` is not enabled

**Compilers/Bundlers Available:**
- TSC (official, best declarations)
- SWC (ultra-fast)
- ESBuild (fast, bundling)
- Webpack (complex projects)
- Rollup (libraries with tree-shaking)
- Vite (modern frameworks)

**Framework Detection:**
- Detects React/Vue/Svelte from `.tsx` files
- Auto-configures Vite plugins for frameworks

## Validation Logic

### JavaScript Handler Validation

```d
// In buildImpl():
bool hasTypeScript = target.sources.any!(s => 
    s.endsWith(".ts") || s.endsWith(".tsx") || 
    s.endsWith(".mts") || s.endsWith(".cts")
);
if (hasTypeScript)
{
    result.error = "JavaScript handler received TypeScript files. " ~
                  "Please use language: typescript for this target.";
    return result;
}
```

### TypeScript Handler Validation

```d
// In buildImpl():
bool hasPlainJS = target.sources.any!(s => 
    (s.endsWith(".js") || s.endsWith(".jsx") || 
     s.endsWith(".mjs") || s.endsWith(".cjs")) &&
    !s.endsWith(".d.ts")
);

if (hasPlainJS && !tsConfig.allowJs)
{
    result.error = "TypeScript handler received JavaScript files but allowJs is not enabled. " ~
                  "Either use language: javascript or enable allowJs in config.";
    return result;
}
```

## Bundler Sharing

Both handlers share the **same bundler implementations** but use them differently:

### Webpack
- **JavaScript**: Uses `webpack` CLI with JavaScript config generation
- **TypeScript**: Uses `webpack` with `ts-loader` for TypeScript compilation

### Rollup
- **JavaScript**: Uses Rollup directly for JavaScript bundling
- **TypeScript**: Uses Rollup with `@rollup/plugin-typescript`

### Vite
- **JavaScript**: Uses Vite for JavaScript with framework detection
- **TypeScript**: Uses Vite with TypeScript support enabled (esbuild transforms)

### ESBuild
- **JavaScript**: Direct JavaScript bundling
- **TypeScript**: TypeScript compilation via esbuild's built-in TS support

## Usage Examples

### Pure JavaScript Project

```d
target("js-app") {
    type: executable;
    language: javascript;  // ← Use javascript
    sources: ["src/**/*.js", "src/**/*.jsx"];
    
    config: {
        "bundler": "vite",
        "mode": "bundle",
        "jsx": true
    };
}
```

### Pure TypeScript Project

```d
target("ts-app") {
    type: executable;
    language: typescript;  // ← Use typescript
    sources: ["src/**/*.ts", "src/**/*.tsx"];
    
    config: {
        "compiler": "vite",
        "mode": "bundle",
        "jsx": "react-jsx"
    };
}
```

### TypeScript with JavaScript Files

```d
target("mixed-app") {
    type: executable;
    language: typescript;  // ← TypeScript handler
    sources: [
        "src/**/*.ts",
        "src/**/*.tsx",
        "src/legacy/**/*.js"  // Legacy JS files
    ];
    
    config: {
        "compiler": "tsc",
        "allowJs": true,      // ← Enable JS support
        "checkJs": false      // Don't type-check JS files
    };
}
```

## Error Messages

### Wrong Language for TypeScript Files

```
Error: JavaScript handler received TypeScript files (.ts/.tsx).
Please use language: typescript for this target.
Files: src/app.ts, src/component.tsx
```

### Wrong Language for JavaScript Files

```
Error: TypeScript handler received JavaScript files (.js/.jsx) but allowJs is not enabled.
Either use language: javascript for this target, or enable allowJs in config.
Files: src/app.js, src/utils.js
```

## Auto-Detection Strategy

When `compiler: "auto"` or `bundler: "auto"` is used:

### JavaScript (auto)
1. Check for framework files (`.jsx`)
2. Check for library indicators in `package.json`
3. Priority: **ESBuild** > Vite > Webpack > Rollup
4. For libraries: prefer Rollup (tree-shaking)

### TypeScript (auto)
1. Check for TSX files (`.tsx`)
2. Check build mode (library vs bundle vs compile)
3. **Library mode**: Rollup > TSC (best declarations)
4. **Bundle mode**: Vite > Webpack (framework support)
5. **Compile mode**: SWC > ESBuild > TSC (speed)

## Framework Detection

Both handlers detect frameworks similarly but from different file types:

### JavaScript
- Scans `.jsx` files for React components
- Checks `package.json` for `react`, `vue`, `svelte` dependencies
- Auto-enables appropriate Vite plugin

### TypeScript
- Scans `.tsx` files for React components
- Checks `package.json` for framework dependencies
- Auto-enables appropriate Vite plugin with TypeScript support

## Configuration Keys

### JavaScript
- Primary: `"javascript"` in target config
- Legacy: `"jsConfig"` (backward compatibility)

### TypeScript
- Primary: `"typescript"` in target config
- Legacy: `"tsConfig"` (backward compatibility)

## Best Practices

1. **Use the correct language**: Match the language to your file extensions
   - `.js`/`.jsx` → `language: javascript`
   - `.ts`/`.tsx` → `language: typescript`

2. **Don't mix unnecessarily**: Keep JavaScript and TypeScript in separate targets unless you need `allowJs`

3. **Enable allowJs explicitly**: If you need TypeScript to process JavaScript files, set `allowJs: true`

4. **Framework projects**: Use Vite for both JS and TS framework projects
   - Best framework integration
   - Fast HMR in development
   - Optimal production builds

5. **Library projects**: Use Rollup for both JS and TS libraries
   - Best tree-shaking
   - Multiple output formats
   - Minimal bundle sizes

6. **Complex builds**: Use Webpack for both JS and TS when you need:
   - Custom loaders
   - Complex plugin ecosystem
   - Migration from existing Webpack config

## Internal Architecture

### Separation Benefits
1. **Clear responsibility**: Each handler knows exactly what files it processes
2. **No ambiguity**: File extensions uniquely identify the handler
3. **Better errors**: Early validation with helpful messages
4. **Type safety**: TypeScript handler can assume TypeScript-specific features
5. **Performance**: No unnecessary checks for file types

### Shared Components
- **Bundlers**: Same implementations, different entry points
- **Utilities**: Dependency installation, package.json parsing
- **Caching**: Both use action-level caching
- **Framework detection**: Similar logic, different file extensions

## Migration Guide

### From JavaScript to TypeScript

1. Change language declaration:
```d
// Before
target("app") {
    language: javascript;
    sources: ["src/**/*.js"];
}

// After
target("app") {
    language: typescript;
    sources: ["src/**/*.ts"];  // Rename files to .ts
}
```

2. Migrate configuration:
```d
// Before
config: {
    "bundler": "vite",
    "jsx": true
}

// After
config: {
    "compiler": "vite",
    "jsx": "react-jsx",
    "strict": true
}
```

### Gradual Migration (allowJs)

```d
target("app") {
    language: typescript;
    sources: [
        "src/**/*.ts",      // New TypeScript files
        "src/legacy/*.js"   // Old JavaScript files
    ];
    
    config: {
        "compiler": "tsc",
        "allowJs": true,     // Allow mixing
        "checkJs": false,    // Don't type-check JS (yet)
        "strict": true       // Strict for TS files only
    };
}
```

## Testing

Both handlers are tested separately to ensure:
- Correct file extension validation
- Proper rejection of wrong file types
- Framework detection accuracy
- Bundler selection logic
- Configuration parsing

Run tests:
```bash
# JavaScript handler tests
dub test -- --filter=JavaScriptHandler

# TypeScript handler tests
dub test -- --filter=TypeScriptHandler
```

## Summary

The JavaScript and TypeScript handlers are **completely separate** with:
- ✅ Distinct file extension mappings
- ✅ Explicit validation and error messages
- ✅ Shared bundler implementations
- ✅ Independent framework detection
- ✅ Clear configuration namespaces
- ✅ No ambiguity in language selection

This separation ensures that **detection happens accurately 100% of the time** based on explicit language declaration and file extensions, preventing any overlap or confusion.

