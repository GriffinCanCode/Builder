module core.distributed.protocol.transport;

import std.socket;
import std.datetime : Duration, seconds;
import std.conv : to;
import std.string : split, strip;
import std.algorithm.searching : startsWith;
import core.distributed.protocol.protocol;
import core.distributed.protocol.protocol : NetworkError;
import errors : BuildError, Result, Ok, Err;

/// Transport layer interface (pluggable implementation)
interface Transport
{
    /// Send message to recipient
    Result!DistributedError send(T)(WorkerId recipient, T message);
    
    /// Receive message (blocking with timeout)
    Result!(Envelope!T, DistributedError) receive(T)(Duration timeout);
    
    /// Check if transport is connected
    bool isConnected();
    
    /// Close transport
    void close();
}

/// Simple HTTP transport (baseline implementation)
/// Production would use gRPC or similar
final class HttpTransport : Transport
{
    private Socket socket;
    private string host;
    private ushort port;
    private Duration timeout;
    
    this(string host, ushort port, Duration timeout = 30.seconds) @trusted
    {
        this.host = host;
        this.port = port;
        this.timeout = timeout;
    }
    
    /// Connect to remote endpoint
    Result!DistributedError connect() @trusted
    {
        try
        {
            auto addr = new InternetAddress(host, port);
            socket = new TcpSocket();
            socket.connect(addr);
            socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, timeout);
            socket.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, timeout);
            return Ok!DistributedError();
        }
        catch (Exception e)
        {
            DistributedError err = new NetworkError("Failed to connect: " ~ e.msg);
            return Result!DistributedError.err(err);
        }
    }
    
    /// Send message
    Result!DistributedError send(T)(WorkerId recipient, T message) @trusted
    {
        if (!isConnected())
        {
            auto connectResult = connect();
            if (connectResult.isErr)
                return connectResult;
        }
        
        try
        {
            // Create envelope
            auto envelope = Envelope!T(WorkerId(0), recipient, message);
            
            // Serialize (simplified - would use proper serialization)
            auto data = serializeMessage(envelope);
            
            // Send with length prefix
            ubyte[4] lengthBytes;
            *cast(uint*)lengthBytes.ptr = cast(uint)data.length;
            socket.send(lengthBytes);
            socket.send(data);
            
            return Ok!DistributedError();
        }
        catch (Exception e)
        {
            return Err!DistributedError(
                new NetworkError("Failed to send: " ~ e.msg));
        }
    }
    
    /// Receive message
    Result!(Envelope!T, DistributedError) receive(T)(Duration timeout) @trusted
    {
        if (!isConnected())
            return Err!(Envelope!T, DistributedError)(
                new NetworkError("Not connected"));
        
        try
        {
            // Receive length prefix
            ubyte[4] lengthBytes;
            auto received = socket.receive(lengthBytes);
            if (received != 4)
                return Err!(Envelope!T, DistributedError)(
                    new NetworkError("Failed to receive length"));
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            
            // Receive message data
            auto data = new ubyte[length];
            received = socket.receive(data);
            if (received != length)
                return Err!(Envelope!T, DistributedError)(
                    new NetworkError("Failed to receive message"));
            
            // Deserialize
            return deserializeMessage!T(data);
        }
        catch (Exception e)
        {
            return Err!(Envelope!T, DistributedError)(
                new NetworkError("Failed to receive: " ~ e.msg));
        }
    }
    
    /// Check if connected
    bool isConnected() @trusted
    {
        return socket !is null && socket.isAlive;
    }
    
    /// Close connection
    void close() @trusted
    {
        if (socket !is null)
        {
            try
            {
                socket.shutdown(SocketShutdown.BOTH);
                socket.close();
            }
            catch (Exception) {}
            socket = null;
        }
    }
    
    /// Binary serialization (efficient, no external dependencies)
    ubyte[] serializeMessage(T)(Envelope!T envelope) @trusted
    {
        import std.bitmanip : write;
        
        ubyte[] buffer;
        buffer.reserve(4096);
        
        // Protocol version
        buffer.write!ubyte(envelope.version_, buffer.length);
        
        // Message ID
        buffer.write!ulong(envelope.id.value, buffer.length);
        
        // Sender/Recipient
        buffer.write!ulong(envelope.sender.value, buffer.length);
        buffer.write!ulong(envelope.recipient.value, buffer.length);
        
        // Timestamp (stdTime)
        buffer.write!long(envelope.timestamp.stdTime, buffer.length);
        
        // Compression
        buffer.write!ubyte(envelope.compression, buffer.length);
        
        // Payload type tag
        static if (is(T == ActionRequest))
        {
            buffer.write!ubyte(1, buffer.length);
            buffer ~= envelope.payload.serialize();
        }
        else static if (is(T == ActionResult))
        {
            buffer.write!ubyte(2, buffer.length);
            buffer ~= serializeActionResult(envelope.payload);
        }
        else static if (is(T == HeartBeat))
        {
            buffer.write!ubyte(3, buffer.length);
            buffer ~= serializeHeartBeat(envelope.payload);
        }
        else static if (is(T == StealRequest))
        {
            buffer.write!ubyte(4, buffer.length);
            buffer ~= serializeStealRequest(envelope.payload);
        }
        else static if (is(T == StealResponse))
        {
            buffer.write!ubyte(5, buffer.length);
            buffer ~= serializeStealResponse(envelope.payload);
        }
        else static if (is(T == Shutdown))
        {
            buffer.write!ubyte(6, buffer.length);
            buffer ~= serializeShutdown(envelope.payload);
        }
        else
            static assert(0, "Unsupported message type: " ~ T.stringof);
        
        return buffer;
    }
    
    /// Binary deserialization
    Result!(Envelope!T, DistributedError) deserializeMessage(T)(ubyte[] data) @system
    {
        import std.bitmanip : read;
        import std.datetime : SysTime;
        
        if (data.length < 30)
            return Err!(Envelope!T, DistributedError)(
                new NetworkError("Message too short"));
        
        try
        {
            ubyte[] mutableData = data.dup;
            size_t offset = 0;
            
            Envelope!T envelope;
            
            // Protocol version
            auto versionSlice = mutableData[offset .. offset + 1];
            envelope.version_ = cast(ProtocolVersion)versionSlice.read!ubyte();
            offset += 1;
            
            // Message ID
            auto idSlice = mutableData[offset .. offset + 8];
            envelope.id = MessageId(idSlice.read!ulong());
            offset += 8;
            
            // Sender/Recipient
            auto senderSlice = mutableData[offset .. offset + 8];
            envelope.sender = WorkerId(senderSlice.read!ulong());
            offset += 8;
            
            auto recipSlice = mutableData[offset .. offset + 8];
            envelope.recipient = WorkerId(recipSlice.read!ulong());
            offset += 8;
            
            // Timestamp
            auto timeSlice = mutableData[offset .. offset + 8];
            envelope.timestamp = SysTime(timeSlice.read!long());
            offset += 8;
            
            // Compression
            auto compSlice = mutableData[offset .. offset + 1];
            envelope.compression = cast(Compression)compSlice.read!ubyte();
            offset += 1;
            
            // Payload type (verify match)
            auto typeSlice = mutableData[offset .. offset + 1];
            immutable payloadType = typeSlice.read!ubyte();
            offset += 1;
            
            auto payloadData = data[offset .. $];
            
            static if (is(T == ActionRequest))
            {
                if (payloadType != 1)
                    return Err!(Envelope!T, DistributedError)(
                        new NetworkError("Type mismatch: expected ActionRequest"));
                // ActionRequest deserialization is complex, return error for now
                return Err!(Envelope!T, DistributedError)(
                    new NetworkError("ActionRequest deserialization not yet implemented"));
            }
            else static if (is(T == ActionResult))
            {
                if (payloadType != 2)
                    return Err!(Envelope!T, DistributedError)(
                        new NetworkError("Type mismatch: expected ActionResult"));
                auto result = deserializeActionResult(payloadData);
                if (result.isErr)
                    return Err!(Envelope!T, DistributedError)(result.unwrapErr());
                envelope.payload = result.unwrap();
            }
            else static if (is(T == HeartBeat))
            {
                if (payloadType != 3)
                    return Err!(Envelope!T, DistributedError)(
                        new NetworkError("Type mismatch: expected HeartBeat"));
                auto result = deserializeHeartBeat(payloadData);
                if (result.isErr)
                    return Err!(Envelope!T, DistributedError)(result.unwrapErr());
                envelope.payload = result.unwrap();
            }
            else
                static assert(0, "Unsupported message type: " ~ T.stringof);
            
            return Ok!(Envelope!T, DistributedError)(envelope);
        }
        catch (Exception e)
        {
            return Err!(Envelope!T, DistributedError)(
                new NetworkError("Deserialization failed: " ~ e.msg));
        }
    }
    
    /// Serialize ActionResult
    private ubyte[] serializeActionResult(ActionResult result) @trusted
    {
        import std.bitmanip : write;
        
        ubyte[] buffer;
        buffer.reserve(1024);
        
        buffer ~= result.id.hash;
        buffer.write!ubyte(result.status, buffer.length);
        buffer.write!long(result.duration.total!"msecs", buffer.length);
        
        // Outputs array
        buffer.write!uint(cast(uint)result.outputs.length, buffer.length);
        foreach (output; result.outputs)
            buffer ~= output.hash;
        
        // Stdout (length-prefixed)
        buffer.write!uint(cast(uint)result.stdout.length, buffer.length);
        buffer ~= cast(ubyte[])result.stdout;
        
        // Stderr (length-prefixed)
        buffer.write!uint(cast(uint)result.stderr.length, buffer.length);
        buffer ~= cast(ubyte[])result.stderr;
        
        buffer.write!int(result.exitCode, buffer.length);
        
        // Resource usage (simplified)
        buffer.write!long(result.resources.cpuTime.total!"msecs", buffer.length);
        buffer.write!ulong(result.resources.peakMemory, buffer.length);
        
        return buffer;
    }
    
    /// Deserialize ActionResult
    private Result!(ActionResult, DistributedError) deserializeActionResult(const ubyte[] data) @system
    {
        import std.bitmanip : read;
        import std.datetime : msecs;
        
        if (data.length < 32)
            return Err!(ActionResult, DistributedError)(
                new NetworkError("ActionResult data too short"));
        
        try
        {
            ubyte[] mutableData = cast(ubyte[])data.dup;
            size_t offset = 0;
            
            ActionResult result;
            
            // Action ID
            result.id = ActionId(data[offset .. offset + 32]);
            offset += 32;
            
            // Status
            auto statusSlice = mutableData[offset .. offset + 1];
            result.status = cast(ResultStatus)statusSlice.read!ubyte();
            offset += 1;
            
            // Duration
            auto durSlice = mutableData[offset .. offset + 8];
            result.duration = durSlice.read!long().msecs;
            offset += 8;
            
            // Outputs
            auto outCountSlice = mutableData[offset .. offset + 4];
            immutable outCount = outCountSlice.read!uint();
            offset += 4;
            result.outputs.reserve(outCount);
            foreach (_; 0 .. outCount)
            {
                result.outputs ~= ArtifactId(data[offset .. offset + 32]);
                offset += 32;
            }
            
            // Stdout
            auto stdoutLenSlice = mutableData[offset .. offset + 4];
            immutable stdoutLen = stdoutLenSlice.read!uint();
            offset += 4;
            result.stdout = cast(string)data[offset .. offset + stdoutLen];
            offset += stdoutLen;
            
            // Stderr
            auto stderrLenSlice = mutableData[offset .. offset + 4];
            immutable stderrLen = stderrLenSlice.read!uint();
            offset += 4;
            result.stderr = cast(string)data[offset .. offset + stderrLen];
            offset += stderrLen;
            
            // Exit code
            auto exitSlice = mutableData[offset .. offset + 4];
            result.exitCode = exitSlice.read!int();
            offset += 4;
            
            // Resource usage
            auto cpuSlice = mutableData[offset .. offset + 8];
            result.resources.cpuTime = cpuSlice.read!long().msecs;
            offset += 8;
            
            auto memSlice = mutableData[offset .. offset + 8];
            result.resources.peakMemory = memSlice.read!ulong();
            
            return Ok!(ActionResult, DistributedError)(result);
        }
        catch (Exception e)
        {
            return Err!(ActionResult, DistributedError)(
                new NetworkError("Failed to deserialize ActionResult: " ~ e.msg));
        }
    }
    
    /// Serialize HeartBeat
    private ubyte[] serializeHeartBeat(HeartBeat hb) @trusted
    {
        import std.bitmanip : write;
        
        ubyte[] buffer;
        buffer.write!ulong(hb.worker.value, buffer.length);
        buffer.write!ubyte(hb.state, buffer.length);
        buffer.write!float(hb.metrics.cpuUsage, buffer.length);
        buffer.write!float(hb.metrics.memoryUsage, buffer.length);
        buffer.write!float(hb.metrics.diskUsage, buffer.length);
        buffer.write!ulong(hb.metrics.queueDepth, buffer.length);
        buffer.write!ulong(hb.metrics.activeActions, buffer.length);
        buffer.write!long(hb.timestamp.stdTime, buffer.length);
        
        return buffer;
    }
    
    /// Deserialize HeartBeat
    private Result!(HeartBeat, DistributedError) deserializeHeartBeat(const ubyte[] data) @system
    {
        import std.bitmanip : read;
        import std.datetime : SysTime;
        
        if (data.length < 41)
            return Err!(HeartBeat, DistributedError)(
                new NetworkError("HeartBeat data too short"));
        
        try
        {
            ubyte[] mutableData = cast(ubyte[])data.dup;
            
            HeartBeat hb;
            
            auto workerSlice = mutableData[0 .. 8];
            hb.worker = WorkerId(workerSlice.read!ulong());
            
            auto stateSlice = mutableData[8 .. 9];
            hb.state = cast(WorkerState)stateSlice.read!ubyte();
            
            auto cpuSlice = mutableData[9 .. 13];
            hb.metrics.cpuUsage = cpuSlice.read!float();
            
            auto memSlice = mutableData[13 .. 17];
            hb.metrics.memoryUsage = memSlice.read!float();
            
            auto diskSlice = mutableData[17 .. 21];
            hb.metrics.diskUsage = diskSlice.read!float();
            
            auto queueSlice = mutableData[21 .. 29];
            hb.metrics.queueDepth = queueSlice.read!ulong();
            
            auto activeSlice = mutableData[29 .. 37];
            hb.metrics.activeActions = activeSlice.read!ulong();
            
            auto timeSlice = mutableData[37 .. 45];
            hb.timestamp = SysTime(timeSlice.read!long());
            
            return Ok!(HeartBeat, DistributedError)(hb);
        }
        catch (Exception e)
        {
            return Err!(HeartBeat, DistributedError)(
                new NetworkError("Failed to deserialize HeartBeat: " ~ e.msg));
        }
    }
    
    /// Serialize StealRequest
    private ubyte[] serializeStealRequest(StealRequest req) @trusted
    {
        import std.bitmanip : write;
        
        ubyte[] buffer;
        buffer.write!ulong(req.thief.value, buffer.length);
        buffer.write!ulong(req.victim.value, buffer.length);
        buffer.write!ubyte(req.minPriority, buffer.length);
        
        return buffer;
    }
    
    /// Serialize StealResponse
    private ubyte[] serializeStealResponse(StealResponse resp) @trusted
    {
        import std.bitmanip : write;
        
        ubyte[] buffer;
        buffer.write!ulong(resp.victim.value, buffer.length);
        buffer.write!ulong(resp.thief.value, buffer.length);
        buffer.write!ubyte(resp.hasWork ? 1 : 0, buffer.length);
        
        if (resp.hasWork)
            buffer ~= resp.action.serialize();
        
        return buffer;
    }
    
    /// Serialize Shutdown
    private ubyte[] serializeShutdown(Shutdown cmd) @trusted
    {
        import std.bitmanip : write;
        
        ubyte[] buffer;
        buffer.write!ubyte(cmd.graceful ? 1 : 0, buffer.length);
        buffer.write!long(cmd.timeout.total!"msecs", buffer.length);
        
        return buffer;
    }
}

/// Transport factory
final class TransportFactory
{
    /// Create transport from URL
    static Result!(Transport, DistributedError) create(string url) @system
    {
        // Parse URL (simplified)
        if (url.startsWith("http://"))
        {
            auto parts = url[7 .. $].split(":");
            if (parts.length != 2)
                return Err!(Transport, DistributedError)(
                    new DistributedError("Invalid URL format"));
            
            immutable host = parts[0];
            immutable port = parts[1].to!ushort;
            
            auto transport = new HttpTransport(host, port);
            auto connectResult = transport.connect();
            
            if (connectResult.isErr)
                return Err!(Transport, DistributedError)(connectResult.unwrapErr());
            
            return Ok!(Transport, DistributedError)(cast(Transport)transport);
        }
        else
        {
            return Err!(Transport, DistributedError)(
                new DistributedError("Unsupported transport protocol"));
        }
    }
}



