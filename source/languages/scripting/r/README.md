# R Language Support

Comprehensive R language support for the Builder build system, including scripts, packages, Shiny applications, and RMarkdown documents.

## Features

- **R Scripts**: Build and execute R scripts with dependency management
- **R Packages**: Full package development lifecycle (build, check, install)
- **Shiny Applications**: Build and validate Shiny apps
- **RMarkdown Documents**: Render RMarkdown to various formats (HTML, PDF, etc.)
- **Testing**: Support for testthat framework and test coverage
- **Dependency Management**: Automatic installation of CRAN, Bioconductor, and GitHub packages
- **Import Analysis**: Automatic detection of library() and source() dependencies

## Build Modes

### 1. Script Mode (Default)

Build and run R scripts:

```
target("my-script") {
    type: executable;
    language: r;
    sources: ["main.R"];
}
```

### 2. Package Mode

Build R packages with full DESCRIPTION support:

```
target("my-package") {
    type: library;
    language: r;
    sources: ["R/*.R"];
    config: {
        mode: "package";
        package: {
            name: "mypackage";
            version: "1.0.0";
            title: "My R Package";
            description: "A comprehensive R package";
            authors: ["John Doe <john@example.com>"];
            maintainer: "John Doe <john@example.com>";
            license: "MIT";
            rVersion: "3.5.0";
            buildVignettes: true;
            runCheck: true;
        };
    };
}
```

### 3. Shiny Mode

Build Shiny web applications:

```
target("my-shiny-app") {
    type: executable;
    language: r;
    sources: ["app.R"];
    config: {
        mode: "shiny";
        shinyHost: "127.0.0.1";
        shinyPort: 8080;
    };
}
```

### 4. RMarkdown Mode

Render RMarkdown documents:

```
target("my-report") {
    type: executable;
    language: r;
    sources: ["report.Rmd"];
    config: {
        mode: "rmarkdown";
        rmdFormat: "html_document";
    };
}
```

### 5. Check Mode

Run R CMD check on packages:

```
target("check-package") {
    type: test;
    language: r;
    sources: ["R/*.R"];
    config: {
        mode: "check";
        package: {
            checkArgs: ["--as-cran", "--no-manual"];
        };
    };
}
```

## Configuration Options

### Basic Configuration

