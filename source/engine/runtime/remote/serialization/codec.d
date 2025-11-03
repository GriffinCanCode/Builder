module engine.runtime.remote.serialization.codec;

import std.datetime : dur;
import engine.runtime.hermetic;
import engine.runtime.remote.serialization.schema;
import infrastructure.utils.serialization;
import infrastructure.errors;

/// Hermetic spec serialization for transmission to workers
/// Uses high-performance SIMD-accelerated serialization framework
struct HermeticSpecCodec
{
    /// Serialize SandboxSpec for transmission
    /// 
    /// Uses high-performance Codec with:
    /// - SIMD-accelerated varint encoding
    /// - Compile-time code generation
    /// - Efficient buffer management
    static ubyte[] serialize(SandboxSpec spec) @trusted
    {
        auto serializable = toSerializable(spec);
        return Codec.serialize(serializable);
    }
    
    /// Deserialize SandboxSpec from transmission
    /// 
    /// Features:
    /// - Zero-copy deserialization where possible
    /// - Automatic schema version checking
    /// - Forward/backward compatibility
    static Result!(SandboxSpec, string) deserialize(const ubyte[] data) @system
    {
        if (data.length == 0)
            return Err!(SandboxSpec, string)("Empty data");
        
        // Deserialize with codec
        auto result = Codec.deserialize!SerializableSandboxSpec(cast(ubyte[])data);
        
        if (result.isErr)
            return Err!(SandboxSpec, string)("Deserialization failed: " ~ result.unwrapErr());
        
        auto serializable = result.unwrap();
        
        // Reconstruct SandboxSpec using builder
        auto builder = SandboxSpecBuilder.create();
        
        try
        {
            // Inputs
            foreach (input; serializable.inputs)
                builder.input(input);
            
            // Outputs
            foreach (output; serializable.outputs)
                builder.output(output);
            
            // Temps
            foreach (temp; serializable.temps)
                builder.temp(temp);
            
            // Network
            if (serializable.networkAllowed)
            {
                // Network allowed - use policy that allows hosts
                builder.withNetwork(NetworkPolicy.allowHosts([]));
            }
            
            // Environment
            foreach (i; 0 .. serializable.envKeys.length)
            {
                builder.env(serializable.envKeys[i], serializable.envValues[i]);
            }
            
            // Resources
            ResourceLimits limits;
            limits.maxMemoryBytes = serializable.maxMemoryBytes;
            limits.maxCpuTimeMs = serializable.maxCpuTimeMs;
            builder.withResources(limits);
            
            auto specResult = builder.build();
            if (specResult.isErr)
                return Err!(SandboxSpec, string)(specResult.unwrapErr());
            
            return Ok!(SandboxSpec, string)(specResult.unwrap());
        }
        catch (Exception e)
        {
            return Err!(SandboxSpec, string)("Build failed: " ~ e.msg);
        }
    }
}
