# Builder Scripting System

**Tier 1 of the Three-Tier Programmability Architecture**

## Overview

This module implements functional DSL extensions for Builderfiles, enabling:
- **Variables**: `let` and `const` bindings
- **Functions**: Pure functions for code reuse
- **Conditionals**: `if`/`else` statements
- **Loops**: `for` loops and `range()` iteration
- **Macros**: Code generation at parse time
- **Built-ins**: 30+ standard library functions
- **Type Safety**: Static type checking
- **Performance**: Compile-time evaluation

## Architecture

```
┌──────────────────────────────────────────────────┐
│                 Builderfile                      │
│  let pkgs = ["core", "api"];                     │
│  for pkg in pkgs { target(pkg) { ... } }         │
└──────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────┐
│              Lexer (parsing/lexer.d)             │
│  Tokenize: let, for, in, identifiers, ...        │
└──────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────┐
│             Parser (parsing/parser.d)            │
│  Parse: variable decls, loops, expressions       │
└──────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────┐
│            Evaluator (evaluator.d)               │
│  Evaluate expressions, resolve variables         │
└──────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────┐
│             Expander (expander.d)                │
│  Expand macros, generate targets                 │
└──────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────┐
│          Target Configuration (schema)           │
│  Final target definitions ready for building     │
└──────────────────────────────────────────────────┘
```

## Modules

### types.d
- `Value`: Runtime value with dynamic type
- `ValueType`: Type enumeration (Null, Bool, Number, String, Array, Map, Function, Target)
- `TargetConfig`: Target configuration structure
- `TypeInfo`: Type information for expressions

**Design principles:**
- Variant-based value representation
- Type-safe conversions
- Efficient equality comparison

### scopemanager.d
- `ScopeManager`: Lexical scope management
- `Symbol`: Variable binding with metadata
- Nested scope support with automatic cleanup

**Features:**
- Stack-based symbol tables
- Const enforcement
- Shadowing detection
- Scope guards for RAII

### builtins.d
- `BuiltinRegistry`: Function registry
- 30+ standard library functions
- String, array, file, environment operations

**Functions:**
- String: `upper`, `lower`, `trim`, `split`, `join`, `replace`, `startsWith`, `endsWith`, `contains`
- Array: `len`, `append`, `range`
- Type: `str`, `int`, `bool`
- File: `glob`, `fileExists`, `readFile`, `basename`, `dirname`, `stripExtension`
- Environment: `env`, `platform`, `arch`

### evaluator.d
- `Evaluator`: Expression evaluation engine
- Binary/unary operations
- Function calls
- Array indexing and slicing
- Type inference

**Features:**
- String interpolation: `"${var}"`
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Logical: `&&`, `||`, `!`
- Type checking at evaluation time

### expander.d
- `MacroExpander`: Macro expansion engine
- `MacroDefinition`: Macro structure
- Code generation at parse time

**Features:**
- Macro definitions with parameters
- Hygiene (prevent name collisions)
- Target generation

## Usage Examples

### Variables
```d
let version = "1.0.0";
const buildDir = "bin";

target("app-${version}") {
    output: buildDir + "/app";
}
```

### Conditionals
```d
let platform = env("OS", "linux");

if (platform == "linux") {
    let flags = ["-pthread"];
} else if (platform == "darwin") {
    let flags = ["-framework", "CoreFoundation"];
}
```

### Loops
```d
let packages = ["core", "api", "cli"];

for pkg in packages {
    target(pkg) {
        type: library;
        sources: ["lib/" + pkg + "/**/*.py"];
    }
}
```

### Functions
```d
fn pythonLib(name, srcs) {
    return {
        type: library,
        language: python,
        sources: srcs
    };
}

target("utils") = pythonLib("utils", ["lib/utils.py"]);
```

