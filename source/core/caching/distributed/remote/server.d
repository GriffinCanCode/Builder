module core.caching.distributed.remote.server;

import std.socket;
import std.stdio : writeln, writefln;
import std.conv : to, text;
import std.string : split, strip, startsWith, indexOf, format, toLower;
import std.algorithm : canFind;
import std.datetime : Clock, SysTime;
import std.file : exists, read, write, remove, mkdirRecurse, dirEntries, SpanMode, DirEntry;
import std.path : buildPath, baseName;
import std.array : Appender;
import std.uri : decode;
import core.thread : Thread;
import core.sync.mutex;
import core.caching.distributed.remote.protocol;
import utils.files.hash : FastHash;
import utils.security.integrity : IntegrityValidator;
import errors;

/// Simple HTTP cache server
/// Implements minimal HTTP/1.1 server for artifact storage
/// Content-addressable storage with LRU eviction
final class CacheServer
{
    private string storageDir;
    private string host;
    private ushort port;
    private string authToken;
    private size_t maxStorageSize;
    private Socket listener;
    private bool running;
    private Mutex storageMutex;
    private RemoteCacheStats stats;
    
    /// Constructor
    this(
        string host = "0.0.0.0",
        ushort port = 8080,
        string storageDir = ".cache-storage",
        string authToken = "",
        size_t maxStorageSize = 10_000_000_000  // 10 GB default
    ) @trusted
    {
        this.host = host;
        this.port = port;
        this.storageDir = storageDir;
        this.authToken = authToken;
        this.maxStorageSize = maxStorageSize;
        this.storageMutex = new Mutex();
        
        // Ensure storage directory exists
        if (!exists(storageDir))
            mkdirRecurse(storageDir);
    }
    
    /// Start the cache server
    void start() @trusted
    {
        listener = new TcpSocket();
        listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        listener.bind(new InternetAddress(host, port));
        listener.listen(128);
        
        running = true;
        
        writefln("Cache server listening on %s:%d", host, port);
        writefln("Storage directory: %s", storageDir);
        writefln("Max storage size: %.2f GB", maxStorageSize / 1_000_000_000.0);
        
        while (running)
        {
            try
            {
                auto client = listener.accept();
                
                // Handle in new thread for concurrency
                auto thread = new Thread(() => handleClient(client));
                thread.start();
            }
            catch (Exception e)
            {
                if (running)
                    writeln("Error accepting connection: ", e.msg);
            }
        }
    }
    
    /// Stop the cache server
    void stop() @trusted
    {
        running = false;
        if (listener !is null)
        {
            try
            {
                listener.shutdown(SocketShutdown.BOTH);
                listener.close();
            }
            catch (Exception) {}
        }
    }
    
    /// Get cache statistics
    RemoteCacheStats getStats() @trusted
    {
        synchronized (storageMutex)
        {
            return stats;
        }
    }
    
    private void cleanupClient(Socket client) nothrow
    {
        try { client.shutdown(SocketShutdown.BOTH); } catch (Exception) {}
        try { client.close(); } catch (Exception) {}
    }
    
