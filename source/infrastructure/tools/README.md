# Tools Package

The Tools package provides IDE integration and developer tooling support for Builder.

## Modules

### VS Code Integration

- **extension.d** - VS Code extension installation and management

## Usage

```d
import tools;

// Install VS Code extension
if (VSCodeExtension.install())
{
    writeln("Extension installed successfully");
}

// Check if already installed
if (VSCodeExtension.isInstalled())
{
    writeln("Extension is already installed");
}
```

## Features

- Automatic VS Code extension detection and installation
- Multiple search path resolution
- VS Code CLI availability checking
- User-friendly error messages and guidance

