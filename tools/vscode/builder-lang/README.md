# Builder Language Support for VS Code

Complete language support for Builder configuration files with Language Server Protocol (LSP).

## Features

### 🎨 Syntax Highlighting
- Full syntax highlighting for `Builderfile` and `Builderspace` files
- Custom file icons for `Builderfile`, `Builderspace`, and `.builderignore` (works with any icon theme!)
- Auto-closing brackets and quotes
- Comment toggling (Cmd+/)
- Smart code folding

### 🚀 Language Server Protocol (LSP)
- **Autocomplete**: Smart suggestions for fields, types, languages, and dependencies
- **Diagnostics**: Real-time error detection and validation
- **Go to Definition**: Jump to target definitions (F12)
- **Hover Information**: Rich documentation on hover
- **Find References**: Find all uses of a target (Shift+F12)
- **Rename Refactoring**: Rename targets across all Builderfiles (F2)

## Installation

### From Marketplace (Recommended)
1. Open VS Code
2. Go to Extensions (Cmd+Shift+X)
3. Search for "Builder Language Support"
4. Click Install

**No additional setup required!** The LSP server is bundled for all platforms.

### Manual Installation
```bash
# Build and install
cd /path/to/Builder
make install-extension

# Or install pre-built VSIX
code --install-extension builder-lang-2.0.0.vsix
```

Then reload VS Code (Cmd+Shift+P → "Developer: Reload Window")

## Platform Support

✅ **Pre-built LSP server binaries included for:**
- macOS (Apple Silicon & Intel)
- Linux (x86_64)
- Windows (x64)

**No D compiler required!** Everything works out of the box.

## Requirements

**None!** The extension is completely self-contained with bundled LSP binaries.

**Optional**: If you have Builder installed system-wide, the extension can also use that installation.

## Extension Settings

This extension contributes the following settings:

* `builder.lsp.enabled`: Enable/disable Builder Language Server Protocol support (default: true)
* `builder.lsp.trace.server`: Trace communication between VS Code and the language server (default: "off")
* `builder.lsp.serverPath`: Custom path to builder-lsp executable (leave empty for auto-detection)

## Usage

Simply open any `Builderfile` or `Builderspace` file, and the extension will automatically activate with full LSP support!

### Example Features in Action

**Autocomplete:**
```
target("my-app") {
    type: e|  ← Suggests: executable, library, test, custom
    deps: ["|"]  ← Suggests available targets
}
```

**Hover Documentation:**
Hover over any field or target to see detailed documentation

**Go to Definition:**
Ctrl/Cmd+Click on a dependency to jump to its definition

**Find All References:**
Right-click on a target and select "Find All References"

## Troubleshooting

### LSP Server Not Found
If you see "Builder LSP server not found":
1. Ensure Builder is installed: `builder --version`
2. Install the LSP server: `make install-lsp` from the Builder repository
3. Or set a custom path in settings: `builder.lsp.serverPath`

### Extension Not Activating
1. Check the Output panel: View → Output → "Builder LSP"
2. Ensure file is recognized as Builder language (check status bar)
3. Try reloading the window: Cmd+Shift+P → "Developer: Reload Window"

## Development

### Building the Extension
```bash
cd tools/vscode/builder-lang
npm install
npx vsce package
```

### Building with LSP Server
```bash
cd /path/to/Builder
make extension
```

## Release Notes

### 2.0.1
- Fixed `.builderignore` file icon to display automatically
- Icons now work with any icon theme (no longer requires switching themes)

### 2.0.0
- Added full Language Server Protocol support
- Autocomplete for fields, types, and dependencies
- Real-time diagnostics and validation
- Go to definition, hover, and find references
- Rename refactoring across all Builderfiles

### 1.0.0
- Initial release with syntax highlighting
