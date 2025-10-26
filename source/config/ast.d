module config.ast;

import std.conv;
import std.algorithm;
import std.array;
import config.schema;

/// Abstract syntax tree node types for BUILD DSL

/// Base AST node
interface ASTNode
{
    /// Get node type name for debugging
    string nodeType() const;
}

/// Expression node
interface Expression : ASTNode
{
}

/// String literal expression
struct StringLiteral
{
    string value;
    size_t line;
    size_t column;
    
    string nodeType() const { return "StringLiteral"; }
}

/// Number literal expression
struct NumberLiteral
{
    long value;
    size_t line;
    size_t column;
    
    string nodeType() const { return "NumberLiteral"; }
}

/// Identifier expression
struct Identifier
{
    string name;
    size_t line;
    size_t column;
    
    string nodeType() const { return "Identifier"; }
}

/// Array literal expression
struct ArrayLiteral
{
    ExpressionValue[] elements;
    size_t line;
    size_t column;
    
    string nodeType() const { return "ArrayLiteral"; }
}

/// Map literal expression (for env)
struct MapLiteral
{
    string[string] pairs;
    size_t line;
    size_t column;
    
    string nodeType() const { return "MapLiteral"; }
}

/// Tagged union for expression values
struct ExpressionValue
{
    enum Kind
    {
        String,
        Number,
        Identifier,
        Array,
        Map
    }
    
    Kind kind;
    
    union
    {
        StringLiteral stringValue;
        NumberLiteral numberValue;
        Identifier identifierValue;
        ArrayLiteral* arrayValue;
        MapLiteral* mapValue;
    }
    
    static ExpressionValue fromString(string value, size_t line, size_t col)
    {
        ExpressionValue expr;
        expr.kind = Kind.String;
        expr.stringValue = StringLiteral(value, line, col);
        return expr;
    }
    
    static ExpressionValue fromNumber(long value, size_t line, size_t col)
    {
        ExpressionValue expr;
        expr.kind = Kind.Number;
        expr.numberValue = NumberLiteral(value, line, col);
        return expr;
    }
    
    static ExpressionValue fromIdentifier(string name, size_t line, size_t col)
    {
        ExpressionValue expr;
        expr.kind = Kind.Identifier;
        expr.identifierValue = Identifier(name, line, col);
        return expr;
    }
    
    static ExpressionValue fromArray(ExpressionValue[] elements, size_t line, size_t col)
    {
        ExpressionValue expr;
        expr.kind = Kind.Array;
        expr.arrayValue = new ArrayLiteral(elements, line, col);
        return expr;
    }
    
    static ExpressionValue fromMap(string[string] pairs, size_t line, size_t col)
    {
        ExpressionValue expr;
        expr.kind = Kind.Map;
        expr.mapValue = new MapLiteral(pairs, line, col);
        return expr;
    }
    
    /// Convert to string (for semantic analysis)
    string asString() const
    {
        final switch (kind)
        {
            case Kind.String: return stringValue.value;
            case Kind.Identifier: return identifierValue.name;
            case Kind.Number: return numberValue.value.to!string;
            case Kind.Array: throw new Exception("Cannot convert array to string");
            case Kind.Map: throw new Exception("Cannot convert map to string");
        }
    }
    
    /// Convert to string array
    string[] asStringArray() const
    {
        if (kind != Kind.Array)
            throw new Exception("Expression is not an array");
        
        return arrayValue.elements.map!(e => e.asString()).array;
    }
    
    /// Convert to map
    string[string] asMap() const
    {
        if (kind != Kind.Map)
            throw new Exception("Expression is not a map");
        
        return cast(string[string]) mapValue.pairs;
    }
    
    /// Check if is specific identifier
    bool isIdentifier(string name) const
    {
        return kind == Kind.Identifier && identifierValue.name == name;
    }
}

/// Field assignment in target body
struct Field
{
    string name;
    ExpressionValue value;
    size_t line;
    size_t column;
    
    string nodeType() const { return "Field"; }
}

/// Target declaration
struct TargetDecl
{
    string name;
    Field[] fields;
    size_t line;
    size_t column;
    
    string nodeType() const { return "TargetDecl"; }
    
    /// Get field by name (returns null if not found)
    const(Field)* getField(string name) const
    {
        foreach (ref field; fields)
        {
            if (field.name == name)
                return &field;
        }
        return null;
    }
    
    /// Check if has field
    bool hasField(string name) const
    {
        return getField(name) !is null;
    }
}

/// Root node containing all targets
struct BuildFile
{
    TargetDecl[] targets;
    string filePath;
    
    string nodeType() const { return "BuildFile"; }
}

/// AST visitor pattern for traversal
interface ASTVisitor
{
    void visitBuildFile(ref BuildFile node);
    void visitTargetDecl(ref TargetDecl node);
    void visitField(ref Field node);
}

/// Pretty printer for debugging
struct ASTPrinter
{
    private int indent = 0;
    private string output;
    
    string print(ref BuildFile file)
    {
        output = "";
        indent = 0;
        
        writeLine("BuildFile");
        indent++;
        
        foreach (ref target; file.targets)
        {
            printTarget(target);
        }
        
        indent--;
        return output;
    }
    
    private void printTarget(ref TargetDecl target)
    {
        writeLine("TargetDecl: " ~ target.name);
        indent++;
        
        foreach (ref field; target.fields)
        {
            printField(field);
        }
        
        indent--;
    }
    
    private void printField(ref Field field)
    {
        writeLine("Field: " ~ field.name ~ " = " ~ valueToString(field.value));
    }
    
    private string valueToString(ref ExpressionValue value)
    {
        final switch (value.kind)
        {
            case ExpressionValue.Kind.String:
                return `"` ~ value.stringValue.value ~ `"`;
            case ExpressionValue.Kind.Number:
                return value.numberValue.value.to!string;
            case ExpressionValue.Kind.Identifier:
                return value.identifierValue.name;
            case ExpressionValue.Kind.Array:
                return "[" ~ value.arrayValue.elements
                    .map!(e => valueToString(e))
                    .join(", ") ~ "]";
            case ExpressionValue.Kind.Map:
                return "{" ~ value.mapValue.pairs.byKeyValue
                    .map!(kv => kv.key ~ ": " ~ kv.value)
                    .join(", ") ~ "}";
        }
    }
    
    private void writeLine(string text)
    {
        import std.range : repeat;
        import std.array : array;
        
        output ~= "  ".repeat(indent).join() ~ text ~ "\n";
    }
}

