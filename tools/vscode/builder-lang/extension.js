const vscode = require('vscode');
const path = require('path');
const fs = require('fs');
const { LanguageClient, TransportKind } = require('vscode-languageclient/node');

let client;

/**
 * Activate the Builder Language Server extension
 */
async function activate(context) {
    console.log('Builder Language Server extension activating...');

    // Check if LSP is enabled
    const config = vscode.workspace.getConfiguration('builder');
    if (!config.get('lsp.enabled', true)) {
        console.log('Builder LSP is disabled in settings');
        return;
    }

    // Find the builder-lsp executable
    const serverExecutable = findServerExecutable();
    if (!serverExecutable) {
        vscode.window.showWarningMessage(
            'Builder LSP server not found. Install Builder to enable language features.',
            'Install Builder'
        ).then(selection => {
            if (selection === 'Install Builder') {
                vscode.env.openExternal(vscode.Uri.parse('https://github.com/yourusername/builder'));
            }
        });
        return;
    }

    console.log('Found Builder LSP server at:', serverExecutable);

    // Configure the language server
    const serverOptions = {
        command: serverExecutable,
        args: [],
        transport: TransportKind.stdio
    };

    // Configure the language client
    const clientOptions = {
        documentSelector: [
            { scheme: 'file', language: 'builder' },
            { scheme: 'file', pattern: '**/Builderfile' },
            { scheme: 'file', pattern: '**/Builderspace' }
        ],
        synchronize: {
            // Notify the server about file changes to Builderfile files
            fileEvents: vscode.workspace.createFileSystemWatcher('**/{Builderfile,Builderspace}')
        },
        diagnosticCollectionName: 'builder',
        outputChannelName: 'Builder LSP',
        traceOutputChannel: vscode.window.createOutputChannel('Builder LSP Trace')
    };

    // Create and start the language client
    client = new LanguageClient(
        'builderLSP',
        'Builder Language Server',
        serverOptions,
        clientOptions
    );

    // Start the client (this will also start the server)
    try {
        await client.start();
        console.log('Builder Language Server started successfully');
        vscode.window.showInformationMessage('Builder Language Server activated');
    } catch (error) {
        console.error('Failed to start Builder Language Server:', error);
        vscode.window.showErrorMessage(`Failed to start Builder LSP: ${error.message}`);
    }
}

/**
 * Deactivate the extension and stop the language server
 */
async function deactivate() {
    if (client) {
        console.log('Stopping Builder Language Server...');
        await client.stop();
    }
}

/**
 * Find the builder-lsp executable
 * Searches in:
 * 1. Custom path from settings
 * 2. Extension's bin/ directory
 * 3. System PATH
 * 4. Common installation locations
 */
function findServerExecutable() {
    // Check custom path from settings
    const config = vscode.workspace.getConfiguration('builder');
    const customPath = config.get('lsp.serverPath', '');
    if (customPath && fs.existsSync(customPath)) {
        return customPath;
    }

    // Check extension directory
    const extensionPath = path.join(__dirname, 'bin', 'builder-lsp');
    if (fs.existsSync(extensionPath)) {
        return extensionPath;
    }

    // Check if builder-lsp is in PATH
    const pathExecutable = findInPath('builder-lsp');
    if (pathExecutable) {
        return pathExecutable;
    }

    // Check common installation locations
    const commonPaths = [
        '/usr/local/bin/builder-lsp',
        '/opt/homebrew/bin/builder-lsp',
        path.join(process.env.HOME, '.local', 'bin', 'builder-lsp')
    ];

    for (const commonPath of commonPaths) {
        if (fs.existsSync(commonPath)) {
            return commonPath;
        }
    }

    return null;
}

/**
 * Find executable in system PATH
 */
function findInPath(executable) {
    const pathEnv = process.env.PATH || '';
    const pathDirs = pathEnv.split(path.delimiter);

    for (const dir of pathDirs) {
        const fullPath = path.join(dir, executable);
        if (fs.existsSync(fullPath)) {
            try {
                fs.accessSync(fullPath, fs.constants.X_OK);
                return fullPath;
            } catch (e) {
                // Not executable, continue searching
            }
        }
    }

    return null;
}

module.exports = {
    activate,
    deactivate
};

