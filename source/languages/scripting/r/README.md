## R Language Support

Comprehensive, modular R language support for Builder with modern tooling integration, environment management, and multiple build modes.

## Architecture

### Core Modules

- **handler.d** - Main `RHandler` class implementing build orchestration
- **config.d** - Configuration structs and enums for all R features
- **tools.d** - Tool detection, version management, and R installation validation
- **packages.d** - Package manager abstraction (install.packages, pak, renv, remotes)
- **environments.d** - Environment management (renv, packrat) with isolation
- **checker.d** - Linting (lintr, goodpractice) and formatting (styler, formatR)
- **dependencies.d** - Dependency analysis from DESCRIPTION, renv.lock, packrat.lock
- **builders/** - Specialized builders for each build mode

### Builders

- **base.d** - Base `RBuilder` interface
- **script.d** - Script execution with wrapper generation
- **package.d** - R package building (R CMD build/check)
- **shiny.d** - Shiny application validation and launcher generation
- **rmarkdown.d** - RMarkdown document rendering

## Features

### Build Modes

- **Script** - Single file or simple script execution (default)
- **Package** - Full R package with DESCRIPTION and R CMD build/check
- **Shiny** - Shiny web application with validation
- **RMarkdown** - RMarkdown document rendering to multiple formats
- **Check** - R CMD check validation for packages
- **Vignette** - Package vignette building

### Package Managers

Automatic detection and support for:
- **install.packages** - Standard R package installation
- **pak** - Modern, fast package manager with caching (recommended)
- **renv** - Reproducible environments with lockfiles
- **packrat** - Legacy environment management
- **remotes** - Install from GitHub, GitLab, and other sources

Priority: pak > renv (if project detected) > install.packages

### Environment Management

- **renv** - Modern reproducible environment management (recommended)
- **packrat** - Legacy environment management
- **Automatic detection** from project structure
- **Lockfile support** (renv.lock, packrat.lock)
- **Snapshot/restore** workflows
- **Isolated library paths**

### Code Quality

**Linters:**
- **lintr** - Standard R linter with customizable rules
- **goodpractice** - Comprehensive package quality checks

**Formatters:**
- **styler** - Modern R code formatter (recommended)
- **formatR** - Classic R formatter

### Testing Frameworks

- **testthat** - Most popular (default if detected)
- **tinytest** - Lightweight alternative
- **RUnit** - Classic unit testing
- **Coverage support** with covr package

### Dependency Management

Parse dependencies from:
- **DESCRIPTION** - Package dependency file
- **renv.lock** - renv lockfile with versions
- **packrat.lock** - packrat lockfile
- **R files** - Automatic detection of library() calls

### Documentation

- **roxygen2** - Function documentation generation
- **pkgdown** - Package website generation
- **README.Rmd** - Dynamic README generation

## Configuration Example

```d
target("r-package") {
    type: library;
    language: r;
    sources: ["R/*.R"];
    
    r: {
        // Build mode
        mode: "package",
        
        // R version requirement
        rVersion: ">= 4.0.0",
        
        // Package manager (auto-detects best)
        packageManager: "auto",
        installDeps: true,
        
        // Environment isolation
        env: {
            enabled: true,
            manager: "renv",
            autoCreate: true,
            autoSnapshot: true,
            useCache: true
        },
        
        // Package configuration
        package: {
            name: "mypackage",
            version: "1.0.0",
            title: "My R Package",
            description: "A comprehensive R package",
            authors: ["Griffin <griffincancode@gmail.com>"],
            maintainer: "Griffin <griffincancode@gmail.com>",
            license: "MIT",
            rVersion: "4.0.0",
            buildVignettes: true,
            runCheck: true,
            checkArgs: ["--as-cran"],
            useDevtools: true,
            lazyData: true,
            roxygen2Markdown: true
        },
        
        // Testing
        test: {
            framework: "testthat",
            coverage: true,
            coverageThreshold: 80.0,
            reporter: "progress",
            parallel: true
        },
        
        // Linting
        lint: {
            linter: "lintr",
            autoFix: false,
            failOnWarnings: false
        },
        
        // Formatting
        format: {
            formatter: "styler",
            autoFormat: true,
            indentWidth: 2,
            maxLineLength: 80,
            stylerScope: "tokens"
        },
        
        // Documentation
        doc: {
            generator: "both",
            buildDocs: true,
            buildSite: true,
            includeVignettes: true
        }
    }
}
```

## Minimal Configuration

Most settings auto-detect intelligently:

```d
target("r-app") {
    type: executable;
    language: r;
    sources: ["main.R"];
    
    r: {
        installDeps: true  // Auto-detects package manager and dependencies
    }
}
```

## Design Principles

### 1. **Modular Architecture**
- Each module has single responsibility
- Easy to extend with new features
- Clean separation of concerns
- Independent testing of components

### 2. **Smart Defaults**
- Auto-detection of project structure
- Intelligent tool selection
- Minimal configuration required
- Convention over configuration

### 3. **Comprehensive Coverage**
- Support all major R workflows
- Handle scripts, packages, Shiny, RMarkdown
- Multiple package managers and tools
- Complete lifecycle management

### 4. **Reproducibility**
- Environment isolation with renv/packrat
- Lockfile support for exact versions
- Snapshot/restore workflows
- Consistent builds across machines

### 5. **Developer Experience**
- Fast builds with pak
- Comprehensive error messages
- Automatic dependency management
- Integrated linting and formatting

## Tool Detection Priority

**Package Managers:**
1. pak (fastest, best caching)
2. renv (if project detected)
3. install.packages (default)

**Linters:**
1. lintr (standard, customizable)
2. goodpractice (comprehensive)

**Formatters:**
1. styler (modern, fast)
2. formatR (classic)

**Test Frameworks:**
1. testthat (if tests/testthat/ detected)
2. tinytest
3. RUnit

**Environment Managers:**
1. renv (if renv.lock detected)
2. packrat (if packrat/ detected)

## Novel Features

### 1. **Pak Integration**
First build system to integrate pak - modern, fast R package manager with caching and parallel installation.

### 2. **Comprehensive Environment Management**
Full renv and packrat support with automatic detection, snapshot/restore, and isolation.

### 3. **Unified Package Manager Abstraction**
Consistent interface across install.packages, pak, renv, packrat, and remotes with automatic fallback.

### 4. **Integrated Code Quality**
Built-in support for lintr, styler, and goodpractice with customizable rules and auto-formatting.

### 5. **Multi-Mode Building**
Single handler supports scripts, packages, Shiny apps, and RMarkdown with appropriate validation for each.

### 6. **Smart Dependency Detection**
Automatically detects dependencies from DESCRIPTION, lockfiles, or by scanning R files for library() calls.

### 7. **Modular Builder System**
Separate builders for each mode enable specialized logic and easy extension for new R workflows.

## Build Modes in Detail

### Script Mode

Simple R script execution with wrapper generation:

```d
target("analysis") {
    type: executable;
    language: r;
    sources: ["analysis.R", "utils.R"];
    r: {
        mode: "script",
        validateSyntax: true
    }
}
```

Creates executable wrapper that sources the main script with proper R environment setup.

### Package Mode

Full R package development workflow:

```d
target("mypackage") {
    type: library;
    language: r;
    sources: ["R/*.R"];
    r: {
        mode: "package",
        package: {
            name: "mypackage",
            runCheck: true,
            buildVignettes: true,
            useDevtools: true
        }
    }
}
```

Runs R CMD build, optionally builds vignettes, and runs R CMD check with configurable arguments.

### Shiny Mode

Shiny web application with validation:

```d
target("dashboard") {
    type: executable;
    language: r;
    sources: ["app.R"];
    r: {
        mode: "shiny",
        shiny: {
            host: "0.0.0.0",
            port: 3838,
            launchBrowser: false
        }
    }
}
```

Validates app structure (app.R or server.R/ui.R) and creates launcher script.

### RMarkdown Mode

Document rendering to multiple formats:

```d
target("report") {
    type: executable;
    language: r;
    sources: ["report.Rmd"];
    r: {
        mode: "rmarkdown",
        rmarkdown: {
            format: "html",
            selfContained: true,
            params: {
                date: "2024-01-01",
                author: "Data Team"
            }
        }
    }
}
```

Renders RMarkdown to HTML, PDF, Word, or custom formats with parameter support.

## Advanced Features

### Environment Isolation

```d
r: {
    env: {
        enabled: true,
        manager: "renv",
        autoCreate: true,
        autoSnapshot: true,
        useCache: true,
        clean: false
    }
}
```

- Creates isolated environment if missing
- Restores from lockfile automatically
- Snapshots after successful build
- Uses cache for faster installs

### Code Quality Pipeline

```d
r: {
    lint: {
        linter: "lintr",
        enabledLinters: ["line_length_linter", "object_name_linter"],
        failOnWarnings: true,
        excludePatterns: ["tests/*"]
    },
    format: {
        formatter: "styler",
        autoFormat: true,
        stylerScope: "tokens",
        maxLineLength: 100
    }
}
```

Runs linter before build, auto-formats code, and optionally fails on warnings.

### Testing with Coverage

```d
target("test") {
    type: test;
    language: r;
    sources: ["tests/testthat/*.R"];
    r: {
        test: {
            framework: "testthat",
            coverage: true,
            coverageThreshold: 80.0,
            reporter: "summary",
            parallel: true,
            parallelWorkers: 4
        }
    }
}
```

Runs tests with parallel execution and coverage analysis, fails if below threshold.

### Documentation Generation

```d
r: {
    doc: {
        generator: "both",
        buildDocs: true,      // roxygen2
        buildSite: true,      // pkgdown
        siteDir: "docs",
        includeVignettes: true,
        generateReadme: true  // README.Rmd -> README.md
    }
}
```

Generates function documentation and package website in one command.

## Integration with Other Languages

R can be integrated with other languages in mixed projects:

```d
target("data-pipeline") {
    type: executable;
    language: python;
    sources: ["pipeline.py"];
    deps: ["r-analysis"];
}

target("r-analysis") {
    type: library;
    language: r;
    sources: ["analysis.R"];
}
```

Python pipeline can call R analysis as a dependency.

## Performance Characteristics

- **Package Installation**: 10-100x faster with pak vs install.packages
- **Environment Restoration**: Cached renv restores are ~5x faster
- **Parallel Testing**: testthat parallel execution scales linearly
- **Syntax Validation**: Fast AST-based validation without execution

## Best Practices

1. **Use renv for reproducibility** - Pin exact package versions
2. **Enable code quality checks** - Catch issues early with lintr
3. **Run R CMD check** - Essential for package development
4. **Use testthat for testing** - Industry standard with great tooling
5. **Enable coverage** - Track test coverage to ensure quality
6. **Build vignettes** - Document package usage with examples
7. **Use pak for speed** - Fastest package installation with caching
8. **Auto-format code** - Consistent style with styler
9. **Document with roxygen2** - Generate help files from code comments
10. **Generate websites** - Use pkgdown for package documentation sites

## Troubleshooting

### R Not Found

Ensure R and Rscript are in PATH, or specify explicitly:

```d
r: {
    rExecutable: "/usr/local/bin/Rscript",
    rCommand: "/usr/local/bin/R"
}
```

### Missing Packages

Enable automatic dependency installation:

```d
r: {
    installDeps: true,
    packageManager: "pak"  // Fastest option
}
```

### Environment Issues

Reset and recreate environment:

```d
r: {
    env: {
        enabled: true,
        clean: true,          // Remove old environment
        autoCreate: true      // Create fresh
    }
}
```

### Check Failures

Customize check arguments:

```d
r: {
    package: {
        runCheck: true,
        checkArgs: ["--no-manual", "--no-vignettes", "--no-tests"]
    }
}
```

## Examples

See `examples/r-project/` for complete working examples including:
- Simple R scripts
- R packages with tests
- Shiny applications
- RMarkdown documents
- renv-managed projects

## Resources

- [R Project](https://www.r-project.org/)
- [CRAN](https://cran.r-project.org/)
- [renv](https://rstudio.github.io/renv/)
- [pak](https://pak.r-lib.org/)
- [testthat](https://testthat.r-lib.org/)
- [lintr](https://lintr.r-lib.org/)
- [styler](https://styler.r-lib.org/)
- [roxygen2](https://roxygen2.r-lib.org/)
- [pkgdown](https://pkgdown.r-lib.org/)
- [Shiny](https://shiny.rstudio.com/)
- [RMarkdown](https://rmarkdown.rstudio.com/)
