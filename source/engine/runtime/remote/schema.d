module engine.runtime.remote.schema;

import infrastructure.utils.serialization;

/// Serializable sandbox specification for remote execution
@Serializable(SchemaVersion(1, 0), 0x53424F58) // "SBOX" - Sandbox Spec
struct SerializableSandboxSpec
{
    @Field(1) string[] inputs;
    @Field(2) string[] outputs;
    @Field(3) string[] temps;
    @Field(4) bool networkAllowed;
    @Field(5) string[] envKeys;
    @Field(6) string[] envValues;
    @Field(7) @Packed ulong maxMemoryBytes;
    @Field(8) @Packed ulong maxCpuTimeMs;
    @Field(9) @Packed ulong timeoutMs;
}

/// Convert SandboxSpec to serializable format
SerializableSandboxSpec toSerializable(T)(auto ref const T spec) @trusted
{
    SerializableSandboxSpec serializable;
    
    // Inputs
    static if (__traits(hasMember, T, "inputs"))
    {
        static if (__traits(hasMember, typeof(spec.inputs), "paths"))
            serializable.inputs = spec.inputs.paths.dup;
        else
            serializable.inputs = spec.inputs.dup;
    }
    
    // Outputs
    static if (__traits(hasMember, T, "outputs"))
    {
        static if (__traits(hasMember, typeof(spec.outputs), "paths"))
            serializable.outputs = spec.outputs.paths.dup;
        else
            serializable.outputs = spec.outputs.dup;
    }
    
    // Temps
    static if (__traits(hasMember, T, "temps"))
    {
        static if (__traits(hasMember, typeof(spec.temps), "paths"))
            serializable.temps = spec.temps.paths.dup;
        else
            serializable.temps = spec.temps.dup;
    }
    
    // Network
    static if (__traits(hasMember, T, "network"))
    {
        static if (__traits(hasMember, typeof(spec.network), "isHermetic"))
            serializable.networkAllowed = !spec.network.isHermetic;
        else
            serializable.networkAllowed = spec.network;
    }
    
    // Environment
    static if (__traits(hasMember, T, "environment"))
    {
        static if (__traits(hasMember, typeof(spec.environment), "vars"))
        {
            foreach (key, value; spec.environment.vars)
            {
                serializable.envKeys ~= key;
                serializable.envValues ~= value;
            }
        }
    }
    
    // Resources
    static if (__traits(hasMember, T, "resources"))
    {
        serializable.maxMemoryBytes = spec.resources.maxMemoryBytes;
        serializable.maxCpuTimeMs = spec.resources.maxCpuTimeMs;
        serializable.timeoutMs = spec.resources.maxCpuTimeMs;
    }
    
    return serializable;
}

