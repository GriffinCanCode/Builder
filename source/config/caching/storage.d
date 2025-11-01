module config.caching.storage;

import std.array;
import std.conv;
import std.algorithm;
import std.bitmanip : nativeToBigEndian, bigEndianToNative;
import config.workspace.ast;

/// Binary serialization for AST nodes
/// 
/// Design: Custom binary format for speed and compactness
/// - Version header for forward compatibility
/// - Type tags for tagged union discrimination
/// - Length-prefixed strings and arrays
/// - Zero-copy deserialization where possible
struct ASTStorage
{
    private enum ubyte VERSION = 1;
    
    /// Serialize BuildFile AST to binary format
    static ubyte[] serialize(const ref BuildFile ast)
    {
        auto buffer = appender!(ubyte[]);
        buffer.reserve(4096); // Reasonable initial capacity
        
        // Version header
        buffer.put(VERSION);
        
        // File path
        writeString(buffer, ast.filePath);
        
        // Targets array
        writeUint(buffer, cast(uint)ast.targets.length);
        foreach (ref target; ast.targets)
        {
            serializeTarget(buffer, target);
        }
        
        return buffer.data;
    }
    
    /// Deserialize BuildFile AST from binary format
    static BuildFile deserialize(const(ubyte)[] data)
    {
        size_t offset = 0;
        
        // Check version
        ubyte version_ = data[offset++];
        if (version_ != VERSION)
            throw new Exception("Incompatible AST cache version");
        
        BuildFile file;
        
        // Read file path
        file.filePath = readString(data, offset);
        
        // Read targets
        uint targetCount = readUint(data, offset);
        file.targets.reserve(targetCount);
        foreach (i; 0 .. targetCount)
        {
            file.targets ~= deserializeTarget(data, offset);
        }
        
        return file;
    }
    
    private static void serializeTarget(ref Appender!(ubyte[]) buffer, const ref TargetDecl target)
    {
        writeString(buffer, target.name);
        writeUlong(buffer, target.line);
        writeUlong(buffer, target.column);
        
        // Fields
        writeUint(buffer, cast(uint)target.fields.length);
        foreach (ref field; target.fields)
        {
            serializeField(buffer, field);
        }
    }
    
    private static TargetDecl deserializeTarget(const(ubyte)[] data, ref size_t offset)
    {
        TargetDecl target;
        target.name = readString(data, offset);
        target.line = readUlong(data, offset);
        target.column = readUlong(data, offset);
        
        uint fieldCount = readUint(data, offset);
        target.fields.reserve(fieldCount);
        foreach (i; 0 .. fieldCount)
        {
            target.fields ~= deserializeField(data, offset);
        }
        
        return target;
    }
    
    private static void serializeField(ref Appender!(ubyte[]) buffer, const ref Field field)
    {
        writeString(buffer, field.name);
        writeUlong(buffer, field.line);
        writeUlong(buffer, field.column);
        serializeExpression(buffer, field.value);
    }
    
    private static Field deserializeField(const(ubyte)[] data, ref size_t offset)
    {
        Field field;
        field.name = readString(data, offset);
        field.line = readUlong(data, offset);
        field.column = readUlong(data, offset);
        field.value = deserializeExpression(data, offset);
        return field;
    }
    
    private static void serializeExpression(ref Appender!(ubyte[]) buffer, const ref ExpressionValue expr)
    {
        // Write discriminator
        buffer.put(cast(ubyte)expr.kind);
        
        final switch (expr.kind)
        {
            case ExpressionValue.Kind.String:
                writeString(buffer, expr.stringValue.value);
                writeUlong(buffer, expr.stringValue.line);
                writeUlong(buffer, expr.stringValue.column);
                break;
                
            case ExpressionValue.Kind.Number:
                writeLong(buffer, expr.numberValue.value);
                writeUlong(buffer, expr.numberValue.line);
                writeUlong(buffer, expr.numberValue.column);
                break;
                
            case ExpressionValue.Kind.Identifier:
                writeString(buffer, expr.identifierValue.name);
                writeUlong(buffer, expr.identifierValue.line);
                writeUlong(buffer, expr.identifierValue.column);
                break;
                
            case ExpressionValue.Kind.Array:
                auto arr = expr.arrayValue;
                writeUlong(buffer, arr.line);
                writeUlong(buffer, arr.column);
                writeUint(buffer, cast(uint)arr.elements.length);
                foreach (ref elem; arr.elements)
                {
                    serializeExpression(buffer, elem);
                }
                break;
                
            case ExpressionValue.Kind.Map:
                auto map = expr.mapValue;
                writeUlong(buffer, map.line);
                writeUlong(buffer, map.column);
                writeUint(buffer, cast(uint)map.pairs.length);
                foreach (key, ref value; map.pairs)
                {
                    writeString(buffer, key);
                    serializeExpression(buffer, value);
                }
                break;
        }
    }
    
