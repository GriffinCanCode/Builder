# Perl Language Support

Comprehensive Perl language support for the Builder build system.

## Features

### Build Modes
- **Script** - Single file or simple scripts
- **Module** - Perl modules and libraries (.pm files)
- **Application** - Multi-file applications
- **CPAN** - Full CPAN distributions with Build.PL or Makefile.PL

### Package Managers
- **cpanm** (cpanminus) - Modern, fast CPAN client (recommended)
- **cpm** - Fast parallel CPAN installer
- **cpan** - Traditional CPAN client
- **carton** - Bundler-like dependency management
- Auto-detection of available tools

### Testing Frameworks
- **prove** - Command-line test runner (recommended)
- **Test::More** - Standard Perl testing
- **Test2** - Modern testing framework
- **Test::Class** - xUnit-style testing
- **TAP::Harness** - Test Anything Protocol harness
- Coverage with Devel::Cover
- Parallel test execution

### Code Quality
- **perltidy** - Code formatting
- **Perl::Critic** - Policy-based linting
- Syntax checking (`perl -c`)
- Configurable severity levels
- Custom policy themes

### Build Tools
- **Module::Build** (Build.PL)
- **ExtUtils::MakeMaker** (Makefile.PL)
- **Dist::Zilla** - Comprehensive distribution builder
- **Minilla** - Lightweight alternative to Dist::Zilla
- Auto-detection from project structure

### Documentation
- **POD** (Plain Old Documentation)
- pod2html - HTML documentation generation
- pod2man - Manual page generation
- Automatic extraction from source files

## Configuration

### Basic Script Example

```
target script {
    type = "executable"
    language = "perl"
    sources = ["script.pl"]
}
```

### Module Example

```
target mymodule {
    type = "library"
    language = "perl"
    sources = ["lib/MyModule.pm"]
    
    langConfig = {
        "perl": {
            "mode": "module",
            "packageManager": "cpanm",
            "installDeps": true,
            "modules": [
                {"name": "Moose", "version": "2.2206"},
                {"name": "DBI"},
                {"name": "DBD::SQLite", "optional": true}
            ]
        }
    }
}
```

### CPAN Distribution Example

```
target cpan_dist {
    type = "library"
    language = "perl"
    sources = ["lib/**/*.pm"]
    
    langConfig = {
        "perl": {
            "mode": "cpan",
            "buildTool": "modulebuild",  // or "makemaker", "distzilla", "minilla"
            "packageManager": "cpanm",
            "installDeps": true,
            "format": {
                "formatter": "both",  // perltidy and perlcritic
                "autoFormat": true,
                "perltidyrc": ".perltidyrc",
                "perlcriticrc": ".perlcriticrc",
                "critic": {
                    "severity": 3,  // 1 (brutal) to 5 (gentle)
                    "theme": "core",
                    "exclude": ["ProhibitPostfixControls"]
                }
            },
            "documentation": {
                "generator": "both",  // HTML and man pages
                "generateMan": true,
                "outputDir": "doc"
            }
        }
    }
}
```

### Testing Example

```
target tests {
    type = "test"
    language = "perl"
    sources = ["t/*.t"]
    
    langConfig = {
        "perl": {
            "test": {
                "framework": "prove",
                "testPaths": ["t/"],
                "coverage": true,
                "coverageTool": "cover",
                "parallel": true,
                "jobs": 4,
                "prove": {
                    "verbose": true,
                    "lib": true,
                    "recurse": true,
                    "color": true,
                    "timer": true,
                    "includes": ["lib", "blib/lib"]
                }
            }
        }
    }
}
```

### Advanced Configuration

```
target advanced_perl {
    type = "executable"
    language = "perl"
    sources = ["bin/app.pl", "lib/**/*.pm"]
    
    langConfig = {
        "perl": {
            "mode": "application",
            "perlVersion": "5.38.0",
            "packageManager": "carton",
            "installDeps": true,
            
            // CPAN configuration
            "cpan": {
                "useLocalLib": true,
                "localLibDir": "local",
                "mirrors": ["https://cpan.metacpan.org/"]
            },
            
            // Include directories
            "includeDirs": ["lib", "local/lib/perl5"],
            
            // Perl flags
            "perlFlags": ["-Mstrict", "-Mwarnings"],
            "warnings": true,
            "strict": true,
            
            // Environment variables
            "env": {
                "PERL5LIB": "lib:local/lib/perl5",
                "PERL_CPANM_OPT": "--local-lib=./local"
            },
            
            // Dependencies
            "modules": [
                {"name": "Mojolicious", "version": "9.34"},
                {"name": "Moo"},
                {"name": "Path::Tiny"},
                {"name": "JSON::XS"},
                {"name": "YAML::XS"},
                {"name": "DBI"},
                {"name": "DBD::Pg"},
                {"name": "Test::More", "phase": "test"},
                {"name": "Test::Pod", "phase": "test", "optional": true}
            ],
            
            // Formatting
            "format": {
                "formatter": "both",
                "autoFormat": true,
                "perltidyrc": ".perltidyrc",
                "critic": {
                    "severity": 4,
                    "theme": "core + bugs",
                    "verbose": true,
                    "color": true,
                    "include": [
                        "ProhibitStringyEval",
                        "RequireUseWarnings"
                    ],
                    "exclude": [
                        "ProhibitPostfixControls",
                        "ProhibitComplexMappings"
                    ]
                },
                "failOnCritic": false
            },
            
            // Testing
            "test": {
                "framework": "prove",
                "testPaths": ["t/", "xt/"],
                "verbose": false,
                "coverage": true,
                "coverageDir": "cover_db",
                "parallel": true,
                "jobs": 8,
                "prove": {
                    "lib": true,
                    "recurse": true,
                    "color": true,
                    "timer": true,
                    "formatter": "TAP::Formatter::HTML"
                }
            },
            
            // Documentation
            "documentation": {
                "generator": "both",
                "outputDir": "docs",
                "generateMan": true,
                "manSection": 3
            }
        }
    }
}
```

