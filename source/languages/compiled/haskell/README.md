# Haskell Language Support

Comprehensive Haskell language support for Builder with GHC, Cabal, and Stack integration.

## Features

### Compiler Support
- **GHC** (Glasgow Haskell Compiler) - Direct compilation
- **Cabal** - Package management and building
- **Stack** - Curated package sets and reproducible builds

### Build Modes
- Executable compilation
- Library building
- Test execution
- Documentation generation (Haddock)

### Code Quality Tools
- **HLint** - Haskell linter for suggesting improvements
- **Ormolu** - Opinionated Haskell formatter
- **Fourmolu** - Alternative Haskell formatter

### Optimization
- Three optimization levels: O0, O1, O2
- Link-time optimization (LTO) support
- Profiling support
- Code coverage support

### Advanced Features
- Language extensions (OverloadedStrings, GADTs, etc.)
- Parallel compilation
- Threaded runtime support
- Static and dynamic linking
- Custom GHC options
- Multiple package dependencies

## Module Structure

```
haskell/
├── core/
│   ├── config.d       # Configuration structures and parsing
│   ├── handler.d      # Main build handler
│   └── package.d      # Module exports
├── tooling/
│   ├── ghc.d          # GHC compiler wrapper
│   ├── cabal.d        # Cabal build tool wrapper
│   ├── stack.d        # Stack build tool wrapper
│   └── package.d      # Module exports
├── analysis/
│   ├── cabal.d        # Cabal file parsing
│   └── package.d      # Module exports
├── package.d          # Top-level exports
└── README.md          # This file
```

## Usage

### Basic GHC Compilation

```d
import languages.compiled.haskell;

auto handler = new HaskellHandler();
auto result = handler.build(target, config);
```

### Builderfile Configuration

#### Simple GHC Build

```yaml
targets:
  - name: my-app
    type: executable
    language: haskell
    sources:
      - Main.hs
    config:
      haskell:
        buildTool: ghc
        optLevel: "2"
```

#### Cabal Project

```yaml
targets:
  - name: my-project
    type: executable
    language: haskell
    sources:
      - src/**/*.hs
    config:
      haskell:
        buildTool: cabal
        optLevel: "2"
        parallel: true
        haddock: true
        hlint: true
```

#### Stack Project

```yaml
targets:
  - name: my-project
    type: executable
    language: haskell
    sources:
      - src/**/*.hs
    config:
      haskell:
        buildTool: stack
        resolver: "lts-21.22"
        parallel: true
        jobs: 4
```

## Configuration Options

### Build Tool Selection

```yaml
haskell:
  buildTool: auto    # Options: auto, ghc, cabal, stack
```

- `auto`: Detects based on presence of `.cabal` or `stack.yaml`
- `ghc`: Direct GHC compilation (fastest for simple projects)
- `cabal`: Uses Cabal package manager
- `stack`: Uses Stack build tool

### Build Mode

```yaml
haskell:
  mode: compile      # Options: compile, library, test, doc, custom
```

### Optimization Levels

```yaml
haskell:
  optLevel: "2"      # Options: "0", "1", "2"
```

- `O0`: No optimization (fastest compilation)
- `O1`: Basic optimization
- `O2`: Full optimization (default, best runtime performance)

### Language Standard

```yaml
haskell:
  standard: haskell2010  # Options: haskell98, haskell2010
```

### Language Extensions

```yaml
haskell:
  extensions:
    - OverloadedStrings
    - GADTs
    - TypeFamilies
    - DataKinds
    - KindSignatures
    - MultiParamTypeClasses
    - FlexibleInstances
    - FlexibleContexts
```

### Compiler Options

```yaml
haskell:
  ghcOptions:
    - -Wall                    # All warnings
    - -Wcompat                 # Compatibility warnings
    - -Wno-unused-imports      # Disable unused import warnings
    - -fno-warn-orphans        # Disable orphan warnings
```

### Warnings

```yaml
haskell:
  warnings: true     # Enable warnings
  werror: false      # Treat warnings as errors
```

### Code Quality

```yaml
haskell:
  hlint: true        # Run HLint
  ormolu: true       # Run Ormolu formatter
  fourmolu: false    # Run Fourmolu formatter
```

### Parallel Compilation

```yaml
haskell:
  parallel: true     # Enable parallel compilation
  jobs: 4            # Number of parallel jobs (0 = auto)
```

### Profiling and Coverage

```yaml
haskell:
  profiling: true    # Enable profiling
  coverage: true     # Enable code coverage
```

### Runtime Options

```yaml
haskell:
  threaded: true     # Enable threaded runtime
  static: true       # Enable static linking
  dynamic: false     # Enable dynamic linking
```

### Package Dependencies

```yaml
haskell:
  packages:
    - text
    - bytestring
    - containers
    - aeson
```

### Include and Library Directories

```yaml
haskell:
  includeDirs:
    - include/
  libDirs:
    - lib/
```

### Cabal-Specific Options

```yaml
haskell:
  buildTool: cabal
  cabalFile: "myproject.cabal"
  cabalFreeze: true     # Use frozen dependencies
```

### Stack-Specific Options

```yaml
haskell:
  buildTool: stack
  stackFile: "stack.yaml"
  resolver: "lts-21.22"  # LTS Haskell resolver
```

