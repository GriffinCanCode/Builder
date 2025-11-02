# Three-Tier Programmability Integration

**How Tier 1, Tier 2, and Tier 3 Work Together**

## Overview

Builder's programmability system consists of three tiers that integrate seamlessly:

```
┌─────────────────────────────────────────────────────────────┐
│                     Builderfile (Entry Point)               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
        ┌───────────────────┴──────────────────┐
        │                                      │
        ↓                                      ↓
┌──────────────────┐                  ┌──────────────────┐
│   Tier 1: DSL    │──────calls──────→│  Tier 2: Macros  │
│  Variables       │←────returns──────│  D Functions     │
│  Functions       │                  │  CTFE            │
│  Conditionals    │                  │  Type-Safe       │
│  Loops           │                  │  Complex Logic   │
└────────┬─────────┘                  └──────────────────┘
         │
         │ calls
         ↓
┌──────────────────┐
│  Tier 3: Plugins │
│  Docker          │
│  Kubernetes      │
│  Custom Tools    │
└──────────────────┘
```

## Integration Points

### 1. DSL Calls D Macros (Tier 1 → Tier 2)

**Builderfile:**
```d
// Import D macro module
import Builderfile.d;

// Call D macro function
let services = generateMicroservices();

// Use returned data in DSL
for svc in services {
    target(svc.name) { ... }
}
```

**Builderfile.d:**
```d
import builder.macros;

string[] generateMicroservices() {
    // Complex D logic here
    return ["auth", "api", "worker"];
}

mixin RegisterMacro!(generateMicroservices, "generateMicroservices");
```

**Flow:**
1. DSL parser encounters `import Builderfile.d`
2. Compiler compiles `Builderfile.d` to binary
3. Binary is executed, returns JSON
4. DSL receives array of strings
5. DSL continues evaluation with returned data

### 2. DSL Uses Plugins (Tier 1 → Tier 3)

**Builderfile:**
```d
let platform = platform();

target("docker-image") {
    type: custom;
    plugin: "docker";
    sources: glob("src/**/*.go");
    config: {
        "platform": platform == "darwin" ? "linux/amd64" : "linux/" + platform
    };
}
```

**Flow:**
1. DSL evaluates `platform()` builtin
2. DSL creates target with `type: custom`
3. Build engine detects `plugin: "docker"`
4. Plugin system invokes `builder-plugin-docker`
5. Plugin executes, returns artifacts
6. Build continues

### 3. D Macros Use Plugins (Tier 2 → Tier 3)

**Builderfile.d:**
```d
import builder.macros;

Target[] generateDockerImages() {
    string[] services = ["auth", "api", "worker"];
    
    return services.map!(svc =>
        TargetBuilder.create(svc ~ "-image")
            .type(TargetType.Custom)
            .build()
            .withPlugin("docker", [
                "image": svc ~ ":latest"
            ])
    ).array;
}
```

**Flow:**
1. D macro generates targets
2. Targets specify `plugin` field
3. Targets returned to Builder
4. Build engine invokes plugins for custom targets

### 4. Full Integration Example

**Builderfile (Tier 1):**
```d
// Configuration
let environment = env("ENV", "dev");
let isProduction = environment == "production";

// Platform detection
let platform = platform();
let arch = arch();

// Import D macros
import Builderfile.d;

// Call Tier 2 macro
let services = generateMicroservices();

// Tier 1: Create test targets for each service
for svc in services {
    target(svc + "-test") {
        type: test;
        sources: ["tests/" + svc + "/**/*.go"];
        deps: [":" + svc];
    }
}

// Tier 1: Platform-specific builds
if (platform == "darwin") {
    target("macos-bundle") {
        type: executable;
        deps: services.map(|s| ":" + s);
    }
}

// Tier 3: Docker image
target("docker-image") {
    plugin: "docker";
    deps: services.map(|s| ":" + s);
}

// Tier 3: Kubernetes deployment
if (isProduction) {
    target("k8s-deploy") {
        plugin: "kubernetes";
        deps: [":docker-image"];
    }
}
```

