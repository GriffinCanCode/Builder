module tests.unit.utils.integrity;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import utils.security.integrity;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.integrity - Basic integrity signing and verification");
    
    auto validator = IntegrityValidator.create();
    ubyte[] data = cast(ubyte[])"Hello, Builder!";
    
    // Sign the data
    auto signature = validator.sign(data);
    
    // Verify the signature
    Assert.isTrue(validator.verify(data, signature));
    
    // Modified data should fail verification
    ubyte[] modifiedData = cast(ubyte[])"Hello, Hacker!";
    Assert.isFalse(validator.verify(modifiedData, signature));
    
    writeln("\x1b[32m  ✓ Basic signing and verification works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.integrity - Consistent signatures for same data");
    
    auto validator = IntegrityValidator.create();
    ubyte[] data = cast(ubyte[])"Consistent data";
    
    auto sig1 = validator.sign(data);
    auto sig2 = validator.sign(data);
    
    // Same data should produce same signature
    Assert.equal(sig1[], sig2[]);
    
    writeln("\x1b[32m  ✓ Signatures are consistent for same data\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.integrity - Different keys produce different signatures");
    
    ubyte[32] key1;
    ubyte[32] key2;
    key1[] = 1;
    key2[] = 2;
    
    auto validator1 = IntegrityValidator.withKey(key1);
    auto validator2 = IntegrityValidator.withKey(key2);
    
    ubyte[] data = cast(ubyte[])"Test data";
    
    auto sig1 = validator1.sign(data);
    auto sig2 = validator2.sign(data);
    
    // Different keys should produce different signatures
    Assert.notEqual(sig1[], sig2[]);
    
    // Cross-validation should fail
    Assert.isFalse(validator1.verify(data, sig2));
    Assert.isFalse(validator2.verify(data, sig1));
    
    writeln("\x1b[32m  ✓ Different keys produce different signatures\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.integrity - Empty data handling");
    
    auto validator = IntegrityValidator.create();
    ubyte[] emptyData = [];
    
    auto signature = validator.sign(emptyData);
    Assert.isTrue(validator.verify(emptyData, signature));
    
    // Empty data signature should differ from non-empty
    ubyte[] nonEmptyData = cast(ubyte[])"x";
    auto nonEmptySig = validator.sign(nonEmptyData);
    Assert.notEqual(signature[], nonEmptySig[]);
    
    writeln("\x1b[32m  ✓ Empty data is handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.integrity - Large data handling");
    
    auto validator = IntegrityValidator.create();
    
    // Create 1MB of data
    ubyte[] largeData = new ubyte[1024 * 1024];
    foreach (i, ref b; largeData)
        b = cast(ubyte)(i % 256);
    
    auto signature = validator.sign(largeData);
    Assert.isTrue(validator.verify(largeData, signature));
    
    // Modify one byte
    largeData[512 * 1024] = cast(ubyte)(largeData[512 * 1024] + 1);
    Assert.isFalse(validator.verify(largeData, signature));
    
    writeln("\x1b[32m  ✓ Large data is handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.integrity - Signature with metadata");
    
    auto validator = IntegrityValidator.create();
    ubyte[] data = cast(ubyte[])"Test data with metadata";
    
    auto signed = validator.signWithMetadata(data, 1);
    
    // Verify the signed data
    Assert.isTrue(validator.verifyMetadata(signed));
    Assert.equal(signed.version_, 1);
    Assert.equal(signed.data, data);
    
    // Tamper with data
    signed.data[0] = cast(ubyte)(signed.data[0] + 1);
    Assert.isFalse(validator.verifyMetadata(signed));
    
    writeln("\x1b[32m  ✓ Metadata signing and verification works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.integrity - Signature tampering detection");
    
    auto validator = IntegrityValidator.create();
    ubyte[] data = cast(ubyte[])"Important data";
    
    auto signature = validator.sign(data);
    
    // Tamper with signature
    signature[0] = cast(ubyte)(signature[0] + 1);
    
    // Verification should fail
    Assert.isFalse(validator.verify(data, signature));
    
    writeln("\x1b[32m  ✓ Signature tampering is detected\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.integrity - Environment-specific validator");
    
    auto validator1 = IntegrityValidator.fromEnvironment("workspace1");
    auto validator2 = IntegrityValidator.fromEnvironment("workspace2");
    
    ubyte[] data = cast(ubyte[])"Test data";
    
    auto sig1 = validator1.sign(data);
    auto sig2 = validator2.sign(data);
    
    // Different workspaces should produce different signatures
    Assert.notEqual(sig1[], sig2[]);
    
    writeln("\x1b[32m  ✓ Environment-specific validators work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.integrity - Signature bit flips are detected");
    
    auto validator = IntegrityValidator.create();
    ubyte[] data = cast(ubyte[])"Critical data";
    
    auto signature = validator.sign(data);
    
    // Flip each bit in signature and verify all are detected
    foreach (byteIndex; 0 .. signature.length)
    {
        foreach (bitIndex; 0 .. 8)
        {
            auto tamperedSig = signature.dup;
            tamperedSig[byteIndex] ^= (1 << bitIndex);
            Assert.isFalse(validator.verify(data, tamperedSig));
        }
    }
    
    writeln("\x1b[32m  ✓ All signature bit flips are detected\x1b[0m");
}

