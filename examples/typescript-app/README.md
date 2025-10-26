# TypeScript Application Example

TypeScript application with type checking and bundling.

## Features

- Full TypeScript support
- Type checking and compilation
- esbuild for fast bundling
- Interfaces, enums, and generics
- Modern TypeScript features

## Requirements

```bash
npm install -g typescript esbuild
```

## Build

```bash
../../bin/builder build
```

## Run

```bash
node dist/app.js
```

## Configuration

The BUILD file specifies:
- `language: typescript` - TypeScript source files
- `bundler: "esbuild"` - Fast TypeScript compilation + bundling
- `target: "es2020"` - Modern JavaScript output

esbuild handles TypeScript compilation automatically without needing a separate tsc step.

## Type Checking

For strict type checking during development:

```bash
tsc --noEmit
```

Builder focuses on fast builds. Use `tsc --noEmit` for comprehensive type checking in CI/CD.