    private static ExpressionValue deserializeExpression(const(ubyte)[] data, ref size_t offset)
    {
        auto kind = cast(ExpressionValue.Kind)data[offset++];
        
        final switch (kind)
        {
            case ExpressionValue.Kind.String:
                string value = readString(data, offset);
                size_t line = readUlong(data, offset);
                size_t col = readUlong(data, offset);
                return ExpressionValue.fromString(value, line, col);
                
            case ExpressionValue.Kind.Number:
                long value = readLong(data, offset);
                size_t line = readUlong(data, offset);
                size_t col = readUlong(data, offset);
                return ExpressionValue.fromNumber(value, line, col);
                
            case ExpressionValue.Kind.Identifier:
                string name = readString(data, offset);
                size_t line = readUlong(data, offset);
                size_t col = readUlong(data, offset);
                return ExpressionValue.fromIdentifier(name, line, col);
                
            case ExpressionValue.Kind.Array:
                size_t line = readUlong(data, offset);
                size_t col = readUlong(data, offset);
                uint count = readUint(data, offset);
                ExpressionValue[] elements;
                elements.reserve(count);
                foreach (i; 0 .. count)
                {
                    elements ~= deserializeExpression(data, offset);
                }
                return ExpressionValue.fromArray(elements, line, col);
                
            case ExpressionValue.Kind.Map:
                size_t line = readUlong(data, offset);
                size_t col = readUlong(data, offset);
                uint count = readUint(data, offset);
                ExpressionValue[string] pairs;
                foreach (i; 0 .. count)
                {
                    string key = readString(data, offset);
                    ExpressionValue value = deserializeExpression(data, offset);
                    pairs[key] = value;
                }
                return ExpressionValue.fromMap(pairs, line, col);
        }
    }
    
    // Primitive serialization helpers
    
    private static void writeString(ref Appender!(ubyte[]) buffer, string str)
    {
        writeUint(buffer, cast(uint)str.length);
        buffer.put(cast(const(ubyte)[])str);
    }
    
    private static string readString(const(ubyte)[] data, ref size_t offset)
    {
        uint len = readUint(data, offset);
        string result = cast(string)data[offset .. offset + len];
        offset += len;
        return result;
    }
    
    private static void writeUint(ref Appender!(ubyte[]) buffer, uint value)
    {
        buffer.put(nativeToBigEndian(value)[]);
    }
    
    private static uint readUint(const(ubyte)[] data, ref size_t offset)
    {
        ubyte[4] bytes = data[offset .. offset + 4];
        offset += 4;
        return bigEndianToNative!uint(bytes);
    }
    
    private static void writeUlong(ref Appender!(ubyte[]) buffer, ulong value)
    {
        buffer.put(nativeToBigEndian(value)[]);
    }
    
    private static ulong readUlong(const(ubyte)[] data, ref size_t offset)
    {
        ubyte[8] bytes = data[offset .. offset + 8];
        offset += 8;
        return bigEndianToNative!ulong(bytes);
    }
    
    private static void writeLong(ref Appender!(ubyte[]) buffer, long value)
    {
        buffer.put(nativeToBigEndian(value)[]);
    }
    
    private static long readLong(const(ubyte)[] data, ref size_t offset)
    {
        ubyte[8] bytes = data[offset .. offset + 8];
        offset += 8;
        return bigEndianToNative!long(bytes);
    }
}

unittest
{
    // Test basic serialization roundtrip
    BuildFile original;
    original.filePath = "test.build";
    
    TargetDecl target;
    target.name = "app";
    target.line = 1;
    target.column = 1;
    
    Field field;
    field.name = "type";
    field.line = 2;
    field.column = 5;
    field.value = ExpressionValue.fromIdentifier("executable", 2, 11);
    
    target.fields ~= field;
    original.targets ~= target;
    
    // Serialize and deserialize
    auto serialized = ASTStorage.serialize(original);
    auto deserialized = ASTStorage.deserialize(serialized);
    
    assert(deserialized.filePath == original.filePath);
    assert(deserialized.targets.length == 1);
    assert(deserialized.targets[0].name == "app");
    assert(deserialized.targets[0].fields.length == 1);
    assert(deserialized.targets[0].fields[0].name == "type");
}