**Builderfile.d (Tier 2):**
```d
import builder.macros;
import std.algorithm;
import std.array;

string[] generateMicroservices() {
    // Complex logic that would be tedious in Tier 1
    struct Service {
        string name;
        int port;
        string[] deps;
    }
    
    Service[] services = [
        Service("auth", 8001, []),
        Service("users", 8002, ["auth"]),
        Service("posts", 8003, ["auth", "users"])
    ];
    
    // Generate targets with complex dependency resolution
    foreach (svc; services) {
        auto target = TargetBuilder.create(svc.name)
            .type(TargetType.Executable)
            .language("go")
            .sources(["services/" ~ svc.name ~ "/**/*.go"])
            .deps(svc.deps.map!(d => ":" ~ d).array)
            .env(["PORT": svc.port.to!string])
            .build();
        
        // Register target
        registerTarget(target);
    }
    
    // Return service names for Tier 1 to use
    return services.map!(s => s.name).array;
}

mixin RegisterMacro!(generateMicroservices, "generateMicroservices");
```

**Data Flow:**
```
1. Builderfile (Tier 1) starts parsing
   ↓
2. Encounters `import Builderfile.d`
   ↓
3. Compiles and executes Builderfile.d (Tier 2)
   ↓
4. Tier 2 returns: ["auth", "users", "posts"]
   ↓
5. Tier 1 binds to variable: let services = ["auth", "users", "posts"]
   ↓
6. Tier 1 loops over services, creates test targets
   ↓
7. Tier 1 creates docker-image target (Tier 3)
   ↓
8. Build starts: executes targets in dependency order
   ↓
9. For custom targets: invokes plugins (Tier 3)
```

## Communication Protocols

### Tier 1 ↔ Tier 2

**Protocol:** JSON over stdout

**Tier 2 Output Format:**
```json
{
  "targets": [
    {
      "name": "service-auth",
      "type": "executable",
      "language": "go",
      "sources": ["services/auth/**/*.go"],
      "deps": [],
      "env": {"PORT": "8001"}
    }
  ],
  "variables": {
    "services": ["auth", "users", "posts"]
  }
}
```

**Tier 1 Parsing:**
```d
// Parser reads JSON, extracts targets and variables
auto json = parseJSON(macroOutput);

// Add targets to build graph
foreach (targetJson; json["targets"].array) {
    targets ~= parseTarget(targetJson);
}

// Bind variables to scope
foreach (key, value; json["variables"].object) {
    scope.define(key, parseValue(value));
}
```

### Tier 1 ↔ Tier 3

**Protocol:** JSON-RPC 2.0 over stdin/stdout

**Request (Builder → Plugin):**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "build.execute",
  "params": {
    "target": {...},
    "workspace": {...}
  }
}
```

**Response (Plugin → Builder):**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "success": true,
    "artifacts": ["image:myapp:latest"]
  }
}
```

### Tier 2 ↔ Tier 3

**Protocol:** Same as Tier 1 ↔ Tier 3 (JSON-RPC)

Tier 2 can invoke plugins directly:
```d
import builder.plugins;

auto result = PluginManager.execute("docker", params);
```

## Type Safety Across Tiers

### Tier 1: Runtime Type Checking

```d
let x = "hello";
let y = 42;

// Error caught at evaluation time:
let z = x + y;  // ERROR: Cannot add string and number
```

### Tier 2: Compile-Time Type Checking

```d
string[] generateServices() {  // Return type enforced
    return ["auth", "api"];
}

// Compile error:
// return 42;  // ERROR: Cannot convert int to string[]
```

### Tier 1 Consuming Tier 2

```d
let services = generateServices();  // Inferred as string[]

// Type-safe in Tier 1:
for svc in services {  // OK: iterating over string[]
    target(svc) { ... }  // OK: svc is string
}
```

## Error Handling

### Tier 1 Errors

```
Error: Undefined variable 'unknownVar' at line 15, column 10
  --> Builderfile:15:10
   |
15 |     deps: unknownVar,
   |           ^^^^^^^^^^ undefined variable
   |
Suggestion: Define variable with 'let unknownVar = ...'
```

### Tier 2 Errors

```
Error: Macro compilation failed
  --> Builderfile.d:23:5
   |
23 |     return 42;  // Wrong type
   |     ^^^^^^^^^ cannot convert int to string[]
   |
Expected: string[]
Found: int
```

### Tier 3 Errors

```
Error: Plugin 'docker' execution failed
  Command: builder-plugin-docker
  Exit code: 1
  Output: Docker daemon is not running

Suggestion: Start Docker daemon with 'docker start'
```

