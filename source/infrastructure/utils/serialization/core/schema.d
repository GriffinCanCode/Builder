module infrastructure.utils.serialization.core.schema;

import std.traits;

/// Schema version for evolution tracking
struct SchemaVersion
{
    ushort major;
    ushort minor;
    
    /// Compare versions
    int opCmp()(auto ref const SchemaVersion other) const pure nothrow @nogc
    {
        if (major != other.major) return major - other.major;
        return minor - other.minor;
    }
}

/// Mark struct as serializable with version
struct Serializable
{
    SchemaVersion version_;
    uint magicNumber = 0;  // Optional validation magic
}

/// Field attributes

/// Mark field with explicit ID for evolution
struct Field
{
    ushort id;  // Stable field identifier
    string name = "";  // Optional name for debugging
}

/// Mark field as optional (can be missing in older versions)
struct Optional
{
}

/// Mark field as deprecated (warn on serialize, skip on deserialize)
struct Deprecated
{
    string reason = "";
    SchemaVersion sinceVersion;
}

/// Specify default value for optional fields
struct Default(T)
{
    T value;
}

/// Mark field for packed encoding (varint instead of fixed-size)
struct Packed
{
}

/// Mark string/array with max length constraint
struct MaxLength
{
    size_t length;
}

/// Mark integer with range constraint (for validation)
struct Range(T)
{
    T min;
    T max;
}

/// Custom serializer for non-standard types
struct CustomSerializer(alias Encoder, alias Decoder)
{
}

/// Compile-time schema validation

/// Check if type is serializable
enum bool isSerializable(T) = hasUDA!(T, Serializable);

/// Get schema version of type
template getSchemaVersion(T)
{
    static assert(isSerializable!T, T.stringof ~ " is not marked as @Serializable");
    enum getSchemaVersion = getUDAs!(T, Serializable)[0].version_;
}

/// Get field ID
template getFieldId(alias field)
{
    static if (hasUDA!(field, Field))
        enum getFieldId = getUDAs!(field, Field)[0].id;
    else
        static assert(0, "Field " ~ __traits(identifier, field) ~ " missing @Field attribute");
}

/// Check if field is optional
enum bool isOptionalField(alias field) = hasUDA!(field, Optional);

/// Check if field is deprecated
enum bool isDeprecatedField(alias field) = hasUDA!(field, Deprecated);

/// Check if field uses packed encoding
enum bool isPackedField(alias field) = hasUDA!(field, Packed);

/// Get max length constraint
template getMaxLength(alias field)
{
    static if (hasUDA!(field, MaxLength))
        enum getMaxLength = getUDAs!(field, MaxLength)[0].length;
    else
        enum getMaxLength = 0;  // No constraint
}

/// Get default value
template getDefaultValue(alias field)
{
    import std.traits : FieldNameTuple, Fields;
    
    alias T = typeof(field);
    static if (hasUDA!(field, Default!T))
        enum getDefaultValue = getUDAs!(field, Default!T)[0].value;
    else
        enum getDefaultValue = T.init;
}

/// Validate schema at compile time
template validateSchema(T)
{
    static assert(isSerializable!T, T.stringof ~ " must be marked with @Serializable");
    
    // Check all fields have @Field attribute
    static foreach (i, field; T.tupleof)
    {
        static assert(hasUDA!(field, Field), 
            "Field " ~ __traits(identifier, field) ~ " in " ~ T.stringof ~ 
            " must have @Field(id) attribute");
    }
    
    // Check for duplicate field IDs
    enum bool validateSchema = checkNoDuplicateFieldIds!T;
}

/// Check no duplicate field IDs
template checkNoDuplicateFieldIds(T)
{
    private static bool impl()
    {
        bool[ushort] ids;
        static foreach (field; T.tupleof)
        {
            enum id = getFieldId!field;
            if (id in ids)
                return false;
            ids[id] = true;
        }
        return true;
    }
    
    enum bool checkNoDuplicateFieldIds = impl();
}

/// Get serialization order (sorted by field ID)
template getSerializationOrder(T)
{
    import std.algorithm : sort;
    import std.array : array;
    
    private static auto impl()
    {
        size_t[] order;
        static foreach (i, field; T.tupleof)
        {
            order ~= i;
        }
        
        // Sort by field ID
        import std.algorithm.sorting : sort;
        order.sort!((a, b) {
            enum idA = getFieldId!(T.tupleof[a]);
            enum idB = getFieldId!(T.tupleof[b]);
            return idA < idB;
        });
        
        return order;
    }
    
    enum getSerializationOrder = impl();
}

/// Count serializable fields
template countSerializableFields(T)
{
    private static size_t impl()
    {
        size_t count = 0;
        static foreach (field; T.tupleof)
        {
            static if (!isDeprecatedField!field)
                count++;
        }
        return count;
    }
    
    enum size_t countSerializableFields = impl();
}

