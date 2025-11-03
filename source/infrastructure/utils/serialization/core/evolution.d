module infrastructure.utils.serialization.core.evolution;

import std.traits;
import infrastructure.utils.serialization.core.schema;

/// Schema evolution utilities for backward/forward compatibility
struct Evolution
{
    /// Check if schema change is backward compatible
    static bool isBackwardCompatible(T, U)()
        if (isSerializable!T && isSerializable!U)
    {
        enum oldVersion = getSchemaVersion!T;
        enum newVersion = getSchemaVersion!U;
        
        // Major version must match for backward compatibility
        if (oldVersion.major != newVersion.major)
            return false;
        
        // Check that all non-optional fields in old schema exist in new schema
        static foreach (oldField; T.tupleof)
        {{
            static if (!isOptionalField!oldField)
            {
                enum oldId = getFieldId!oldField;
                bool foundInNew = false;
                
                static foreach (newField; U.tupleof)
                {{
                    enum newId = getFieldId!newField;
                    if (oldId == newId)
                        foundInNew = true;
                }}
                
                if (!foundInNew)
                    return false;
            }
        }}
        
        return true;
    }
    
    /// Check if schema change is forward compatible
    static bool isForwardCompatible(T, U)()
        if (isSerializable!T && isSerializable!U)
    {
        // Forward compatible if we can read old data with new schema
        // All new fields must be optional
        static foreach (newField; U.tupleof)
        {{
            enum newId = getFieldId!newField;
            bool existsInOld = false;
            
            static foreach (oldField; T.tupleof)
            {{
                enum oldId = getFieldId!oldField;
                if (oldId == newId)
                    existsInOld = true;
            }}
            
            if (!existsInOld && !isOptionalField!newField)
                return false;
        }}
        
        return true;
    }
    
    /// List fields added between versions
    static string[] addedFields(T, U)()
        if (isSerializable!T && isSerializable!U)
    {
        string[] added;
        
        static foreach (newField; U.tupleof)
        {{
            enum newId = getFieldId!newField;
            bool existsInOld = false;
            
            static foreach (oldField; T.tupleof)
            {{
                enum oldId = getFieldId!oldField;
                if (oldId == newId)
                    existsInOld = true;
            }}
            
            if (!existsInOld)
                added ~= __traits(identifier, newField);
        }}
        
        return added;
    }
    
    /// List fields removed between versions
    static string[] removedFields(T, U)()
        if (isSerializable!T && isSerializable!U)
    {
        string[] removed;
        
        static foreach (oldField; T.tupleof)
        {{
            enum oldId = getFieldId!oldField;
            bool existsInNew = false;
            
            static foreach (newField; U.tupleof)
            {{
                enum newId = getFieldId!newField;
                if (oldId == newId)
                    existsInNew = true;
            }}
            
            if (!existsInNew)
                removed ~= __traits(identifier, oldField);
        }}
        
        return removed;
    }
    
    /// Generate migration report
    static string migrationReport(T, U)()
        if (isSerializable!T && isSerializable!U)
    {
        import std.format : format;
        import std.array : join;
        
        enum oldVersion = getSchemaVersion!T;
        enum newVersion = getSchemaVersion!U;
        enum added = addedFields!(T, U);
        enum removed = removedFields!(T, U);
        enum backward = isBackwardCompatible!(T, U);
        enum forward = isForwardCompatible!(T, U);
        
        string report = format("Schema Migration: %s v%d.%d -> v%d.%d\n",
            T.stringof,
            oldVersion.major, oldVersion.minor,
            newVersion.major, newVersion.minor);
        
        report ~= format("Backward Compatible: %s\n", backward ? "Yes" : "No");
        report ~= format("Forward Compatible: %s\n", forward ? "Yes" : "No");
        
        if (added.length > 0)
            report ~= format("Added Fields: %s\n", added.join(", "));
        
        if (removed.length > 0)
            report ~= format("Removed Fields: %s\n", removed.join(", "));
        
        return report;
    }
}

