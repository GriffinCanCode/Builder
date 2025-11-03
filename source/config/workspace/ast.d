module config.workspace.ast;

import std.conv;
import std.algorithm;
import std.array;
import std.typecons : Rebindable, rebindable;
import config.schema.schema;
import errors;

/// Abstract syntax tree node types for Builderfile DSL
/// 
/// Memory Safety: All heap allocations are GC-managed. Pointers in unions
/// are used only to break recursive struct dependencies and are always
/// valid for the lifetime of the owning ExpressionValue.

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
    ExpressionValue[string] pairs;
    size_t line;
    size_t column;
    
    string nodeType() const { return "MapLiteral"; }
}

/// Tagged union for expression values
/// 
/// Memory Safety Design:
/// - Uses tagged union pattern with discriminator field (kind)
/// - Pointers are GC-managed (automatic memory management)
/// - Type-safe accessors prevent accessing wrong union member
/// - Const correctness enforced throughout
struct ExpressionValue
{
    /// Discriminator for tagged union
    enum Kind
    {
        String,
        Number,
        Identifier,
        Array,
        Map
    }
    
    /// Current variant type
    Kind kind;
    
    /// Union storage - only one active at a time based on kind
    /// Pointers used to break recursive type dependencies
    private union Storage
    {
        StringLiteral stringValue;
        NumberLiteral numberValue;
        Identifier identifierValue;
        ArrayLiteral* arrayValue;  // GC-managed, breaks recursion
        MapLiteral* mapValue;      // GC-managed, breaks recursion
    }
    
    private Storage _storage;
    
    // Factory methods (type-safe constructors)
    
    /// Create string literal expression
    static ExpressionValue fromString(string value, size_t line, size_t col) pure
    {
        ExpressionValue expr;
        expr.kind = Kind.String;
        expr._storage.stringValue = StringLiteral(value, line, col);
        return expr;
    }
    
    /// Create number literal expression
    static ExpressionValue fromNumber(long value, size_t line, size_t col) pure nothrow @nogc
    {
        ExpressionValue expr;
        expr.kind = Kind.Number;
        expr._storage.numberValue = NumberLiteral(value, line, col);
        return expr;
    }
    
    /// Create identifier expression
    static ExpressionValue fromIdentifier(string name, size_t line, size_t col) pure
    {
        ExpressionValue expr;
        expr.kind = Kind.Identifier;
        expr._storage.identifierValue = Identifier(name, line, col);
        return expr;
    }
    
    /// Create array expression (allocates on GC heap)
    static ExpressionValue fromArray(ExpressionValue[] elements, size_t line, size_t col)
    {
        ExpressionValue expr;
        expr.kind = Kind.Array;
        expr._storage.arrayValue = new ArrayLiteral(elements, line, col);
        return expr;
    }
    
    /// Create map expression (allocates on GC heap)
    static ExpressionValue fromMap(ExpressionValue[string] pairs, size_t line, size_t col)
    {
        ExpressionValue expr;
        expr.kind = Kind.Map;
        expr._storage.mapValue = new MapLiteral(pairs, line, col);
        return expr;
    }
    
    /// Create map expression from string pairs (convenience for simple maps)
    static ExpressionValue fromStringMap(string[string] stringPairs, size_t line, size_t col)
    {
        ExpressionValue[string] pairs;
        foreach (key, value; stringPairs)
        {
            pairs[key] = ExpressionValue.fromString(value, line, col);
        }
        return fromMap(pairs, line, col);
    }
    
    // Type-safe accessors
    
    /// Get string value (checked at runtime)
    @property inout(StringLiteral)* getString() inout pure nothrow @nogc
    {
        return kind == Kind.String ? &_storage.stringValue : null;
    }
    
    /// Get number value (checked at runtime)
    @property inout(NumberLiteral)* getNumber() inout pure nothrow @nogc
    {
        return kind == Kind.Number ? &_storage.numberValue : null;
    }
    
    /// Get identifier value (checked at runtime)
    @property inout(Identifier)* getIdentifier() inout pure nothrow @nogc
    {
        return kind == Kind.Identifier ? &_storage.identifierValue : null;
    }
    
    /// Get array value (checked at runtime)
    @property inout(ArrayLiteral)* getArray() inout pure nothrow @nogc
    {
        return kind == Kind.Array ? _storage.arrayValue : null;
    }
    
    /// Get map value (checked at runtime)
    @property inout(MapLiteral)* getMap() inout pure nothrow @nogc
    {
        return kind == Kind.Map ? _storage.mapValue : null;
    }
    
    // Legacy accessors for backward compatibility (unchecked - use with care)
    // These are kept to maintain existing code compatibility
    @property ref inout(StringLiteral) stringValue() inout pure return
    in (kind == Kind.String, "Accessed stringValue on non-string ExpressionValue")
    {
        return _storage.stringValue;
    }
    
    @property ref inout(NumberLiteral) numberValue() inout pure return
    in (kind == Kind.Number, "Accessed numberValue on non-number ExpressionValue")
    {
        return _storage.numberValue;
    }
    
    @property ref inout(Identifier) identifierValue() inout pure return
    in (kind == Kind.Identifier, "Accessed identifierValue on non-identifier ExpressionValue")
    {
        return _storage.identifierValue;
    }
    
    @property inout(ArrayLiteral)* arrayValue() inout pure nothrow @nogc
    in (kind == Kind.Array, "Accessed arrayValue on non-array ExpressionValue")
    {
        return _storage.arrayValue;
    }
    
