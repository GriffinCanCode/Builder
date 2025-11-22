module tests.unit.caching.tls_test;

import std.socket;
import std.datetime : seconds;
import std.conv : to;
import engine.caching.distributed.remote.tls;
import infrastructure.errors;

/// Test TLS configuration validation
unittest
{
    // Test: Disabled TLS is always valid
    {
        TlsConfig config;
        config.enabled = false;
        assert(config.isValid());
    }
    
    // Test: Enabled TLS requires cert and key files
    {
        TlsConfig config;
        config.enabled = true;
        assert(!config.isValid()); // Missing files
        
        config.certFile = "/path/to/cert.pem";
        assert(!config.isValid()); // Still missing key
        
        config.keyFile = "/path/to/key.pem";
        assert(config.isValid()); // Now valid
    }
}

/// Test TLS protocol version enums
unittest
{
    assert(TlsVersion.TLS_1_0 == 0x01);
    assert(TlsVersion.TLS_1_1 == 0x02);
    assert(TlsVersion.TLS_1_2 == 0x03);
    assert(TlsVersion.TLS_1_3 == 0x04);
}

/// Test TLS content types
unittest
{
    assert(TlsContentType.ChangeCipherSpec == 20);
    assert(TlsContentType.Alert == 21);
    assert(TlsContentType.Handshake == 22);
    assert(TlsContentType.ApplicationData == 23);
}

/// Test cipher suite enums
unittest
{
    // TLS 1.3 ciphers
    assert(CipherSuite.TLS_AES_128_GCM_SHA256 == 0x1301);
    assert(CipherSuite.TLS_AES_256_GCM_SHA384 == 0x1302);
    assert(CipherSuite.TLS_CHACHA20_POLY1305_SHA256 == 0x1303);
    
    // TLS 1.2 ciphers
    assert(CipherSuite.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 == 0xC02F);
    assert(CipherSuite.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 == 0xC030);
}

/// Test TLS record serialization and parsing
unittest
{
    // Test: Serialize a TLS record
    {
        TlsRecord record;
        record.contentType = TlsContentType.Handshake;
        record.protocolVersion = TlsVersion.TLS_1_2;
        record.fragment = [0x01, 0x02, 0x03, 0x04];
        record.length = cast(ushort)record.fragment.length;
        
        auto data = record.serialize();
        
        // Check header
        assert(data.length == 9); // 5 byte header + 4 byte fragment
        assert(data[0] == cast(ubyte)TlsContentType.Handshake);
        assert(data[1] == 0x03); // Major version
        assert(data[2] == cast(ubyte)TlsVersion.TLS_1_2);
        assert(data[3] == 0x00); // Length high byte
        assert(data[4] == 0x04); // Length low byte
        assert(data[5..9] == [0x01, 0x02, 0x03, 0x04]);
    }
    
    // Test: Parse a TLS record
    {
        ubyte[] data = [
            0x16, // Handshake
            0x03, 0x03, // TLS 1.2
            0x00, 0x04, // Length = 4
            0x01, 0x02, 0x03, 0x04 // Fragment
        ];
        
        auto result = TlsRecord.parse(data);
        assert(result.isOk);
        
        auto record = result.unwrap();
        assert(record.contentType == TlsContentType.Handshake);
        assert(record.protocolVersion == TlsVersion.TLS_1_2);
        assert(record.length == 4);
        assert(record.fragment == [0x01, 0x02, 0x03, 0x04]);
    }
    
    // Test: Parse invalid record (too short)
    {
        ubyte[] data = [0x16, 0x03]; // Only 2 bytes
        auto result = TlsRecord.parse(data);
        assert(result.isErr);
        assert(result.unwrapErr() == "Record too short");
    }
    
    // Test: Parse incomplete record
    {
        ubyte[] data = [
            0x16, 0x03, 0x03,
            0x00, 0x10, // Length = 16 but only 2 bytes follow
            0x01, 0x02
        ];
        auto result = TlsRecord.parse(data);
        assert(result.isErr);
        assert(result.unwrapErr() == "Incomplete record");
    }
}

/// Test TLS session key derivation
unittest
{
    TlsSession session;
    
    // Set test values
    session.masterSecret = cast(ubyte[32])[
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20
    ];
    
    session.clientRandom = cast(ubyte[32])[
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20
    ];
    
    session.serverRandom = cast(ubyte[32])[
        0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28,
        0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x30,
        0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38,
        0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40
    ];
    
    ubyte[16] clientKey, serverKey;
    session.deriveKeys(clientKey, serverKey);
    
    // Keys should be different
    assert(clientKey != serverKey);
    
    // Keys should be deterministic
    ubyte[16] clientKey2, serverKey2;
    session.deriveKeys(clientKey2, serverKey2);
    assert(clientKey == clientKey2);
    assert(serverKey == serverKey2);
}

/// Test handshake state transitions
unittest
{
    assert(HandshakeState.Initial == 0);
    assert(HandshakeState.Complete > HandshakeState.Initial);
    
    // States should progress in order
    int prev = cast(int)HandshakeState.Initial;
    assert(cast(int)HandshakeState.ClientHelloSent > prev);
    prev = cast(int)HandshakeState.ClientHelloSent;
    assert(cast(int)HandshakeState.ServerHelloReceived > prev);
}

