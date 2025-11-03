# CLI Commands

This directory contains all CLI command implementations for the Builder system, organized into logical categories for maintainability and ease of navigation.

## Directory Structure

```
commands/
├── README.md                    # This file
├── package.d                    # Main barrel export
│
├── execution/                   # Build execution and analysis
│   ├── package.d
│   ├── discover.d              # Preview dynamic dependency discovery
│   ├── query.d                 # Query build graph and configuration
│   ├── test.d                  # Execute tests with filtering
│   └── infer.d                 # Infer build configuration
│
├── project/                     # Project management
│   ├── package.d
│   ├── init.d                  # Initialize new Builder project
│   ├── wizard.d                # Interactive project setup
│   └── migrate.d               # Migrate from other build systems
│
├── infrastructure/              # Distributed build infrastructure
│   ├── package.d
│   ├── cacheserver.d           # Start remote cache server
│   ├── coordinator.d           # Start build coordinator
│   └── worker.d                # Start build worker node
│
├── extensions/                  # Extensions and dev tools
│   ├── package.d
│   ├── plugin.d                # Manage Builder plugins
│   ├── telemetry.d             # View/configure telemetry
│   └── watch.d                 # Watch mode for auto-rebuilds
│
└── help/                        # Help and documentation
    ├── package.d
    └── help.d                  # Display help information
```

## Command Categories

### Execution Commands (`execution/`)

Commands for building, testing, querying, and analyzing the build graph:

- **discover**: Preview dynamic dependency discovery without building
- **query**: Query the build graph and configuration
- **test**: Execute tests with advanced filtering and reporting
- **infer**: Infer build configuration from source code

### Project Management (`project/`)

Commands for project initialization, configuration, and migration:

- **init**: Initialize a new Builder project with Builderfile and Builderspace
- **wizard**: Interactive wizard for project setup and configuration
- **migrate**: Migrate from other build systems (Bazel, Make, CMake, etc.)

### Infrastructure Commands (`infrastructure/`)

Commands for managing distributed build infrastructure:

- **cacheserver**: Start a remote cache server for distributed builds
- **coordinator**: Start a build coordinator for distributed execution
- **worker**: Start a build worker node for distributed execution

### Extensions & Observability (`extensions/`)

Commands for plugins, monitoring, and development tools:

- **plugin**: Manage Builder plugins (install, remove, list)
- **telemetry**: View and configure telemetry settings
- **watch**: Watch mode for automatic rebuilds on file changes

### Help & Documentation (`help/`)

Commands for displaying help information:

- **help**: Display comprehensive help information for all commands

## Usage Patterns

### Command Structure

Each command module follows a consistent pattern:

```d
module frontend.cli.commands.category.commandname;

// Command implementation as struct or function
struct CommandNameCommand
{
    static void execute(string[] args)
    {
        // Command logic here
    }
}

// Alternative: Function-based command
void commandNameCommand(string[] args)
{
    // Command logic here
}
```

### Barrel Exports

Each subdirectory contains a `package.d` file that re-exports all commands in that category:

```d
module frontend.cli.commands.category;

public import frontend.cli.commands.category.command1;
public import frontend.cli.commands.category.command2;
```

This allows importing entire categories:

```d
import frontend.cli.commands.execution;  // Import all execution commands
import frontend.cli.commands.project;    // Import all project commands
```

Or importing the entire commands package:

```d
import frontend.cli.commands;  // Import all commands
```

## Adding New Commands

To add a new command:

1. **Choose the appropriate category** or create a new one if needed
2. **Create the command file** in the category directory
3. **Implement the command** following the existing patterns
4. **Add the import** to the category's `package.d` file
5. **Update this README** with the new command description

### Example: Adding a New Command

```bash
# 1. Create the command file
touch source/frontend/cli/commands/execution/newcommand.d

# 2. Implement the command
# (edit newcommand.d with your implementation)

# 3. Add to package.d
# Add this line to execution/package.d:
# public import frontend.cli.commands.execution.newcommand;

# 4. Update this README
# Add documentation for your new command
```

## Design Principles

1. **Modularity**: Each command is self-contained in its own module
2. **Organization**: Commands are grouped by logical category
3. **Consistency**: All commands follow similar patterns and interfaces
4. **Discoverability**: Barrel exports make it easy to find and import commands
5. **Documentation**: Each category and command is well-documented

## Dependencies

Commands typically depend on:

- `engine.*` - Core build engine functionality
- `infrastructure.*` - Infrastructure services (config, analysis, etc.)
- `frontend.cli.control.*` - Terminal control and formatting
- `frontend.cli.display.*` - Display and output formatting

## Testing

Command tests are located in `tests/integration/` and follow the pattern:

```
tests/integration/commands/test_commandname.d
```

Each command should have comprehensive integration tests covering:

- Argument parsing
- Error handling
- Success cases
- Edge cases

## See Also

- [CLI User Guide](../../../docs/user-guides/cli.md)
- [Frontend Architecture](../README.md)
- [Command Help System](help/help.d)

