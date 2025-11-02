module lsp.definition;

import std.algorithm;
import std.array;
import std.string;
import lsp.protocol;
import lsp.workspace;
import config.workspace.ast;

/// Go-to-definition provider
struct DefinitionProvider
{
    private WorkspaceManager workspace;
    
    this(WorkspaceManager workspace)
    {
        this.workspace = workspace;
    }
    
    /// Provide definition location for symbol at position
    Location* provideDefinition(string uri, Position pos)
    {
        auto doc = workspace.getDocument(uri);
        if (doc is null)
            return null;
        
        // Get the word/symbol at the cursor position
        auto symbol = getSymbolAtPosition(doc.text, pos);
        if (symbol.length == 0)
            return null;
        
        // Check if it's a target dependency reference
        if (symbol.startsWith(":") || symbol.startsWith("//"))
        {
            // It's a target reference
            return workspace.findDefinition(symbol);
        }
        
        // Check if we're in a deps field
        auto field = workspace.findFieldAtPosition(uri, pos);
        if (field !is null && field.name == "deps")
        {
            // Try to find the target
            return workspace.findDefinition(symbol);
        }
        
        return null;
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
        
        // Extract symbol, handling quotes
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