### Cross-Tier Error Propagation

```
Builderfile (Tier 1)
    ↓ calls
Builderfile.d (Tier 2) → Error: Compilation failed
    ↓ propagates
Builderfile (Tier 1) → Error: Macro 'generateServices' failed
    ↓ stops
Build aborted
```

## Performance Characteristics

### Tier 1 Evaluation
- **Time**: O(n) where n = AST nodes
- **Space**: O(n) symbol tables
- **Overhead**: ~10ms for typical Builderfile

### Tier 2 Compilation & Execution
- **First run**: ~1s (D compilation)
- **Cached**: ~10ms (binary execution)
- **CTFE**: 0ms (compile-time)

### Tier 3 Plugin Invocation
- **Spawn overhead**: ~50ms per plugin
- **Execution**: Depends on plugin
- **Parallel**: Plugins run in parallel when possible

### Total Build Time Breakdown

```
Example: 100 targets, 3 macros, 2 plugins

Tier 1 parsing:          10ms
Tier 2 execution:        30ms (cached)
Build graph analysis:    50ms
Tier 3 plugins:          100ms (parallel)
Actual compilation:      60s
─────────────────────────────
Total:                   ~60s

Programmability overhead: 0.3% of total time
```

## Best Practices for Integration

### 1. Minimize Tier Transitions

**Good:**
```d
// Tier 2 does all complex work, returns simple data
let services = generateAll();  // One call

for svc in services {
    target(svc.name) { ... }
}
```

**Bad:**
```d
// Too many Tier 1 ↔ Tier 2 transitions
for svc in ["a", "b", "c"] {
    let config = generateConfig(svc);  // Called 3 times!
    target(svc) = config;
}
```

### 2. Use Right Tier for the Job

**Good:**
```d
// Tier 1 for simple list
let packages = ["a", "b", "c"];

// Tier 2 for complex algorithm
import Builderfile.d;
let graph = generateDependencyGraph();

// Tier 3 for external tools
target("deploy") { plugin: "kubernetes"; }
```

**Bad:**
```d
// Tier 2 overkill for simple list
import Builderfile.d;
let packages = generateSimpleList();  // Just use Tier 1!

// Tier 1 struggling with complex logic
let graph = {};  // 100 lines of complex nested loops
// Should use Tier 2 instead
```

### 3. Keep Interfaces Simple

**Good:**
```d
// Simple, clear interface
let services = generateServices();  // Returns string[]

for svc in services {
    target(svc) { ... }
}
```

**Bad:**
```d
// Complex, unclear interface
let result = complexMacro();  // Returns what?
let services = result.data.services.names[0];  // Unclear!
```

### 4. Handle Errors Gracefully

```d
// Tier 1 with error handling
import Builderfile.d;

let result = tryGenerateServices();
if (result.isError) {
    error("Failed to generate services: " + result.error);
}

let services = result.value;
```

## Testing Integration

### Unit Tests: Per-Tier

```bash
# Test Tier 1
builder check Builderfile

# Test Tier 2
dmd -unittest Builderfile.d
./Builderfile --test

# Test Tier 3
builder plugin test docker
```

### Integration Tests: Cross-Tier

```bash
# Test Tier 1 + Tier 2
builder build --dry-run :all

# Test Tier 1 + Tier 3
builder build --plugin-test :docker-image

# Test all tiers
builder build --test-all
```

## Debugging

### Debug Tier 1

```bash
# Verbose parsing
builder build --parse-verbose

# Show evaluated variables
builder build --show-vars
```

### Debug Tier 2

```bash
# Verbose macro compilation
builder build --macro-verbose

# Show macro output
builder build --show-macro-output
```

### Debug Tier 3

```bash
# Verbose plugin execution
builder build --plugin-verbose

# Show plugin I/O
builder build --show-plugin-io
```

## Summary

The three-tier system provides:

✅ **Progressive Complexity**: Use simplest tool for the job  
✅ **Seamless Integration**: Tiers call each other naturally  
✅ **Type Safety**: Static checks where possible, runtime checks where needed  
✅ **Performance**: Minimal overhead, optimized for speed  
✅ **Extensibility**: Easy to add new features at any tier  

**Key Insight:** Each tier does what it's best at, and integration is automatic.

