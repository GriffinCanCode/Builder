module lsp.references;

import std.algorithm;
import std.array;
import std.string;
import lsp.protocol;
import lsp.workspace;

/// References provider (find all uses)
struct ReferencesProvider
{
    private WorkspaceManager workspace;
    
    this(WorkspaceManager workspace)
    {
        this.workspace = workspace;
    }
    
    /// Find all references to symbol at position
    Location[] provideReferences(string uri, Position pos, bool includeDeclaration)
    {
        auto doc = workspace.getDocument(uri);
        if (doc is null)
            return [];
        
        // Get the symbol at the cursor
        auto symbol = getSymbolAtPosition(doc.text, pos);
        if (symbol.length == 0)
            return [];
        
        // Find all references
        auto references = workspace.findReferences(symbol);
        
        // Add definition if requested
        if (includeDeclaration)
        {
            auto def = workspace.findDefinition(symbol);
            if (def !is null)
                references ~= *def;
        }
        
        return references;
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

