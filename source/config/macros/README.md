# D-Based Macro System

**Tier 2 of the Three-Tier Programmability Architecture**

## Overview

For advanced users who need full D language power for complex build logic.
Write D code directly to generate targets programmatically with compile-time
type safety and zero runtime overhead.

## Features

- **Full D Access**: All D language features available
- **Compile-Time Generation**: Use CTFE for zero-cost macros
- **Runtime Compilation**: Dynamic macro loading via D compiler
- **Type Safety**: Full D type system
- **Performance**: Compile-time evaluation when possible

## Architecture

```
Builderfile.d (D source) → DCompiler → Binary → Execute → Targets
                                ↓
                           MacroRegistry
                                ↓
                           Target Generation
```

## Modules

### api.d
- `TargetBuilder`: Fluent API for target creation
- `MacroProvider`: Interface for macro implementations
- `MacroContext`: Build environment access
- Helper functions: `executable()`, `library()`, `test()`

### ctfe.d  
- Compile-time function execution
- Template-based target generation
- Compile-time validation
- Platform-specific conditionals

### compiler.d
- `DCompiler`: Compiles D code to executables
- `MacroExecutor`: Executes compiled macros
- `MacroBuilder`: High-level interface
- Caching support

### loader.d
- `MacroRegistry`: Macro registration and lookup
- `MacroLoader`: Auto-discovery of macros
- `MacroCache`: Compilation caching

## Usage Examples

### Example 1: Simple CTFE Macro

```d
// Builderfile.d
import builder.macros;

// This runs at compile-time
Target[] generateLibs() {
    return ["core", "api", "cli"].map!(name =>
        library(name, ["lib/" ~ name ~ "/**/*.d"], "d")
    ).array;
}

// Register macro
mixin RegisterMacro!(generateLibs, "generateLibs");
```

### Example 2: Microservices Generator

```d
// macros/microservices.d
module macros.microservices;

import builder.macros;
import std.algorithm;
import std.array;

struct ServiceConfig {
    string name;
    int port;
    string database;
}

class MicroserviceMacro : BaseMacro {
    this() {
        super("microservices", "Generate microservice targets");
    }
    
    override Target[] execute(MacroContext ctx) {
        ServiceConfig[] services = [
            ServiceConfig("auth", 8001, "postgres"),
            ServiceConfig("api", 8002, "redis"),
            ServiceConfig("worker", 8003, "mongo")
        ];
        
        return services.map!(svc =>
            TargetBuilder.create(svc.name)
                .type(TargetType.Executable)
                .language("go")
                .sources(["services/" ~ svc.name ~ "/**/*.go"])
                .env([
                    "PORT": svc.port.to!string,
                    "DATABASE": svc.database
                ])
                .build()
        ).array;
    }
}

// Register
static this() {
    MacroRegistry.instance.register("microservices", new MicroserviceMacro());
}
```

### Example 3: Platform Matrix Builder

```d
// Builderfile.d
import builder.macros;

Target[] generatePlatformBuilds() {
    auto matrix = PlatformMatrix(
        ["linux", "darwin", "windows"],
        ["x86_64", "arm64"],
        [
            "linux": ["x86_64": "-pthread -ldl", "arm64": "-pthread"],
            "darwin": ["x86_64": "-framework CoreFoundation", "arm64": "-framework CoreFoundation"],
            "windows": ["x86_64": "-lws2_32", "arm64": "-lws2_32"]
        ]
    );
    
    return matrix.generate("app", ["src/**/*.c"]);
}
```

### Example 4: Dependency Graph Generator

```d
import builder.macros;

Target[] generateLayeredArchitecture() {
    // Generate bottom-up dependency chain
    return generateDependencyTree(
        "app",                           // Root
        [
            ["utils", "logging"],        // Layer 1: Base utilities
            ["db", "http"],              // Layer 2: Infrastructure
            ["models", "services"],      // Layer 3: Business logic
            ["api", "cli"]               // Layer 4: Interfaces
        ],
        "lib/{name}/**/*.d"
    );
}
```

### Example 5: Code Generation Pipeline

