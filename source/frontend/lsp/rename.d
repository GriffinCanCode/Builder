module frontend.lsp.rename;

import std.algorithm;
import std.array;
import std.string;
import frontend.lsp.protocol;
import frontend.lsp.workspace;

/// Rename refactoring provider
struct RenameProvider
{
    private WorkspaceManager workspace;
    
    this(WorkspaceManager workspace)
    {
        this.workspace = workspace;
    }
    
    /// Provide workspace edits for renaming symbol at position
    WorkspaceEdit* provideRename(string uri, Position pos, string newName)
    {
        auto doc = workspace.getDocument(uri);
        if (doc is null)
            return null;
        
        // Get the symbol at the cursor
        auto oldName = getSymbolAtPosition(doc.text, pos);
        if (oldName.length == 0)
            return null;
        
        // Find all references (including definition)
        auto references = workspace.findReferences(oldName);
        auto definition = workspace.findDefinition(oldName);
        if (definition !is null)
            references ~= *definition;
        
        if (references.length == 0)
            return null;
        
        // Build workspace edit
        auto edit = new WorkspaceEdit;
        
        foreach (ref loc; references)
        {
            // Create text edit for this location
            TextEdit textEdit;
            textEdit.range = loc.range;
            textEdit.newText = newName;
            
            // Add to workspace edit
            if (loc.uri !in edit.changes)
                edit.changes[loc.uri] = [];
            edit.changes[loc.uri] ~= textEdit;
        }
        
        return edit;
    }
    
    private string getSymbolAtPosition(string text, Position pos)
    {
        auto lines = text.split("\n");
        if (pos.line >= lines.length)
            return "";
        
        string line = lines[pos.line];
        if (pos.character >= line.length)
            return "";
        
        // Find word boundaries
        size_t start = pos.character;
        size_t end = pos.character;
        
        // Extend backwards
        while (start > 0 && isSymbolChar(line[start - 1]))
            start--;
        
        // Extend forwards
        while (end < line.length && isSymbolChar(line[end]))
            end++;
        
        // Extract symbol
        string symbol = line[start .. end];
        
        // Remove quotes if present
        if (symbol.startsWith("\"") && symbol.endsWith("\""))
            symbol = symbol[1 .. $ - 1];
        if (symbol.startsWith("'") && symbol.endsWith("'"))
            symbol = symbol[1 .. $ - 1];
        
        return symbol;
    }
    
    private bool isSymbolChar(char c)
    {
        import std.ascii : isAlphaNum;
        return isAlphaNum(c) || c == '_' || c == '-' || c == '/' || c == ':' || c == '.' || c == '"' || c == '\'';
    }
}