## Package Managers

### cpanm (Recommended)
Fast, zero-config CPAN client.

Install: `curl -L https://cpanmin.us | perl - App::cpanminus`

### cpm
Fast parallel CPAN installer.

Install: `cpanm App::cpm`

### carton
Dependency management like Bundler for Ruby.

Install: `cpanm Carton`

Usage: Create `cpanfile` with dependencies, run `carton install`

## Build Tools

### Module::Build (Build.PL)
Modern pure-Perl build system.

Example Build.PL:
```perl
use Module::Build;

my $builder = Module::Build->new(
    module_name => 'My::Module',
    license     => 'perl',
    requires    => {
        'Moose' => '2.2206',
    },
    build_requires => {
        'Test::More' => 0,
    },
);

$builder->create_build_script();
```

Build: `perl Build.PL && ./Build`

### ExtUtils::MakeMaker (Makefile.PL)
Traditional Perl build system.

Example Makefile.PL:
```perl
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'My::Module',
    VERSION_FROM => 'lib/My/Module.pm',
    PREREQ_PM    => {
        'Moose' => '2.2206',
    },
);
```

Build: `perl Makefile.PL && make`

### Dist::Zilla
Comprehensive distribution builder with plugins.

Install: `cpanm Dist::Zilla`

Configuration: `dist.ini`

Build: `dzil build`

### Minilla
Lightweight alternative to Dist::Zilla.

Install: `cpanm Minilla`

Configuration: `minil.toml`

Build: `minil build`

## Testing

### Test File Structure
```
t/
  00-load.t
  01-basic.t
  02-advanced.t
  author/
    critic.t
    pod.t
```

### Example Test (Test::More)
```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;

use_ok('My::Module');

my $obj = My::Module->new();
isa_ok($obj, 'My::Module');

is($obj->method(), 'expected', 'method returns expected value');
```

### Running Tests
```bash
# With prove (recommended)
prove -l t/

# With prove (verbose, parallel)
prove -lvj8 t/

# Direct execution
perl t/00-load.t

# With coverage
cover -delete
HARNESS_PERL_SWITCHES=-MDevel::Cover prove -l t/
cover
```

## Code Quality Tools

### perltidy
Code formatting tool.

Install: `cpanm Perl::Tidy`

Configuration: `.perltidyrc`

Usage: `perltidy -b file.pl`

### Perl::Critic
Policy-based linting.

Install: `cpanm Perl::Critic`

Configuration: `.perlcriticrc`

Usage: `perlcritic --severity 3 file.pl`

Severity levels:
- 1: Brutal (only critical violations)
- 2: Cruel
- 3: Harsh (recommended for production)
- 4: Stern
- 5: Gentle (all policies)

## Best Practices

1. **Use strict and warnings**: Always enable with `use strict; use warnings;`
2. **Write tests**: Use Test::More or Test2
3. **Document with POD**: Inline documentation
4. **Format code**: Use perltidy for consistency
5. **Lint regularly**: Use Perl::Critic to catch issues early
6. **Manage dependencies**: Use cpanfile or Build.PL/Makefile.PL
7. **Version control**: Include `META.json`, `META.yml` in .gitignore
8. **Local libraries**: Use local::lib for user-level installs

## Integration with Builder

Builder automatically:
1. Detects Perl files (`.pl`, `.pm`, `.t`)
2. Checks syntax with `perl -c`
3. Runs tests in `t/` directory
4. Installs CPAN dependencies
5. Formats code with perltidy
6. Lints with Perl::Critic
7. Generates documentation from POD

## Resources

- [Perl Documentation](https://perldoc.perl.org/)
- [CPAN](https://metacpan.org/)
- [Modern Perl](http://modernperlbooks.com/)
- [Perl Best Practices](https://www.oreilly.com/library/view/perl-best-practices/0596001738/)
- [Perl::Critic Policies](https://metacpan.org/pod/Perl::Critic)

