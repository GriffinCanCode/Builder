module engine.runtime.hermetic.determinism.integration;

import std.conv : to;
import infrastructure.config.schema.schema;
import engine.runtime.hermetic.core.spec;
import engine.runtime.hermetic.core.executor;
import engine.runtime.hermetic.determinism.enforcer;
import engine.caching.actions.action;
import infrastructure.errors;

/// Integration helpers for determinism enforcement
/// 
/// Provides utility functions to integrate determinism enforcement
/// with existing Builder systems (config, cache, language handlers)

/// Convert DeterminismOptions to DeterminismConfig
DeterminismConfig toDeterminismConfig(const DeterminismOptions options) @safe pure nothrow
{
    DeterminismConfig config;
    config.fixedTimestamp = options.fixedTimestamp;
    config.prngSeed = options.prngSeed;
    config.normalizeTimestamps = options.normalizeTimestamps;
    config.deterministicThreading = options.deterministicThreading;
    config.strictMode = options.strictMode;
    return config;
}

/// Create DeterminismEnforcer from workspace configuration
Result!(DeterminismEnforcer, BuildError) createEnforcerFromConfig(
    HermeticExecutor executor,
    const BuildOptions options
) @system
{
    if (!options.determinism.enabled)
    {
        return Err!(DeterminismEnforcer, BuildError)(
            new SystemError("Determinism not enabled in configuration", 
                          ErrorCode.InvalidConfiguration));
    }
    
    auto config = toDeterminismConfig(options.determinism);
    return DeterminismEnforcer.create(executor, config);
}

/// Update ActionEntry with determinism verification result
void updateWithDeterminismResult(
    ref ActionEntry entry,
    const DeterminismResult result
) @safe
{
    entry.isDeterministic = result.deterministic;
    entry.verificationHash = result.outputHash;
    
    if (result.deterministic)
        entry.determinismVerifications++;
    
    // Add determinism metadata
    entry.metadata["deterministic"] = result.deterministic.to!string;
    entry.metadata["det_violations"] = result.violations.length.to!string;
    entry.metadata["det_overhead_ms"] = result.enforcementOverhead.total!"msecs".to!string;
}

/// Check if action cache entry is deterministically valid
bool isDeterministicallyValid(
    const ActionEntry entry,
    const string expectedHash
) @safe pure nothrow
{
    if (!entry.isDeterministic)
        return false;
    
    if (entry.verificationHash.length == 0)
        return false;
    
    // Optionally verify hash matches
    if (expectedHash.length > 0 && entry.verificationHash != expectedHash)
        return false;
    
    return true;
}

/// Create determinism metadata for action cache
string[string] createDeterminismMetadata(
    const DeterminismConfig config
) @safe
{
    string[string] metadata;
    metadata["det_timestamp"] = config.fixedTimestamp.to!string;
    metadata["det_seed"] = config.prngSeed.to!string;
    metadata["det_threading"] = config.deterministicThreading.to!string;
    metadata["det_strict"] = config.strictMode.to!string;
    return metadata;
}

@safe unittest
{
    import std.stdio : writeln;
    
    writeln("Testing determinism integration...");
    
    // Test config conversion
    DeterminismOptions options;
    options.enabled = true;
    options.strictMode = true;
    options.fixedTimestamp = 1234567890;
    options.prngSeed = 99;
    
    auto config = toDeterminismConfig(options);
    assert(config.fixedTimestamp == 1234567890);
    assert(config.prngSeed == 99);
    assert(config.strictMode);
    
    // Test metadata creation
    auto metadata = createDeterminismMetadata(config);
    assert("det_timestamp" in metadata);
    assert("det_seed" in metadata);
    assert(metadata["det_timestamp"] == "1234567890");
    assert(metadata["det_seed"] == "99");
    
    writeln("✓ Determinism integration tests passed");
}