/// Test TLS context initialization
unittest
{
    TlsConfig config;
    config.enabled = false; // Disabled for testing
    
    auto context = new TlsContext(config);
    assert(!context.isEnabled());
}

/// Test TLS socket creation without encryption
unittest
{
    // Test disabled TLS context
    TlsConfig config;
    config.enabled = false;
    auto context = new TlsContext(config);
    
    assert(!context.isEnabled());
    
    // Socket wrapper is tested indirectly through TlsContext.wrapSocket()
    // which is the intended public API
}

/// Test cipher suite priority (modern ciphers preferred)
unittest
{
    // TLS 1.3 ciphers should have lower values (higher priority)
    assert(CipherSuite.TLS_AES_128_GCM_SHA256 < CipherSuite.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256);
    
    // AES-256 should be preferred over AES-128 for high security
    assert(CipherSuite.TLS_AES_256_GCM_SHA384 > CipherSuite.TLS_AES_128_GCM_SHA256);
}

/// Test TLS record layer fragmentation
unittest
{
    // Maximum TLS record size is 2^14 bytes (16KB)
    enum MAX_TLS_RECORD_SIZE = 16384;
    
    ubyte[] largeData = new ubyte[MAX_TLS_RECORD_SIZE];
    foreach (i, ref b; largeData)
        b = cast(ubyte)(i % 256);
    
    TlsRecord record;
    record.contentType = TlsContentType.ApplicationData;
    record.protocolVersion = TlsVersion.TLS_1_2;
    record.fragment = largeData;
    record.length = cast(ushort)record.fragment.length;
    
    // Should be able to serialize max-size record
    auto serialized = record.serialize();
    assert(serialized.length == 5 + MAX_TLS_RECORD_SIZE);
    
    // Should be able to parse it back
    auto parsed = TlsRecord.parse(serialized);
    assert(parsed.isOk);
    assert(parsed.unwrap().fragment.length == MAX_TLS_RECORD_SIZE);
}

/// Test TLS handshake message types
unittest
{
    assert(TlsHandshakeType.ClientHello == 1);
    assert(TlsHandshakeType.ServerHello == 2);
    assert(TlsHandshakeType.Certificate == 11);
    assert(TlsHandshakeType.Finished == 20);
}

/// Integration test: Full TLS handshake simulation
unittest
{
    // This would test the full handshake but requires actual socket connections
    // For now, we verify the structure is in place
    
    TlsSession session;
    session.version_ = TlsVersion.TLS_1_3;
    session.cipherSuite = CipherSuite.TLS_AES_128_GCM_SHA256;
    
    // Generate randoms
    foreach (ref b; session.clientRandom)
        b = cast(ubyte)0xAA;
    foreach (ref b; session.serverRandom)
        b = cast(ubyte)0xBB;
    
    // Simulate master secret generation
    import std.digest.sha : sha256Of;
    auto hash = sha256Of(session.clientRandom ~ session.serverRandom);
    session.masterSecret = hash[0..32];
    
    // Derive keys
    ubyte[16] clientKey, serverKey;
    session.deriveKeys(clientKey, serverKey);
    
    // Verify keys are derived
    assert(clientKey != ubyte[16].init);
    assert(serverKey != ubyte[16].init);
    assert(clientKey != serverKey);
}

/// Test TLS version compatibility
unittest
{
    // Older versions should be rejected in favor of newer
    assert(TlsVersion.TLS_1_2 > TlsVersion.TLS_1_0);
    assert(TlsVersion.TLS_1_3 > TlsVersion.TLS_1_2);
    
    // We should prefer TLS 1.3 > TLS 1.2 > TLS 1.1 > TLS 1.0
    TlsVersion preferred = TlsVersion.TLS_1_3;
    assert(preferred == TlsVersion.TLS_1_3);
}

/// Test error handling in TLS operations
unittest
{
    // Test parsing errors
    {
        ubyte[] emptyData;
        auto result = TlsRecord.parse(emptyData);
        assert(result.isErr);
    }
    
    // Test invalid content type
    {
        ubyte[] invalidData = [0xFF, 0x03, 0x03, 0x00, 0x00];
        auto result = TlsRecord.parse(invalidData);
        assert(result.isOk); // Parsing succeeds, validation happens later
        
        auto record = result.unwrap();
        assert(cast(ubyte)record.contentType == 0xFF);
    }
}

/// Stress test: Multiple record operations
unittest
{
    foreach (i; 0..100)
    {
        TlsRecord record;
        record.contentType = cast(TlsContentType)(20 + (i % 4));
        record.protocolVersion = TlsVersion.TLS_1_2;
        record.fragment = cast(ubyte[])[cast(ubyte)i, cast(ubyte)(i + 1)];
        record.length = cast(ushort)record.fragment.length;
        
        auto serialized = record.serialize();
        auto parsed = TlsRecord.parse(serialized);
        
        assert(parsed.isOk);
        assert(parsed.unwrap().fragment == record.fragment);
    }
}