    private void handleClient(Socket client) @trusted
    {
        import core.time : seconds;
        
        scope(exit)
        {
            // Clean up client connection
            cleanupClient(client);
        }
        
        try
        {
            // Read request with timeout
            client.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, 30.seconds);
            
            auto requestResult = receiveHttpRequest(client);
            if (requestResult.isErr)
            {
                sendErrorResponse(client, 400, "Bad Request");
                return;
            }
            
            auto request = requestResult.unwrap();
            
            // Check authentication
            if (authToken.length > 0)
            {
                immutable authHeader = request.headers.get("Authorization", "");
                if (!authHeader.startsWith("Bearer " ~ authToken))
                {
                    sendErrorResponse(client, 401, "Unauthorized");
                    return;
                }
            }
            
            // Route request
            if (request.method == "GET")
                handleGet(client, request);
            else if (request.method == "PUT")
                handlePut(client, request);
            else if (request.method == "HEAD")
                handleHead(client, request);
            else if (request.method == "DELETE")
                handleDelete(client, request);
            else
                sendErrorResponse(client, 405, "Method Not Allowed");
        }
        catch (Exception e)
        {
            try
            {
                sendErrorResponse(client, 500, "Internal Server Error");
            }
            catch (Exception) {}
        }
    }
    
    private struct HttpRequest
    {
        string method;
        string path;
        string[string] headers;
        ubyte[] body_;
    }
    
    private Result!(HttpRequest, BuildError) receiveHttpRequest(Socket client) @trusted
    {
        HttpRequest request;
        ubyte[] buffer = new ubyte[8192];
        Appender!(ubyte[]) received;
        
        try
        {
            // Read headers
            bool headersComplete = false;
            ptrdiff_t headerEnd = -1;
            
            while (!headersComplete)
            {
                immutable bytesRead = client.receive(buffer);
                if (bytesRead <= 0)
                    break;
                
                received ~= buffer[0 .. bytesRead];
                
                // Check for header end
                foreach (i; 0 .. received.data.length - 3)
                {
                    if (received.data[i .. i + 4] == cast(ubyte[])"\r\n\r\n")
                    {
                        headersComplete = true;
                        headerEnd = i + 4;
                        break;
                    }
                }
                
                // Prevent header overflow
                if (received.data.length > 1_000_000)
                {
                    auto error = new NetworkError(
                        "Request headers too large",
                        ErrorCode.NetworkError
                    );
                    return Err!(HttpRequest, BuildError)(error);
                }
            }
            
            if (headerEnd < 0)
            {
                auto error = new NetworkError(
                    "Invalid HTTP request",
                    ErrorCode.NetworkError
                );
                return Err!(HttpRequest, BuildError)(error);
            }
            
            // Parse request line and headers
            immutable headerSection = cast(string)received.data[0 .. headerEnd];
            auto lines = headerSection.split("\r\n");
            
            if (lines.length == 0)
            {
                auto error = new NetworkError(
                    "Empty HTTP request",
                    ErrorCode.NetworkError
                );
                return Err!(HttpRequest, BuildError)(error);
            }
            
            // Parse request line
            auto requestParts = lines[0].split(" ");
            if (requestParts.length < 3)
            {
                auto error = new NetworkError(
                    "Invalid request line",
                    ErrorCode.NetworkError
                );
                return Err!(HttpRequest, BuildError)(error);
            }
            
            request.method = requestParts[0];
            request.path = requestParts[1];
            
            // Parse headers
            foreach (line; lines[1 .. $])
            {
                immutable colonIdx = line.indexOf(':');
                if (colonIdx > 0)
                {
                    immutable key = line[0 .. colonIdx].strip();
                    immutable value = line[colonIdx + 1 .. $].strip();
                    request.headers[key] = value;
                }
            }
            
            // Read body if present
            immutable contentLengthStr = request.headers.get("Content-Length", "0");
            size_t contentLength;
            try
            {
                contentLength = contentLengthStr.to!size_t;
            }
            catch (Exception)
            {
                contentLength = 0;
            }
            
            // Extract body from received data
            if (headerEnd < received.data.length)
                request.body_ ~= received.data[headerEnd .. $];
            
            // Read remaining body
            while (request.body_.length < contentLength)
            {
                immutable remaining = contentLength - request.body_.length;
                immutable toRead = remaining < buffer.length ? remaining : buffer.length;
                immutable bytesRead = client.receive(buffer[0 .. toRead]);
                
                if (bytesRead <= 0)
                    break;
                
                request.body_ ~= buffer[0 .. bytesRead];
            }
            
            return Ok!(HttpRequest, BuildError)(request);
        }
        catch (Exception e)
        {
            auto error = new NetworkError(
                "Failed to receive request: " ~ e.msg,
                ErrorCode.NetworkError
            );
            return Err!(HttpRequest, BuildError)(error);
        }
    }
    
    private void handleGet(Socket client, ref HttpRequest request) @trusted
    {
        // Parse path: /artifacts/{hash}
        if (!request.path.startsWith("/artifacts/"))
        {
            sendErrorResponse(client, 404, "Not Found");
            return;
        }
        
        immutable hash = decode(request.path[11 .. $]);
        immutable artifactPath = buildPath(storageDir, hash);
        
        synchronized (storageMutex)
        {
            stats.getRequests++;
        }
        
        if (!exists(artifactPath))
        {
            synchronized (storageMutex)
            {
                stats.misses++;
                stats.compute();
            }
            sendErrorResponse(client, 404, "Not Found");
            return;
        }
        
        try
        {
            auto data = cast(ubyte[])read(artifactPath);
            
            synchronized (storageMutex)
            {
                stats.hits++;
                stats.bytesDownloaded += data.length;
                stats.compute();
            }
            
            sendResponse(client, 200, "OK", data);
        }
        catch (Exception e)
        {
            synchronized (storageMutex)
            {
                stats.errors++;
            }
            sendErrorResponse(client, 500, "Internal Server Error");
        }
    }
    
    private void handlePut(Socket client, ref HttpRequest request) @trusted
    {
        // Parse path: /artifacts/{hash}
        if (!request.path.startsWith("/artifacts/"))
        {
            sendErrorResponse(client, 404, "Not Found");
            return;
        }
        
        immutable hash = decode(request.path[11 .. $]);
        immutable artifactPath = buildPath(storageDir, hash);
        
        synchronized (storageMutex)
        {
            stats.putRequests++;
        }
        
        try
        {
            // Write artifact
            write(artifactPath, request.body_);
            
            synchronized (storageMutex)
            {
                stats.bytesUploaded += request.body_.length;
            }
            
            // Check if eviction needed
            checkEviction();
            
            sendResponse(client, 201, "Created", null);
        }
        catch (Exception e)
        {
            synchronized (storageMutex)
            {
                stats.errors++;
            }
            sendErrorResponse(client, 500, "Internal Server Error");
        }
    }
    
    private void handleHead(Socket client, ref HttpRequest request) @trusted
    {
        // Parse path: /artifacts/{hash}
        if (!request.path.startsWith("/artifacts/"))
        {
            sendErrorResponse(client, 404, "Not Found");
            return;
        }
        
        immutable hash = decode(request.path[11 .. $]);
        immutable artifactPath = buildPath(storageDir, hash);
        
        synchronized (storageMutex)
        {
            stats.headRequests++;
        }
        
        if (exists(artifactPath))
        {
            synchronized (storageMutex)
            {
                stats.hits++;
                stats.compute();
            }
            sendResponse(client, 200, "OK", null);
        }
        else
        {
            synchronized (storageMutex)
            {
                stats.misses++;
                stats.compute();
            }
            sendErrorResponse(client, 404, "Not Found");
        }
    }
    
    private void handleDelete(Socket client, ref HttpRequest request) @trusted
    {
        // Parse path: /artifacts/{hash}
        if (!request.path.startsWith("/artifacts/"))
        {
            sendErrorResponse(client, 404, "Not Found");
            return;
        }
        
        immutable hash = decode(request.path[11 .. $]);
        immutable artifactPath = buildPath(storageDir, hash);
        
        if (!exists(artifactPath))
        {
            sendErrorResponse(client, 404, "Not Found");
            return;
        }
        
        try
        {
            remove(artifactPath);
            sendResponse(client, 204, "No Content", null);
        }
        catch (Exception e)
        {
            synchronized (storageMutex)
            {
                stats.errors++;
            }
            sendErrorResponse(client, 500, "Internal Server Error");
        }
    }
    
    private void sendResponse(Socket client, int statusCode, string statusText, const(ubyte)[] body_) @trusted
    {
        Appender!(ubyte[]) response;
        
        // Status line
        response ~= cast(ubyte[])format("HTTP/1.1 %d %s\r\n", statusCode, statusText);
        
        // Headers
        response ~= cast(ubyte[])"Server: Builder-Cache/1.0\r\n";
        response ~= cast(ubyte[])"Connection: close\r\n";
        
        if (body_ !is null && body_.length > 0)
        {
            response ~= cast(ubyte[])format("Content-Length: %d\r\n", body_.length);
            response ~= cast(ubyte[])"Content-Type: application/octet-stream\r\n";
        }
        else
        {
            response ~= cast(ubyte[])"Content-Length: 0\r\n";
        }
        
        response ~= cast(ubyte[])"\r\n";
        
        // Body
        if (body_ !is null && body_.length > 0)
            response ~= body_;
        
        client.send(response.data);
    }
    
    private void sendErrorResponse(Socket client, int statusCode, string statusText) @trusted
    {
        sendResponse(client, statusCode, statusText, null);
    }
    
    private void checkEviction() @trusted
    {
        synchronized (storageMutex)
        {
            try
            {
                // Calculate total storage size
                size_t totalSize = 0;
                DirEntry[] entries;
                
                foreach (entry; dirEntries(storageDir, SpanMode.shallow))
                {
                    if (entry.isFile)
                    {
                        totalSize += entry.size;
                        entries ~= entry;
                    }
                }
                
                // Evict if over limit (remove oldest 10%)
                if (totalSize > maxStorageSize)
                {
                    import std.algorithm : sort;
                    import std.array : array;
                    
                    // Sort by access time (oldest first)
                    entries.sort!((a, b) => a.timeLastModified < b.timeLastModified);
                    
                    immutable toEvict = entries.length / 10;
                    foreach (entry; entries[0 .. toEvict])
                    {
                        remove(entry.name);
                    }
                    
                    writefln("Evicted %d artifacts (total size: %.2f MB)", 
                             toEvict, totalSize / 1_000_000.0);
                }
            }
            catch (Exception e)
            {
                writeln("Warning: Eviction check failed: ", e.msg);
            }
        }
    }
}


