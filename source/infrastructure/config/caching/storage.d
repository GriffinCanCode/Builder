module infrastructure.config.caching.storage;

import std.array;
import std.conv;
import std.algorithm;
import std.bitmanip : nativeToBigEndian, bigEndianToNative;
import infrastructure.config.workspace.ast;

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
    
    private static void serializeTarget(ref Appender!(ubyte[]) buffer, const ref TargetDeclStmt target)
    {
        writeString(buffer, target.name);
        writeUlong(buffer, target.loc.line);
        writeUlong(buffer, target.loc.column);
        
        // Fields
        writeUint(buffer, cast(uint)target.fields.length);
        foreach (ref field; target.fields)
        {
            serializeField(buffer, field);
        }
    }
    
    private static TargetDeclStmt deserializeTarget(const(ubyte)[] data, ref size_t offset)
    {
        string name = readString(data, offset);
        size_t line = readUlong(data, offset);
        size_t column = readUlong(data, offset);
        Location loc = Location("", line, column);
        
        uint fieldCount = readUint(data, offset);
        Field[] fields;
        fields.reserve(fieldCount);
        foreach (i; 0 .. fieldCount)
        {
            fields ~= deserializeField(data, offset);
        }
        
        return new TargetDeclStmt(name, fields, loc);
    }
    
    private static void serializeField(ref Appender!(ubyte[]) buffer, const ref Field field)
    {
        writeString(buffer, field.name);
        writeUlong(buffer, field.loc.line);
        writeUlong(buffer, field.loc.column);
        serializeExpr(buffer, field.value);
    }
    
    private static Field deserializeField(const(ubyte)[] data, ref size_t offset)
    {
        string name = readString(data, offset);
        size_t line = readUlong(data, offset);
        size_t column = readUlong(data, offset);
        Expr value = deserializeExpr(data, offset);
        Location loc = Location("", line, column);
        return Field(name, value, loc);
    }
    
    private static void serializeExpr(ref Appender!(ubyte[]) buffer, Expr expr)
    {
        // TODO: Implement proper Expr serialization with the new AST structure
        // Placeholder implementation
        buffer.put(cast(ubyte)0);
    }
    
    private static Expr deserializeExpr(const(ubyte)[] data, ref size_t offset)
    {
        // TODO: Implement proper Expr deserialization with the new AST structure
        // Placeholder implementation - skip the serialized byte
        offset++;
        return new LiteralExpr(Literal.makeNull(), Location("", 0, 0));
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