### Documentation

```yaml
haskell:
  haddock: true         # Generate Haddock documentation
```

### Test Options

```yaml
haskell:
  mode: test
  testOptions:
    - --test-show-details=direct
    - --test-option=--color=always
```

## Build Tool Detection

The handler automatically detects the appropriate build tool:

1. If `buildTool: auto` (default):
   - Checks for `stack.yaml` → uses Stack
   - Checks for `*.cabal` → uses Cabal
   - Otherwise → uses GHC directly

2. Explicit selection overrides detection:
   ```yaml
   haskell:
     buildTool: cabal  # Force Cabal even if stack.yaml exists
   ```

## Import Analysis

The handler analyzes Haskell imports to track dependencies:

```haskell
import Data.List           -- External import
import qualified Data.Map  -- Qualified import
import Control.Monad (forM, when)  -- Selective import
```

All imports are tracked and included in the dependency graph.

## Examples

### Simple Executable

```yaml
- name: hello
  type: executable
  language: haskell
  sources:
    - Main.hs
  config:
    haskell:
      buildTool: ghc
      optLevel: "2"
```

### Library with Tests

```yaml
- name: mylib
  type: library
  language: haskell
  sources:
    - src/Lib.hs
  config:
    haskell:
      buildTool: cabal
      haddock: true

- name: mylib-tests
  type: test
  language: haskell
  sources:
    - test/Spec.hs
  deps:
    - mylib
  config:
    haskell:
      buildTool: cabal
      mode: test
```

### Advanced Configuration

```yaml
- name: advanced-app
  type: executable
  language: haskell
  sources:
    - app/Main.hs
  config:
    haskell:
      buildTool: cabal
      optLevel: "2"
      parallel: true
      jobs: 8
      hlint: true
      ormolu: true
      warnings: true
      werror: true
      extensions:
        - OverloadedStrings
        - GADTs
        - TypeFamilies
      ghcOptions:
        - -Wall
        - -Wcompat
      packages:
        - text
        - aeson
        - http-client
      profiling: false
      threaded: true
```

## Error Handling

The handler provides detailed error messages:

- Compiler not found errors
- Compilation errors with line numbers
- HLint suggestions
- Missing dependencies

## Performance

### Build Tool Performance

- **GHC Direct**: Fastest for single-file projects
- **Cabal**: Good for projects with dependencies
- **Stack**: Best for reproducible builds with curated packages

### Optimization Impact

- `-O0`: Fast compilation, slow runtime
- `-O1`: Balanced
- `-O2`: Slow compilation, fast runtime (recommended for production)

### Parallel Builds

Enable parallel compilation for faster builds:

```yaml
haskell:
  parallel: true
  jobs: 0  # Auto-detect CPU count
```

## Integration

### With Language Registry

The handler is registered for `.hs`, `.lhs`, and `.hsc` files:

```d
// Automatic detection
auto lang = inferLanguageFromExtension(".hs");  // TargetLanguage.Haskell
```

### With Project Detector

Haskell projects are detected by:
- `.hs` source files
- `.cabal` files (higher confidence)
- `stack.yaml` files (higher confidence)

## Dependencies

### Required
- GHC (Glasgow Haskell Compiler)

### Optional
- Cabal (for Cabal-based projects)
- Stack (for Stack-based projects)
- HLint (for linting)
- Ormolu (for formatting)
- Fourmolu (alternative formatter)

## Installation

### GHCup (Recommended)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ghcup install ghc
ghcup install cabal
```

### Package Managers

```bash
# macOS
brew install ghc cabal-install stack

# Ubuntu/Debian
sudo apt-get install ghc cabal-install haskell-stack

# Arch Linux
sudo pacman -S ghc cabal-install stack
```

### Code Quality Tools

```bash
# Using Cabal
cabal install hlint ormolu fourmolu

# Using Stack
stack install hlint ormolu fourmolu
```

## Limitations

1. **GHC Direct Mode**: Limited to single-file or simple multi-file projects
2. **Library Building**: Requires Cabal or Stack for proper library support
3. **Cross-Compilation**: Not yet fully supported
4. **Cabal File Generation**: Must be created manually or with `cabal init`

## Future Enhancements

- [ ] Automatic Cabal file generation
- [ ] Cross-compilation support
- [ ] GHC plugin support
- [ ] More granular dependency tracking
- [ ] Haskell Language Server integration
- [ ] Template Haskell support detection
- [ ] Benchmark support

## Contributing

When adding features to Haskell support:

1. Update configuration in `core/config.d`
2. Implement in appropriate wrapper (`ghc.d`, `cabal.d`, `stack.d`)
3. Add handler logic in `core/handler.d`
4. Update this README
5. Add tests
6. Update example project

## See Also

- [Haskell Official Documentation](https://www.haskell.org/documentation/)
- [GHC User Guide](https://downloads.haskell.org/ghc/latest/docs/users_guide/)
- [Cabal User Guide](https://www.haskell.org/cabal/users-guide/)
- [Stack Documentation](https://docs.haskellstack.org/)
- [HLint](https://github.com/ndmitchell/hlint)
- [Ormolu](https://github.com/tweag/ormolu)