```d
import builder.macros;
import std.file;
import std.path;

Target[] generateProtobufTargets() {
    import utils.files.glob;
    
    auto protoFiles = expandGlob("proto/**/*.proto");
    string[] languages = ["go", "python", "rust"];
    
    Target[] targets;
    
    foreach (proto; protoFiles) {
        string baseName = proto.baseName.stripExtension;
        
        foreach (lang; languages) {
            string outputDir = "gen/" ~ lang;
            
            auto target = TargetBuilder.create(baseName ~ "-" ~ lang)
                .type(TargetType.Custom)
                .sources([proto])
                .output(outputDir)
                .build();
            
            // Add custom command (would be handled by custom handler)
            target.config["command"] = "protoc --" ~ lang ~ "_out=" ~ outputDir ~ " " ~ proto;
            
            targets ~= target;
        }
    }
    
    return targets;
}
```

## Advanced Features

### Template-Based Generation

```d
auto serviceTemplate = TargetTemplate(
    TargetType.Executable,
    "go",
    "services/{name}/**/*.go",
    ["-ldflags", "-s -w"],  // Common flags
    ["LOG_LEVEL": "info"]   // Common env
);

auto targets = serviceTemplate.instantiateMany(["auth", "api", "worker"]);
```

### Conditional Compilation

```d
auto targets = conditionalTargets!(
    Condition!(isLinux, () => executable("app-linux", ["src/linux.c"])),
    Condition!(isDarwin, () => executable("app-darwin", ["src/darwin.c"])),
    Condition!(isWindows, () => executable("app-windows", ["src/windows.c"]))
)();
```

### Type-Safe Validation

```d
// Compile-time validation
enum myTarget = executable("app", ["main.d"]);
static assert(ValidateTarget!myTarget);  // Checked at compile-time

auto targets = validatedTargets!(
    executable("app1", ["src/app1.d"]),
    library("lib1", ["lib/lib1.d"]),
    test("test1", ["tests/test1.d"])
)();
```

## Integration with Builderfile

### In Builderfile (DSL)

```d
// Builderfile
import Builderfile.d;  // Import D macro file

// Call D function to generate targets
generateMicroservices();
generatePlatformBuilds();
```

### Standalone Macro File

```d
// macros/custom.d
module macros.custom;

import builder.macros;

extern(C) export Target[] generate() {
    // Return generated targets
    return [
        executable("app1", ["src/app1.d"]),
        library("lib1", ["lib/lib1.d"])
    ];
}
```

## Macro Discovery

Macros are auto-discovered from:
1. `./` - Current directory
2. `.builder/macros/` - Project macros  
3. `~/.builder/macros/` - User macros

## Compilation and Caching

Macros are compiled once and cached:
- Cache location: `.builder-cache/macros/`
- Recompiled only if source changes
- Binary cached based on source modification time

**Performance:**
- First run: ~1s compilation
- Subsequent runs: <10ms (cached)

## Testing

```bash
# Test macro compilation
dmd -unittest -main config/macros/*.d -of=test-macros
./test-macros

# Test specific macro
builder macro test microservices
```

## Best Practices

1. **Keep Macros Pure**: No side effects, only target generation
2. **Use CTFE When Possible**: Faster, zero runtime cost
3. **Validate at Compile-Time**: Catch errors early
4. **Cache Compilation**: Don't recompile unchanged macros
5. **Document Macros**: Explain what they generate and why

## Comparison: CTFE vs Runtime

| Aspect | CTFE | Runtime |
|--------|------|---------|
| Speed | Instant (compile-time) | ~1s first run |
| Flexibility | D language subset | Full D language |
| Caching | N/A | Automatic |
| Debugging | Compile errors | Runtime errors |
| Use Case | Static generation | Dynamic generation |

**Recommendation**: Use CTFE for static patterns, runtime for dynamic/complex logic.

## Integration with Tier 1

Tier 2 macros can be called from Tier 1 DSL:

```d
// Builderfile (Tier 1 DSL)
import myMacros;  // Tier 2 D code

// Call Tier 2 macro from Tier 1 DSL
let services = genMicroservices(["auth", "api", "worker"]);

for svc in services {
    target(svc.name) {
        type: executable;
        sources: svc.sources;
    }
}
```

## Next Steps

1. **Implement Parser Integration**: Wire macro system into DSL parser
2. **Add More Examples**: Cover common use cases
3. **Performance Tuning**: Optimize compilation and caching
4. **Documentation**: User guide and API reference
5. **Testing**: Comprehensive test suite

## References

- [Tier 1: Functional DSL](../scripting/README.md)
- [Architecture Overview](../../../docs/architecture/programmability.md)
- [Examples](../../../examples/macros/)

