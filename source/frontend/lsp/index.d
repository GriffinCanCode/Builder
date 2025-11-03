module frontend.lsp.index;

import std.algorithm;
import std.array;
import std.string;
import frontend.lsp.protocol;
import infrastructure.config.workspace.ast : BuildFile, TargetDeclStmt, Field, Expr, ASTLocation = Location;

/// Symbol information for quick lookups
struct Symbol
{
    string name;           // Target name
    string uri;            // Document URI
    Range range;           // Precise location
    SymbolKind kind;       // Type of symbol
    string detail;         // Additional info (type, language, etc.)
    string[] deps;         // Dependencies
}

/// Symbol kind enum
enum SymbolKind
{
    Target,
    Field,
    Dependency
}

/// Fast workspace-wide symbol index
/// Provides O(1) lookups for definitions and references
struct Index
{
    private Symbol[string] symbols;                  // name -> symbol
    private string[][string] references;             // name -> [uri...]
    private Symbol[][string] documentSymbols;        // uri -> [symbols...]
    private string[Range][string] rangeSymbols;      // uri -> range -> name
    
    /// Index a document
    void indexDocument(string uri, const ref BuildFile ast)
    {
        // Clear previous symbols from this document
        if (uri in documentSymbols)
        {
            foreach (sym; documentSymbols[uri])
            {
                symbols.remove(sym.name);
            }
        }
        
        documentSymbols[uri] = [];
        
        // Index all targets
        foreach (ref target; ast.targets)
        {
            Symbol sym;
            sym.name = target.name;
            sym.uri = uri;
            sym.kind = SymbolKind.Target;
            sym.range = Range(
                Position(cast(uint)(target.line - 1), 0),
                Position(cast(uint)(target.line - 1), cast(uint)(target.name.length + 8))
            );
            
            // Extract detail info
            auto typeField = target.getField("type");
            if (typeField !is null && typeField.value.kind == ExpressionValue.Kind.Identifier)
            {
                auto ident = typeField.value.getIdentifier();
                if (ident !is null)
                    sym.detail = ident.name;
            }
            
            // Extract dependencies
            auto depsField = target.getField("deps");
            if (depsField !is null && depsField.value.kind == ExpressionValue.Kind.Array)
            {
                auto arr = depsField.value.getArray();
                if (arr !is null)
                {
                    foreach (elem; arr.elements)
                    {
                        if (elem.kind == ExpressionValue.Kind.String)
                        {
                            auto str = elem.getString();
                            if (str !is null)
                                sym.deps ~= str.value;
                        }
                    }
                }
            }
            
            symbols[sym.name] = sym;
            documentSymbols[uri] ~= sym;
            
            // Index range for quick position-based lookup
            if (uri !in rangeSymbols)
                rangeSymbols[uri] = null;
            rangeSymbols[uri][sym.range] = sym.name;
        }
        
        // Index references (dependencies)
        buildReferencesForDocument(uri, ast);
    }
    
    /// Build reference index for a document
    private void buildReferencesForDocument(string uri, const ref BuildFile ast)
    {
        foreach (ref target; ast.targets)
        {
            auto depsField = target.getField("deps");
            if (depsField is null)
                continue;
            
            if (depsField.value.kind != ExpressionValue.Kind.Array)
                continue;
            
            auto arr = depsField.value.getArray();
            if (arr is null)
                continue;
            
            foreach (elem; arr.elements)
            {
                if (elem.kind != ExpressionValue.Kind.String)
                    continue;
                
                auto str = elem.getString();
                if (str is null)
                    continue;
                
                string depName = str.value;
                // Normalize
                if (depName.startsWith(":"))
                    depName = depName[1 .. $];
                else if (depName.startsWith("//"))
                {
                    auto colonPos = depName.lastIndexOf(':');
                    if (colonPos != -1)
                        depName = depName[colonPos + 1 .. $];
                }
                
                // Add reference
                if (depName !in references)
                    references[depName] = [];
                
                if (!references[depName].canFind(uri))
                    references[depName] ~= uri;
            }
        }
    }
    
    /// Remove document from index
    void removeDocument(string uri)
    {
        if (uri in documentSymbols)
        {
            foreach (sym; documentSymbols[uri])
            {
                symbols.remove(sym.name);
            }
            documentSymbols.remove(uri);
        }
        
        rangeSymbols.remove(uri);
        
        // Remove references to this document
        foreach (name, uris; references)
        {
            references[name] = uris.filter!(u => u != uri).array;
        }
    }
    
    /// Check if target exists
    bool hasTarget(string name) const
    {
        return (name in symbols) !is null;
    }
    
    /// Get symbol by name
    const(Symbol)* getSymbol(string name) const
    {
        auto sym = name in symbols;
        return sym;
    }
    
    /// Get all symbols in a document
    const(Symbol)[] getDocumentSymbols(string uri) const
    {
        auto syms = uri in documentSymbols;
        if (syms is null)
            return [];
        return *syms;
    }
    
    /// Get all target names
    string[] getAllTargetNames() const
    {
        return symbols.keys;
    }
    
    /// Find symbol at position
    const(Symbol)* findSymbolAt(string uri, Position pos) const
    {
        auto ranges = uri in rangeSymbols;
        if (ranges is null)
            return null;
        
        foreach (range, name; *ranges)
        {
            if (positionInRange(pos, range))
            {
                return getSymbol(name);
            }
        }
        
        return null;
    }
    
    /// Get all references to a symbol
    Location[] getReferences(string name) const
    {
        Location[] locations;
        
        auto uris = name in references;
        if (uris is null)
            return locations;
        
        // For each document that references this symbol
        foreach (uri; *uris)
        {
            auto syms = uri in documentSymbols;
            if (syms is null)
                continue;
            
            // Find the actual reference locations
            foreach (sym; *syms)
            {
                if (sym.deps.canFind(name) || sym.deps.canFind(":" ~ name))
                {
                    Location loc;
                    loc.uri = uri;
                    loc.range = sym.range;
                    locations ~= loc;
                }
            }
        }
        
        return locations;
    }
    
    /// Get definition location for a symbol
    Location* getDefinition(string name) const
    {
        auto sym = getSymbol(name);
        if (sym is null)
            return null;
        
        auto loc = new Location;
        loc.uri = sym.uri;
        loc.range = sym.range;
        return loc;
    }
    
    /// Helper: Check if position is in range
    private bool positionInRange(Position pos, Range range) const pure nothrow @safe
    {
        if (pos.line < range.start.line || pos.line > range.end.line)
            return false;
        
        if (pos.line == range.start.line && pos.character < range.start.character)
            return false;
        
        if (pos.line == range.end.line && pos.character > range.end.character)
            return false;
        
        return true;
    }
}