- **mode**: Build mode (script, package, shiny, rmarkdown, check)
- **rExecutable**: Path to Rscript executable (default: "Rscript")
- **rCommand**: Path to R command (default: "R")
- **installDeps**: Auto-install dependencies (default: false)
- **cranMirror**: CRAN mirror URL (default: https://cloud.r-project.org)
- **libPaths**: Additional R library paths
- **workDir**: Working directory for R execution
- **outDir**: Output directory

### Package Configuration

```
package: {
    name: "mypackage";
    version: "1.0.0";
    title: "My Package Title";
    description: "Detailed package description";
    authors: ["Author Name <email@example.com>"];
    maintainer: "Maintainer <email@example.com>";
    license: "MIT";
    rVersion: "3.5.0";
    buildVignettes: false;
    runCheck: false;
    checkArgs: ["--as-cran"];
};
```

### Test Configuration

```
test: {
    useTestthat: true;
    coverage: false;
    coverageFormat: "html";
    reporter: "progress";
    stopOnFailure: false;
};
```

### Dependency Configuration

R packages are typically specified in DESCRIPTION files. The handler supports:

- **Depends**: Required R version and essential packages
- **Imports**: Packages imported by the package
- **Suggests**: Optional packages for examples/tests

For automatic installation:

```
config: {
    installDeps: true;
    cranMirror: "https://cran.r-project.org";
    additionalRepos: [
        "https://bioconductor.org/packages/release/bioc"
    ];
};
```

### Shiny Configuration

```
config: {
    mode: "shiny";
    shinyHost: "127.0.0.1";
    shinyPort: 8080;
};
```

### RMarkdown Configuration

```
config: {
    mode: "rmarkdown";
    rmdFormat: "html_document";  // or pdf_document, word_document, etc.
};
```

## Testing

### testthat Tests

```
target("tests") {
    type: test;
    language: r;
    sources: ["tests/testthat/*.R"];
    config: {
        test: {
            useTestthat: true;
            reporter: "summary";
            coverage: true;
            coverageFormat: "html";
        };
    };
}
```

### Direct R Test Scripts

```
target("test-scripts") {
    type: test;
    language: r;
    sources: ["tests/test_*.R"];
    config: {
        test: {
            useTestthat: false;
        };
    };
}
```

## Project Structure

### R Package Structure

```
my-package/
├── DESCRIPTION          # Auto-detected
├── NAMESPACE
├── R/                   # R source files
│   ├── functions.R
│   └── utils.R
├── tests/
│   └── testthat/       # Test files
│       └── test-functions.R
├── man/                # Documentation
├── vignettes/          # Vignettes
└── Builderfile
```

### Shiny App Structure

```
my-app/
├── app.R               # Single-file Shiny app
└── Builderfile

# OR

my-app/
├── server.R            # Server logic
├── ui.R                # UI definition
├── global.R            # (optional)
└── Builderfile
```

### Script Project Structure

```
my-script/
├── main.R
├── utils.R
└── Builderfile
```

## Import Detection

The R handler automatically detects and analyzes:

- **library()** calls - External package dependencies
- **require()** calls - External package dependencies
- **source()** calls - Local script dependencies
- **load()** calls - R data file dependencies

Example:

```r
# Detected as external dependencies
library(dplyr)
require(ggplot2)

# Detected as local dependencies
source("utils.R")
source("helpers/math.R")

# Detected as data dependencies
load("data/dataset.RData")
```

## Environment Variables

The R handler respects and can set:

- **R_LIBS_USER**: User R library path
- **R_HOME**: R installation directory
- Custom variables via `rEnv` configuration

```
config: {
    rEnv: {
        R_LIBS_USER: "/custom/lib/path";
        MY_VAR: "value";
    };
};
```

## Examples

### Simple R Script

```
target("analyze-data") {
    type: executable;
    language: r;
    sources: ["analyze.R"];
    config: {
        installDeps: true;
    };
}
```

### Complete R Package

```
target("my-package") {
    type: library;
    language: r;
    sources: ["R/*.R"];
    config: {
        mode: "package";
        installDeps: true;
        package: {
            name: "mypackage";
            version: "1.0.0";
            title: "My Data Analysis Package";
            description: "Tools for analyzing data";
            authors: ["Data Team <team@example.com>"];
            license: "GPL-3";
            buildVignettes: true;
            runCheck: true;
            checkArgs: ["--as-cran"];
        };
    };
}

target("test-package") {
    type: test;
    language: r;
    sources: ["tests/testthat/*.R"];
    deps: ["my-package"];
    config: {
        test: {
            useTestthat: true;
            coverage: true;
            reporter: "summary";
        };
    };
}
```

### Shiny Dashboard

```
target("dashboard") {
    type: executable;
    language: r;
    sources: ["app.R", "modules/*.R"];
    config: {
        mode: "shiny";
        installDeps: true;
        shinyHost: "0.0.0.0";
        shinyPort: 3838;
    };
}
```

### RMarkdown Report Pipeline

```
target("report") {
    type: executable;
    language: r;
    sources: ["report.Rmd"];
    deps: ["data-processing"];
    config: {
        mode: "rmarkdown";
        rmdFormat: "html_document";
        installDeps: true;
    };
}

target("pdf-report") {
    type: executable;
    language: r;
    sources: ["report.Rmd"];
    deps: ["data-processing"];
    config: {
        mode: "rmarkdown";
        rmdFormat: "pdf_document";
    };
}
```

## Best Practices

1. **Use DESCRIPTION Files**: For packages, always maintain a proper DESCRIPTION file
2. **Version Control Dependencies**: Specify package versions when needed
3. **Enable Coverage**: Use coverage analysis for better test quality
4. **Run R CMD check**: Always check packages before release
5. **Use testthat**: Standard R testing framework with good IDE integration
6. **Separate Logic**: Keep business logic separate from Shiny UI code
7. **Document Functions**: Use roxygen2 for function documentation
8. **Use renv**: Consider renv for reproducible environments

## Troubleshooting

### R Not Found

Ensure R and Rscript are in your PATH, or specify explicitly:

```
config: {
    rExecutable: "/usr/local/bin/Rscript";
    rCommand: "/usr/local/bin/R";
};
```

### Missing Packages

Enable automatic dependency installation:

```
config: {
    installDeps: true;
};
```

### Package Check Failures

Review check arguments and ensure DESCRIPTION is complete:

```
config: {
    package: {
        runCheck: true;
        checkArgs: ["--no-manual", "--no-vignettes"];
    };
};
```

### Shiny App Issues

Verify app structure (app.R or server.R/ui.R):

```bash
# Single file
app.R

# OR multi-file
server.R
ui.R
```

## Integration with Other Languages

R can be integrated with other languages in mixed projects:

```
target("python-r-pipeline") {
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

## Performance Considerations

- **Parallel Testing**: R's testthat supports parallel test execution
- **Compiled Code**: Consider using Rcpp for performance-critical code
- **Caching**: Builder automatically caches R package builds
- **Dependencies**: Minimize dependencies for faster builds

## Resources

- [R Project](https://www.r-project.org/)
- [CRAN](https://cran.r-project.org/)
- [Bioconductor](https://www.bioconductor.org/)
- [testthat](https://testthat.r-lib.org/)
- [R Packages Book](https://r-pkgs.org/)
- [Shiny](https://shiny.rstudio.com/)
- [RMarkdown](https://rmarkdown.rstudio.com/)

