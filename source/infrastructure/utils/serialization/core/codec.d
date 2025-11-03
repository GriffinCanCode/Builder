module infrastructure.utils.serialization.core.codec;

import std.traits;
import std.meta;
import infrastructure.utils.serialization.core.schema;
import infrastructure.utils.serialization.core.buffer;
import infrastructure.errors;

/// High-performance codec with compile-time code generation
/// Zero overhead - generates optimal code for each type at compile time
struct Codec
{
    /// Serialize value to bytes
    static ubyte[] serialize(T)(auto ref const(T) value) @trusted
        if (isSerializable!T)
    {
        enum estimatedSize = estimateSize!T;
        auto writer = WriteBuffer(estimatedSize);
        
        // Write schema version and magic
        enum version_ = getSchemaVersion!T;
        enum magic = getUDAs!(T, Serializable)[0].magicNumber;
        
        if (magic != 0)
            writer.writeU32(magic);
        
        writer.writeU16(version_.major);
        writer.writeU16(version_.minor);
        
        // Serialize fields in ID order
        serializeFields(writer, value);
        
        return cast(ubyte[])writer.data.dup;
    }
    
    /// Deserialize from bytes
    static Result!(T, string) deserialize(T)(scope const(ubyte)[] data) @system
        if (isSerializable!T)
    {
        try
        {
            auto reader = ReadBuffer(data);
            
            // Verify magic if present
            enum magic = getUDAs!(T, Serializable)[0].magicNumber;
            if (magic != 0)
            {
                auto readMagic = reader.readU32();
                if (readMagic != magic)
                    return Err!(T, string)("Invalid magic number");
            }
            
            // Read schema version
            auto major = reader.readU16();
            auto minor = reader.readU16();
            auto dataVersion = SchemaVersion(major, minor);
            
            // Check version compatibility
            enum currentVersion = getSchemaVersion!T;
            if (dataVersion.major > currentVersion.major)
                return Err!(T, string)("Incompatible schema version");
            
            T result;
            auto parseResult = deserializeFields(reader, result, dataVersion);
            if (parseResult.isErr)
                return Err!(T, string)(parseResult.unwrapErr());
            
            return Ok!(T, string)(result);
        }
        catch (Exception e)
        {
            return Err!(T, string)(e.msg);
        }
    }
    
    /// Estimate serialized size at compile time
    private static template estimateSize(T)
    {
        enum estimateSize = () {
            size_t size = 8;  // Version + magic
            static foreach (field; T.tupleof)
            {
                alias FieldType = typeof(field);
                static if (is(FieldType == string))
                    size += 64;  // Estimate
                else static if (isArray!FieldType)
                    size += 128;
                else static if (is(FieldType == struct))
                    size += 256;
                else
                    size += FieldType.sizeof;
            }
            return size;
        }();
    }
    
    /// Serialize all fields
    private static void serializeFields(T)(ref WriteBuffer writer, auto ref const(T) value) @trusted
    {
        // Write field count (for forward compatibility)
        enum fieldCount = countSerializableFields!T;
        writer.writeVarU32(fieldCount);
        
        // Serialize each field in ID order
        static foreach (field; T.tupleof)
        {{
            static if (!isDeprecatedField!field)
            {
                enum fieldId = getFieldId!field;
                alias FieldType = typeof(field);
                
                // Write field ID
                writer.writeVarU32(fieldId);
                
                // Serialize field value
                serializeValue(writer, __traits(getMember, value, __traits(identifier, field)));
            }
        }}
    }
    
    /// Deserialize all fields
    private static Result!(void, string) deserializeFields(T)(
        ref ReadBuffer reader,
        ref T result,
        SchemaVersion dataVersion) @system
    {
        try
        {
            auto fieldCount = reader.readVarU32();
            
            // Read each field
            foreach (i; 0 .. fieldCount)
            {
                auto fieldId = reader.readVarU32();
                
                // Find matching field by ID
                bool found = false;
                static foreach (field; T.tupleof)
                {{
                    enum currentFieldId = getFieldId!field;
                    if (fieldId == currentFieldId)
                    {
                        // Deserialize into field
                        alias FieldType = typeof(field);
                        auto fieldResult = deserializeValue!FieldType(reader);
                        if (fieldResult.isErr)
                            return Err!(void, string)(fieldResult.unwrapErr());
                        
                        __traits(getMember, result, __traits(identifier, field)) = 
                            fieldResult.unwrap();
                        found = true;
                    }
                }}
                
                // Skip unknown fields (for forward compatibility)
                if (!found)
                {
                    // Skip field by reading as generic bytes
                    // This requires type information - for now, fail
                    return Err!(void, string)("Unknown field ID: " ~ fieldId.stringof);
                }
            }
            
            // Set defaults for missing optional fields
            static foreach (field; T.tupleof)
            {{
                static if (isOptionalField!field)
                {
                    // Check if field was set (would need tracking)
                    // For now, use default value
                    alias FieldType = typeof(field);
                    enum defaultValue = getDefaultValue!field;
                    // __traits(getMember, result, __traits(identifier, field)) = defaultValue;
                }
            }}
            
            return Ok!(void, string)();
        }
        catch (Exception e)
        {
            return Err!(void, string)(e.msg);
        }
    }
    
