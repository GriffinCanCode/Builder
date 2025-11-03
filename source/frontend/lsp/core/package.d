/**
 * LSP Core Module
 * 
 * This module contains the core LSP server implementation, including:
 * - LSP server (JSON-RPC 2.0 protocol over stdio)
 * - LSP protocol types and structures (Position, Range, Location, etc.)
 * - Main entry point for the standalone LSP server binary
 * 
 * The core module handles all client-server communication and dispatches
 * requests to the appropriate providers.
 */
module frontend.lsp.core;

public import frontend.lsp.core.server;
public import frontend.lsp.core.protocol;
public import frontend.lsp.core.main;