### Macros
```d
macro genServices(services) {
    for svc in services {
        target(svc.name) {
            type: executable;
            sources: ["services/" + svc.name + "/**/*.go"];
            env: {"PORT": str(svc.port)};
        }
    }
}

genServices([
    {name: "auth", port: 8001},
    {name: "api", port: 8002}
]);
```

## Implementation Status

### Phase 1: Core Infrastructure ✅
- [x] Type system (`types.d`)
- [x] Scope management (`scope.d`)
- [x] Built-in functions (`builtins.d`)
- [x] Expression evaluator (`evaluator.d`)
- [x] Macro expander (`expander.d`)

### Phase 2: Parser Integration 🚧
- [ ] Extend lexer with new tokens
- [ ] Parse variable declarations
- [ ] Parse functions and macros
- [ ] Parse conditionals and loops
- [ ] Integrate evaluator

### Phase 3: Testing 📋
- [ ] Unit tests for each module
- [ ] Integration tests
- [ ] Example Builderfiles
- [ ] Performance benchmarks

## Performance

### Compile-Time Evaluation
Most operations happen at parse time:
- Variable resolution: O(1) hash table lookup
- Function calls: Inline expansion or memoization
- Conditionals: Evaluated once, dead code eliminated
- Loops: Unrolled at parse time

**Result**: Zero runtime overhead for most constructs.

### Optimization Strategies
1. **Constant Folding**: Evaluate constants at parse time
2. **Dead Code Elimination**: Remove unreachable branches
3. **Memoization**: Cache pure function results
4. **Inlining**: Inline small functions

## Type Safety

All expressions are type-checked:
- No runtime type errors
- Function signatures enforced
- Array/map types preserved

**Type Inference:**
```d
let x = 42;              // inferred as number
let name = "app";        // inferred as string
let flags = ["-O2"];     // inferred as array<string>
```

**Type Errors:**
```d
let x = "hello" + 42;    // ERROR: Cannot add string and number
target("app") {
    sources: unknownVar;  // ERROR: Undefined variable
}
```

## Integration

### With Parser
```d
// In parser
auto evaluator = new Evaluator();

// Define variables from let statements
evaluator.defineVariable("version", Value.makeString("1.0.0"), false);

// Evaluate expressions in target definitions
auto sourcesExpr = parseExpression();  // Parse DSL expression
auto sourcesValue = evaluator.evaluate(sourcesExpr);  // Evaluate to value
```

### With Target Schema
```d
// Convert Value to Target
auto targetValue = evaluator.evaluate(targetExpr);
auto configResult = TargetConfig.fromValue(targetValue);
if (configResult.isOk) {
    auto target = configResult.unwrap();
    // Use target configuration
}
```

## Testing

Run tests:
```bash
dmd -unittest -main config/scripting/*.d -of=test-scripting
./test-scripting
```

## Next Steps

1. **Parser Integration**: Wire evaluator into DSL parser
2. **Statement Execution**: Implement for loops and conditionals
3. **Function Definitions**: Support user-defined functions
4. **Macro System**: Complete macro expansion
5. **Documentation**: User guide and examples
6. **Testing**: Comprehensive test suite

## Design Decisions

### Why Functional?
- **Predictability**: Pure functions, no side effects
- **Type Safety**: Static type checking
- **Performance**: Compile-time evaluation
- **Simplicity**: Limited scope prevents abuse

### Why Not Turing-Complete?
- **Build files should be declarative**: Prevents complex logic
- **Security**: Limits what malicious Builderfiles can do
- **Performance**: Compile-time evaluation simpler
- **For complex logic**: Use Tier 2 (D macros) or Tier 3 (plugins)

### Why Value-Based?
- **Flexibility**: Dynamic types when needed
- **Type Safety**: Static checking when possible
- **Simplicity**: No complex type system to learn

## References

- [Architecture Documentation](../../../docs/architecture/programmability.md)
- [DSL Specification](../../../docs/architecture/dsl.md)
- [Examples](../../../examples/)