    /// Serialize single value (type dispatch)
    private static void serializeValue(T)(ref WriteBuffer writer, auto ref const(T) value) @trusted
    {
        static if (is(T == bool))
        {
            writer.writeByte(value ? 1 : 0);
        }
        else static if (is(T == byte) || is(T == ubyte))
        {
            writer.writeByte(cast(ubyte)value);
        }
        else static if (is(T == short) || is(T == ushort))
        {
            static if (isPackedField!value)
                writer.writeVarI32(value);
            else
                writer.writeU16(cast(ushort)value);
        }
        else static if (is(T == int) || is(T == uint))
        {
            static if (isPackedField!value)
                writer.writeVarI32(cast(int)value);
            else
                writer.writeU32(cast(uint)value);
        }
        else static if (is(T == long) || is(T == ulong))
        {
            static if (isPackedField!value)
                writer.writeVarI64(cast(long)value);
            else
                writer.writeU64(cast(ulong)value);
        }
        else static if (is(T == float))
        {
            writer.writeU32(*cast(uint*)&value);
        }
        else static if (is(T == double))
        {
            writer.writeU64(*cast(ulong*)&value);
        }
        else static if (is(T == string))
        {
            writer.writeString(value);
        }
        else static if (isArray!T)
        {
            writer.writeVarU32(cast(uint)value.length);
            foreach (ref elem; value)
                serializeValue(writer, elem);
        }
        else static if (is(T == struct))
        {
            static if (isSerializable!T)
            {
                // Nested serializable struct
                serializeFields(writer, value);
            }
            else
            {
                static assert(0, "Cannot serialize non-@Serializable struct: " ~ T.stringof);
            }
        }
        else static if (is(T : V[K], K, V))
        {
            // Associative array
            writer.writeVarU32(cast(uint)value.length);
            foreach (k, v; value)
            {
                serializeValue(writer, k);
                serializeValue(writer, v);
            }
        }
        else
        {
            static assert(0, "Cannot serialize type: " ~ T.stringof);
        }
    }
    
    /// Deserialize single value (type dispatch)
    private static Result!(T, string) deserializeValue(T)(ref ReadBuffer reader) @system
    {
        try
        {
            static if (is(T == bool))
            {
                return Ok!(T, string)(reader.readByte() != 0);
            }
            else static if (is(T == byte) || is(T == ubyte))
            {
                return Ok!(T, string)(cast(T)reader.readByte());
            }
            else static if (is(T == short))
            {
                return Ok!(T, string)(cast(short)reader.readVarI32());
            }
            else static if (is(T == ushort))
            {
                return Ok!(T, string)(cast(ushort)reader.readU16());
            }
            else static if (is(T == int))
            {
                return Ok!(T, string)(reader.readVarI32());
            }
            else static if (is(T == uint))
            {
                return Ok!(T, string)(reader.readVarU32());
            }
            else static if (is(T == long))
            {
                return Ok!(T, string)(reader.readVarI64());
            }
            else static if (is(T == ulong))
            {
                return Ok!(T, string)(reader.readVarU64());
            }
            else static if (is(T == float))
            {
                uint bits = reader.readU32();
                return Ok!(T, string)(*cast(float*)&bits);
            }
            else static if (is(T == double))
            {
                ulong bits = reader.readU64();
                return Ok!(T, string)(*cast(double*)&bits);
            }
            else static if (is(T == string))
            {
                return Ok!(T, string)(reader.readString());
            }
            else static if (isArray!T)
            {
                alias ElemType = ForeachType!T;
                auto len = reader.readVarU32();
                T result;
                result.reserve(len);
                
                foreach (i; 0 .. len)
                {
                    auto elemResult = deserializeValue!ElemType(reader);
                    if (elemResult.isErr)
                        return Err!(T, string)(elemResult.unwrapErr());
                    result ~= elemResult.unwrap();
                }
                
                return Ok!(T, string)(result);
            }
            else static if (is(T == struct))
            {
                T result;
                auto fieldResult = deserializeFields(reader, result, SchemaVersion(0, 0));
                if (fieldResult.isErr)
                    return Err!(T, string)(fieldResult.unwrapErr());
                return Ok!(T, string)(result);
            }
            else static if (is(T : V[K], K, V))
            {
                auto len = reader.readVarU32();
                T result;
                
                foreach (i; 0 .. len)
                {
                    auto keyResult = deserializeValue!K(reader);
                    if (keyResult.isErr)
                        return Err!(T, string)(keyResult.unwrapErr());
                    
                    auto valResult = deserializeValue!V(reader);
                    if (valResult.isErr)
                        return Err!(T, string)(valResult.unwrapErr());
                    
                    result[keyResult.unwrap()] = valResult.unwrap();
                }
                
                return Ok!(T, string)(result);
            }
            else
            {
                static assert(0, "Cannot deserialize type: " ~ T.stringof);
            }
        }
        catch (Exception e)
        {
            return Err!(T, string)(e.msg);
        }
    }
}

