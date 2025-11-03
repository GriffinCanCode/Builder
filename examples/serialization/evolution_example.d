#!/usr/bin/env dub
/+ dub.sdl:
    name "serialization_evolution"
+/

/**
 * Schema Evolution Example
 * 
 * Demonstrates forward/backward compatibility
 */

import std.stdio;
import infrastructure.utils.serialization;

/// Version 1 of our data structure
@Serializable(SchemaVersion(1, 0))
struct DataV1
{
    @Field(1) uint id;
    @Field(2) string name;
}

/// Version 2: Added optional field
@Serializable(SchemaVersion(1, 1))
struct DataV2
{
    @Field(1) uint id;
    @Field(2) string name;
    @Field(3) @Optional @Default!string("unknown") string category;
}

/// Version 3: Added another optional field
@Serializable(SchemaVersion(1, 2))
struct DataV3
{
    @Field(1) uint id;
    @Field(2) string name;
    @Field(3) @Optional @Default!string("unknown") string category;
    @Field(4) @Optional @Packed long timestamp;
}

void main()
{
    writeln("=== Schema Evolution Example ===\n");
    
    // Show schema info
    writeln("Version 1 Schema:");
    writeln(SchemaInfo!DataV1.toString());
    writeln();
    
    writeln("Version 2 Schema:");
    writeln(SchemaInfo!DataV2.toString());
    writeln();
    
    writeln("Version 3 Schema:");
    writeln(SchemaInfo!DataV3.toString());
    writeln();
    
    // Check compatibility
    writeln("=== Compatibility Analysis ===\n");
    
    enum v1to2backward = Evolution.isBackwardCompatible!(DataV1, DataV2);
    enum v1to2forward = Evolution.isForwardCompatible!(DataV1, DataV2);
    writefln("V1 -> V2 Backward Compatible: %s", v1to2backward ? "✓" : "✗");
    writefln("V1 -> V2 Forward Compatible: %s", v1to2forward ? "✓" : "✗");
    writeln();
    
    enum v2to3backward = Evolution.isBackwardCompatible!(DataV2, DataV3);
    enum v2to3forward = Evolution.isForwardCompatible!(DataV2, DataV3);
    writefln("V2 -> V3 Backward Compatible: %s", v2to3backward ? "✓" : "✗");
    writefln("V2 -> V3 Forward Compatible: %s", v2to3forward ? "✓" : "✗");
    writeln();
    
    // Generate migration report
    writeln("=== Migration Report (V1 -> V3) ===\n");
    writeln(Evolution.migrationReport!(DataV1, DataV3));
    
    // Demonstrate actual migration
    writeln("\n=== Practical Example ===\n");
    
    // Create V1 data
    auto v1 = DataV1(1, "Test");
    writeln("Original V1 data:");
    writefln("  id=%s, name=%s", v1.id, v1.name);
    
    // Serialize as V1
    auto v1bytes = Codec.serialize(v1);
    writefln("Serialized: %d bytes", v1bytes.length);
    
    // Try to deserialize as V2 (with optional field)
    // Note: In real implementation, would need better field skipping
    writeln("\nNote: Full cross-version deserialization requires");
    writeln("field skipping implementation (future enhancement)");
}

