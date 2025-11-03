/**
 * LSP Package - Language Server Protocol Implementation
 * 
 * This package provides Language Server Protocol support for Builder.
 * 
 * Modules:
 * - server: LSP server implementation
 * - protocol: LSP protocol definitions
 * - analysis: Code analysis for LSP
 * - completion: Code completion provider
 * - definition: Go-to-definition support
 * - hover: Hover information provider
 * - references: Find references support
 * - rename: Symbol renaming
 * - symbols: Document and workspace symbols
 * - workspace: Workspace management for LSP
 * - index: Code indexing
 */
module frontend.lsp;

public import frontend.lsp.server;
public import frontend.lsp.protocol;
public import frontend.lsp.analysis;
public import frontend.lsp.completion;
public import frontend.lsp.definition;
public import frontend.lsp.hover;
public import frontend.lsp.references;
public import frontend.lsp.rename;
public import frontend.lsp.symbols;
public import frontend.lsp.workspace;
public import frontend.lsp.index;