    @property inout(MapLiteral)* mapValue() inout pure nothrow @nogc
    in (kind == Kind.Map, "Accessed mapValue on non-map ExpressionValue")
    {
        return _storage.mapValue;
    }
    
    // Semantic conversion methods
    
    /// Convert to string (Result-based version for type-safe conversion)
    /// Returns: Ok with string value, Err if expression cannot be converted
    Result!(string, BuildError) asString() const
    {
        final switch (kind)
        {
            case Kind.String: return Ok!(string, BuildError)(_storage.stringValue.value);
            case Kind.Identifier: return Ok!(string, BuildError)(_storage.identifierValue.name);
            case Kind.Number: return Ok!(string, BuildError)(_storage.stringValue.value.to!string);
            case Kind.Array:
                auto error = ErrorBuilder!ParseError
                    .create("", "Cannot convert array expression to string", ErrorCode.InvalidFieldValue)
                    .withSuggestion(ErrorSuggestion.fileCheck("Expected a string value, but got an array"))
                    .withSuggestion(ErrorSuggestion.fileCheck("Remove brackets [] to use a single string value"))
                    .build();
                return Err!(string, BuildError)(cast(BuildError) error);
            case Kind.Map:
                auto error = ErrorBuilder!ParseError
                    .create("", "Cannot convert map expression to string", ErrorCode.InvalidFieldValue)
                    .withSuggestion(ErrorSuggestion.fileCheck("Expected a string value, but got a map"))
                    .withSuggestion(ErrorSuggestion.fileCheck("Remove braces {} to use a single string value"))
                    .build();
                return Err!(string, BuildError)(cast(BuildError) error);
        }
    }
    
    /// Convert to string array (Result-based version for type-safe conversion)
    /// Returns: Ok with string array, Err if expression is not an array
    Result!(string[], BuildError) asStringArray() const
    {
        if (kind != Kind.Array)
        {
            auto error = ErrorBuilder!ParseError
                .create("", "Expected array but got " ~ kind.to!string, ErrorCode.InvalidFieldValue)
                .withSuggestion(ErrorSuggestion.fileCheck("Value must be an array like [\"item1\", \"item2\"]"))
                .withSuggestion(ErrorSuggestion.fileCheck("Add brackets [] around the values"))
                .build();
            return Err!(string[], BuildError)(cast(BuildError) error);
        }
        
        // Try to convert each element, collecting errors
        string[] result;
        result.reserve(_storage.arrayValue.elements.length);
        
        foreach (elem; _storage.arrayValue.elements)
        {
            auto elemResult = elem.asString();
            if (elemResult.isErr)
                return Err!(string[], BuildError)(elemResult.unwrapErr());
            result ~= elemResult.unwrap();
        }
        
        return Ok!(string[], BuildError)(result);
    }
    
    /// Convert to map (Result-based version for type-safe conversion)
    /// Returns: Ok with string map, Err if expression is not a map
    Result!(string[string], BuildError) asMap() const
    {
        if (kind != Kind.Map)
        {
            auto error = ErrorBuilder!ParseError
                .create("", "Expected map but got " ~ kind.to!string, ErrorCode.InvalidFieldValue)
                .withSuggestion(ErrorSuggestion.fileCheck("Value must be a map like {key: \"value\"}"))
                .withSuggestion(ErrorSuggestion.fileCheck("Add braces {} around key-value pairs"))
                .build();
            return Err!(string[string], BuildError)(cast(BuildError) error);
        }
        
        string[string] result;
        foreach (key, value; _storage.mapValue.pairs)
        {
            auto valueResult = value.asString();
            if (valueResult.isErr)
                return Err!(string[string], BuildError)(valueResult.unwrapErr());
            result[key] = valueResult.unwrap();
        }
        
        return Ok!(string[string], BuildError)(result);
    }
    
    // Utility methods
    
    /// Check if is specific identifier
    bool isIdentifier(string name) const pure
    {
        return kind == Kind.Identifier && _storage.identifierValue.name == name;
    }
    
    /// Match pattern for type-safe exhaustive handling
    U match(U)(
        U delegate(ref const StringLiteral) onString,
        U delegate(ref const NumberLiteral) onNumber,
        U delegate(ref const Identifier) onIdentifier,
        U delegate(const ArrayLiteral*) onArray,
        U delegate(const MapLiteral*) onMap
    ) const
    {
        final switch (kind)
        {
            case Kind.String: return onString(_storage.stringValue);
            case Kind.Number: return onNumber(_storage.numberValue);
            case Kind.Identifier: return onIdentifier(_storage.identifierValue);
            case Kind.Array: return onArray(_storage.arrayValue);
            case Kind.Map: return onMap(_storage.mapValue);
        }
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

/// Repository declaration (external dependencies)
struct RepositoryDecl
{
    string name;
    Field[] fields;
    size_t line;
    size_t column;
    
    string nodeType() const { return "RepositoryDecl"; }
    
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

/// Root node containing all targets and repositories
struct BuildFile
{
    TargetDecl[] targets;
    RepositoryDecl[] repositories;
    string filePath;
    
    string nodeType() const { return "BuildFile"; }
}

/// AST visitor pattern for traversal
interface ASTVisitor
{
    void visitBuildFile(ref BuildFile node);
    void visitTargetDecl(ref TargetDecl node);
    void visitRepositoryDecl(ref RepositoryDecl node);
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
    
    private string valueToString(const ref ExpressionValue value)
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
                    .map!(kv => kv.key ~ ": " ~ valueToString(kv.value))
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

