module runtime.remote.codec;

import std.datetime : dur;
import std.bitmanip : write, read;
import runtime.hermetic;
import errors;

/// Hermetic spec serialization for transmission to workers
/// Central codec for encoding/decoding SandboxSpec across the wire
struct HermeticSpecCodec
{
    /// Serialize SandboxSpec for transmission
    /// 
    /// Responsibility: Convert SandboxSpec to wire format
    /// Used by: RemoteExecutor for sending specs to workers
    static ubyte[] serialize(SandboxSpec spec) @trusted
    {
        ubyte[] buffer;
        buffer.reserve(4096);
        
        // Inputs
        buffer.write!uint(cast(uint)spec.inputs.paths.length, buffer.length);
        foreach (input; spec.inputs.paths)
        {
            buffer.write!uint(cast(uint)input.length, buffer.length);
            buffer ~= cast(ubyte[])input;
        }
        
        // Outputs
        buffer.write!uint(cast(uint)spec.outputs.paths.length, buffer.length);
        foreach (output; spec.outputs.paths)
        {
            buffer.write!uint(cast(uint)output.length, buffer.length);
            buffer ~= cast(ubyte[])output;
        }
        
        // Temp directories
        buffer.write!uint(cast(uint)spec.temps.paths.length, buffer.length);
        foreach (temp; spec.temps.paths)
        {
            buffer.write!uint(cast(uint)temp.length, buffer.length);
            buffer ~= cast(ubyte[])temp;
        }
        
        // Flags
        ubyte flags = 0;
        if (!spec.network.isHermetic) flags |= 0x01;  // Network allowed if not hermetic
        buffer.write!ubyte(flags, buffer.length);
        
        // Environment
        buffer.write!uint(cast(uint)spec.environment.vars.length, buffer.length);
        foreach (key, value; spec.environment.vars)
        {
            buffer.write!uint(cast(uint)key.length, buffer.length);
            buffer ~= cast(ubyte[])key;
            buffer.write!uint(cast(uint)value.length, buffer.length);
            buffer ~= cast(ubyte[])value;
        }
        
        // Resources
        buffer.write!ulong(spec.resources.maxMemoryBytes, buffer.length);
        buffer.write!ulong(spec.resources.maxCpuTimeMs, buffer.length);
        buffer.write!ulong(spec.resources.maxCpuTimeMs, buffer.length);  // Use maxCpuTimeMs as timeout
        
        return buffer;
    }
    
    /// Deserialize SandboxSpec from transmission
    /// 
    /// Responsibility: Reconstruct SandboxSpec from wire format
    /// Used by: Workers for receiving specs from coordinator
    static Result!(SandboxSpec, string) deserialize(const ubyte[] data) @system
    {
        if (data.length < 4)
            return Err!(SandboxSpec, string)("Data too short");
        
        ubyte[] mutableData = cast(ubyte[])data.dup;
        size_t offset = 0;
        
        auto builder = SandboxSpecBuilder.create();
        
        try
        {
            // Inputs
            auto inputCountSlice = mutableData[offset .. offset + 4];
            immutable inputCount = inputCountSlice.read!uint();
            offset += 4;
            
            foreach (_; 0 .. inputCount)
            {
                auto lenSlice = mutableData[offset .. offset + 4];
                immutable len = lenSlice.read!uint();
                offset += 4;
                
                immutable path = cast(string)data[offset .. offset + len];
                offset += len;
                
                builder.input(path);
            }
            
            // Outputs
            auto outputCountSlice = mutableData[offset .. offset + 4];
            immutable outputCount = outputCountSlice.read!uint();
            offset += 4;
            
            foreach (_; 0 .. outputCount)
            {
                auto lenSlice = mutableData[offset .. offset + 4];
                immutable len = lenSlice.read!uint();
                offset += 4;
                
                immutable path = cast(string)data[offset .. offset + len];
                offset += len;
                
                builder.output(path);
            }
            
            // Temps
            auto tempCountSlice = mutableData[offset .. offset + 4];
            immutable tempCount = tempCountSlice.read!uint();
            offset += 4;
            
            foreach (_; 0 .. tempCount)
            {
                auto lenSlice = mutableData[offset .. offset + 4];
                immutable len = lenSlice.read!uint();
                offset += 4;
                
                immutable path = cast(string)data[offset .. offset + len];
                offset += len;
                
                builder.temp(path);
            }
            
            // Flags
            auto flagSlice = mutableData[offset .. offset + 1];
            immutable flags = flagSlice.read!ubyte();
            offset += 1;
            
            if (flags & 0x01)
            {
                // Network allowed - use policy that allows hosts
                builder.withNetwork(NetworkPolicy.allowHosts([]));
            }
            
            // Environment
            auto envCountSlice = mutableData[offset .. offset + 4];
            immutable envCount = envCountSlice.read!uint();
            offset += 4;
            
            foreach (_; 0 .. envCount)
            {
                auto keyLenSlice = mutableData[offset .. offset + 4];
                immutable keyLen = keyLenSlice.read!uint();
                offset += 4;
                
                immutable key = cast(string)data[offset .. offset + keyLen];
                offset += keyLen;
                
                auto valLenSlice = mutableData[offset .. offset + 4];
                immutable valLen = valLenSlice.read!uint();
                offset += 4;
                
                immutable value = cast(string)data[offset .. offset + valLen];
                offset += valLen;
                
                builder.env(key, value);
            }
            
            // Resources
            auto memSlice = mutableData[offset .. offset + 8];
            immutable maxMemory = memSlice.read!ulong();
            offset += 8;
            
            auto cpuSlice = mutableData[offset .. offset + 8];
            immutable maxCpu = cpuSlice.read!ulong();
            offset += 8;
            
            auto timeoutSlice = mutableData[offset .. offset + 8];
            immutable timeoutMs = timeoutSlice.read!ulong();
            
            // Set resources using the builder's withResources method
            ResourceLimits limits;
            limits.maxMemoryBytes = maxMemory;
            limits.maxCpuTimeMs = timeoutMs;
            builder.withResources(limits);
            
            auto specResult = builder.build();
            if (specResult.isErr)
                return Err!(SandboxSpec, string)(specResult.unwrapErr());
            
            return Ok!(SandboxSpec, string)(specResult.unwrap());
        }
        catch (Exception e)
        {
            return Err!(SandboxSpec, string)("Deserialization failed: " ~ e.msg);
        }
    }
}

