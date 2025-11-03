module frontend.lsp.symbols;

import std.algorithm;
import std.array;
import std.string;
import std.conv;
import std.json;
import frontend.lsp.protocol;
import frontend.lsp.workspace;
import infrastructure.config.workspace.ast;

/// Document symbols provider for outline view
struct SymbolsProvider
{
    private WorkspaceManager workspace;
    
    this(WorkspaceManager workspace)
    {
        this.workspace = workspace;
    }
    
    /// Provide document symbols for outline
    DocumentSymbol[] provideDocumentSymbols(string uri)
    {
        auto doc = workspace.getDocument(uri);
        if (doc is null)
            return [];
        
        DocumentSymbol[] symbols;
        
        foreach (ref target; doc.ast.targets)
        {
            DocumentSymbol sym;
            sym.name = target.name;
            sym.kind = DocumentSymbolKind.Class; // Use Class for targets
            sym.range = Range(
                Position(cast(uint)(target.line - 1), 0),
                Position(cast(uint)(target.line + target.fields.length), 0)
            );
            sym.selectionRange = Range(
                Position(cast(uint)(target.loc.line - 1), 0),
                Position(cast(uint)(target.loc.line - 1), cast(uint)(target.name.length + 8))
            );
            
            // Add detail from type field
            import infrastructure.config.workspace.ast : IdentExpr;
            
            auto typeField = target.getField("type");
            if (typeField !is null)
            {
                auto ident = cast(const IdentExpr)typeField.value;
                if (ident !is null)
                    sym.detail = ident.name;
            }
            
            // Add children for fields
            foreach (ref field; target.fields)
            {
                DocumentSymbol fieldSym;
                fieldSym.name = field.name;
                fieldSym.kind = DocumentSymbolKind.Property;
                fieldSym.range = Range(
                    Position(cast(uint)(field.line - 1), 0),
                    Position(cast(uint)(field.line - 1), 100)
                );
                fieldSym.selectionRange = fieldSym.range;
                
                // Add field value as detail
                fieldSym.detail = getFieldValueSummary(field);
                
                sym.children ~= fieldSym;
            }
            
            symbols ~= sym;
        }
        
        return symbols;
    }
    
    /// Get summary of field value for display
    private string getFieldValueSummary(const ref Field field)
    {
        final switch (field.value.kind)
        {
            case ExpressionValue.Kind.String:
                auto str = field.value.getString();
                return str !is null ? "\"" ~ str.value ~ "\"" : "";
            
            case ExpressionValue.Kind.Number:
                auto num = field.value.getNumber();
                return num !is null ? num.value.to!string : "";
            
            case ExpressionValue.Kind.Identifier:
                auto ident = field.value.getIdentifier();
                return ident !is null ? ident.name : "";
            
            case ExpressionValue.Kind.Array:
                auto arr = field.value.getArray();
                if (arr is null || arr.elements.empty)
                    return "[]";
                return "[" ~ arr.elements.length.to!string ~ " items]";
            
            case ExpressionValue.Kind.Map:
                auto map = field.value.getMap();
                if (map is null || map.pairs.length == 0)
                    return "{}";
                return "{" ~ map.pairs.length.to!string ~ " entries}";
        }
    }
}

/// Document symbol kind (subset of LSP)
enum DocumentSymbolKind : uint
{
    File = 1,
    Module = 2,
    Namespace = 3,
    Package = 4,
    Class = 5,
    Method = 6,
    Property = 7,
    Field = 8,
    Constructor = 9,
    Enum = 10,
    Interface = 11,
    Function = 12,
    Variable = 13,
    Constant = 14,
    String = 15,
    Number = 16,
    Boolean = 17,
    Array = 18,
    Object = 19,
    Key = 20,
    Null = 21
}

/// Document symbol (hierarchical)
struct DocumentSymbol
{
    string name;
    string detail;
    DocumentSymbolKind kind;
    Range range;
    Range selectionRange;
    DocumentSymbol[] children;
    
    JSONValue toJSON() const
    {
        import std.json;
        import std.conv;
        
        JSONValue json;
        json["name"] = name;
        json["kind"] = cast(uint)kind;
        json["range"] = range.toJSON();
        json["selectionRange"] = selectionRange.toJSON();
        
        if (detail.length > 0)
            json["detail"] = detail;
        
        if (!children.empty)
        {
            JSONValue[] childrenJson;
            foreach (child; children)
                childrenJson ~= child.toJSON();
            json["children"] = JSONValue(childrenJson);
        }
        
        return json;
    }
}

