# Builder Tools

This directory contains IDE extensions, helper scripts, and developer tooling for the Builder project.

## Directory Structure

- **vscode/** - Visual Studio Code extension for Builder language support
  - Syntax highlighting for Builderfile and Builderspace
  - Custom file icons
  - Language configuration (auto-closing, comments, etc.)
  - Packaged VSIX for distribution

## Installation

### VS Code Extension

#### Quick Install (using Builder CLI)
```bash
builder install-extension
```

#### Manual Install
```bash
code --install-extension tools/vscode/builder-lang-1.0.0.vsix
```

Then reload VS Code: `Cmd+Shift+P` → "Developer: Reload Window"

## Future Tooling

This directory can be extended with:
- JetBrains IDE plugin
- Vim/Neovim syntax files
- Emacs mode
- Shell completion scripts
- Git hooks
- Pre-commit hooks
- CI/CD helpers

