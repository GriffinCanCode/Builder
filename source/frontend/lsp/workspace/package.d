/**
 * LSP Workspace Module
 * 
 * This module manages workspace state and document analysis:
 * - Workspace manager for tracking open documents and their state
 * - Index for fast symbol lookups and cross-references
 * - Semantic analyzer for deep validation beyond syntax checking
 * 
 * The workspace module maintains a synchronized view of the editor's
 * workspace and provides efficient querying capabilities for LSP features.
 */
module frontend.lsp.workspace;

public import frontend.lsp.workspace.workspace;
public import frontend.lsp.workspace.index;
public import frontend.lsp.workspace.analysis;

