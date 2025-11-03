module infrastructure.utils.serialization.core.reflection;

import std.traits;
import std.meta;
import infrastructure.utils.serialization.core.schema;

/// Compile-time schema introspection and validation
struct SchemaInfo(T) if (isSerializable!T)
{
    alias Type = T;
    
    /// Schema version
    enum version_ = getSchemaVersion!T;
    
    /// Magic number
    enum magic = getUDAs!(T, Serializable)[0].magicNumber;
    
    /// Field count
    enum fieldCount = T.tupleof.length;
    
    /// Type name
    enum name = T.stringof;
    
    /// Get field info at compile time
    template field(size_t index) if (index < fieldCount)
    {
        alias FieldType = typeof(T.tupleof[index]);
        enum id = getFieldId!(T.tupleof[index]);
        enum name = __traits(identifier, T.tupleof[index]);
        enum isOptional = isOptionalField!(T.tupleof[index]);
        enum isDeprecated = isDeprecatedField!(T.tupleof[index]);
        enum isPacked = isPackedField!(T.tupleof[index]);
    }
    
    /// Generate JSON schema representation
    static string toJsonSchema()
    {
        import std.format : format;
        import std.array : appender;
        
        auto result = appender!string;
        result ~= "{\n";
        result ~= format(`  "name": "%s",` ~ "\n", name);
        result ~= format(`  "version": "%d.%d",` ~ "\n", version_.major, version_.minor);
        result ~= `  "fields": [` ~ "\n";
        
        static foreach (i, field; T.tupleof)
        {{
            if (i > 0) result ~= ",\n";
            
            enum fieldId = getFieldId!field;
            enum fieldName = __traits(identifier, field);
            alias FieldType = typeof(field);
            
            result ~= "    {\n";
            result ~= format(`      "id": %d,` ~ "\n", fieldId);
            result ~= format(`      "name": "%s",` ~ "\n", fieldName);
            result ~= format(`      "type": "%s"`, FieldType.stringof);
            
            static if (isOptionalField!field)
                result ~= `,` ~ "\n" ~ `      "optional": true`;
            
            static if (isDeprecatedField!field)
                result ~= `,` ~ "\n" ~ `      "deprecated": true`;
            
            result ~= "\n    }";
        }}
        
        result ~= "\n  ]\n";
        result ~= "}";
        
        return result.data;
    }
    
    /// Pretty print schema
    static string toString()
    {
        import std.format : format;
        import std.array : appender;
        
        auto result = appender!string;
        result ~= format("@Serializable(%d.%d)\n", version_.major, version_.minor);
        result ~= format("struct %s\n{\n", name);
        
        static foreach (i, field; T.tupleof)
        {{
            enum fieldId = getFieldId!field;
            enum fieldName = __traits(identifier, field);
            alias FieldType = typeof(field);
            
            result ~= "  ";
            static if (isOptionalField!field)
                result ~= "@Optional ";
            static if (isDeprecatedField!field)
                result ~= "@Deprecated ";
            static if (isPackedField!field)
                result ~= "@Packed ";
            
            result ~= format("@Field(%d) ", fieldId);
            result ~= format("%s %s;\n", FieldType.stringof, fieldName);
        }}
        
        result ~= "}";
        return result.data;
    }
    
    /// Validate schema at compile time
    enum bool isValid = validateSchema!T;
}

/// Pretty-print all serializable types in a module
string dumpSchemas(alias Module)()
{
    import std.array : appender;
    
    auto result = appender!string;
    result ~= "=== Serializable Schemas ===\n\n";
    
    static foreach (member; __traits(allMembers, Module))
    {{
        static if (is(__traits(getMember, Module, member)))
        {
            alias T = __traits(getMember, Module, member);
            static if (is(T == struct) && isSerializable!T)
            {
                result ~= SchemaInfo!T.toString();
                result ~= "\n\n";
            }
        }
    }}
    
    return result.data;
}

