# Builder Language Support

This extension provides syntax highlighting and language support for Builder configuration files.

## Features

- **Syntax Highlighting**: Full TextMate grammar for Builderfile and Builderspace files
- **Custom Icon**: Distinctive icon for Builder configuration files
- **Smart Features**:
  - Auto-closing brackets and quotes
  - Comment toggling (Cmd+/)
  - Bracket matching
  - Code folding
  - Auto-indentation

## Supported Files

- `Builderfile` - Build target definitions
- `Builderspace` - Workspace configuration
- `*.builder` - Any file with .builder extension

## Language Features

### Syntax Highlighting Includes:

- **Keywords**: `target`, `workspace`, `type`, `language`, `sources`, etc.
- **Types**: `executable`, `library`, `test`, `static`, `shared`
- **Language Sections**: `go`, `rust`, `cpp`, `python`, `javascript`, etc.
- **Properties**: All configuration properties
- **Strings**: Double and single quoted strings with escape sequences
- **Numbers**: Integer and decimal numbers
- **Booleans**: `true`, `false`
- **Comments**: Line (`//`) and block (`/* */`) comments

## Installation

### For Local Development

This extension is automatically loaded when you open this workspace in VS Code.

### For Team-Wide Installation

#### Option 1: Manual Installation
1. Copy the `.vscode/extensions/builder-lang` folder to your VS Code extensions directory:
   - **macOS/Linux**: `~/.vscode/extensions/builder-lang`
   - **Windows**: `%USERPROFILE%\.vscode\extensions\builder-lang`
2. Reload VS Code

#### Option 2: Package as VSIX
```bash
# Install vsce (VS Code Extension Manager)
npm install -g @vscode/vsce

# From the extension directory
cd .vscode/extensions/builder-lang
vsce package

# This creates builder-lang-1.0.0.vsix
# Install with: code --install-extension builder-lang-1.0.0.vsix
```

#### Option 3: Publish to VS Code Marketplace
```bash
# Create a publisher account at https://marketplace.visualstudio.com/
vsce publish
```

## Using the Custom Icons

To enable the custom Builder file icons:

1. Open VS Code Command Palette (Cmd+Shift+P / Ctrl+Shift+P)
2. Type "File Icon Theme"
3. Select "Builder Icons"

## Configuration

The extension automatically associates the following files:
- All files named `Builderfile`
- All files named `Builderspace`
- Files with `.builder` extension

## Development

To modify the syntax highlighting:

1. Edit `syntaxes/builder.tmLanguage.json`
2. Reload VS Code window (Cmd+Shift+P → "Developer: Reload Window")
3. Test your changes

To modify the icon:

1. Edit `icons/file-icon.svg`
2. Reload VS Code window

## License

Same as the Builder project.

