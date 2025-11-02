module runtime.remote.artifacts;

import std.file : exists, read;
import distributed.protocol.protocol : ArtifactId, ActionId, InputSpec, OutputSpec;
import runtime.hermetic : SandboxSpec;
import caching.distributed.remote.client : RemoteCacheClient;
import errors;
import utils.logging.logger;

/// Artifact manager - single responsibility: manage artifact upload/download
/// 
/// Separation of concerns:
/// - RemoteExecutor: orchestrates remote execution flow
/// - ArtifactManager: handles artifact I/O and transfer
/// - RemoteCacheClient: handles actual network transfer to cache
final class ArtifactManager
{
    private RemoteCacheClient cacheClient;
    
    this(RemoteCacheClient cacheClient) @safe
    {
        this.cacheClient = cacheClient;
    }
    
    /// Upload input artifacts to remote store
    /// 
    /// Responsibility: Read, hash, and upload all input files/directories
    /// Returns: Array of InputSpec with artifact IDs for remote execution
    Result!(InputSpec[], BuildError) uploadInputs(SandboxSpec spec) @trusted
    {
        InputSpec[] inputs;
        
        foreach (inputPath; spec.inputs.paths)
        {
            // Read artifact from filesystem
            auto readResult = readArtifact(inputPath);
            if (readResult.isErr)
            {
                auto error = new GenericError(
                    "Failed to read input: " ~ inputPath ~ ": " ~ 
                    readResult.unwrapErr(),
                    ErrorCode.FileNotFound
                );
                return Err!(InputSpec[], BuildError)(error);
            }
            
            auto data = readResult.unwrap();
            
            // Compute artifact ID (content hash)
            auto artifactId = computeArtifactId(data);
            
            // Upload to artifact store
            auto uploadResult = cacheClient.put(
                artifactId.toString(), 
                cast(const(ubyte)[])data
            );
            if (uploadResult.isErr)
            {
                return Err!(InputSpec[], BuildError)(uploadResult.unwrapErr());
            }
            
            // Check if executable
            bool executable = isExecutable(inputPath);
            
            inputs ~= InputSpec(artifactId, inputPath, executable);
            
            Logger.debugLog("Uploaded input: " ~ inputPath ~ 
                          " -> " ~ artifactId.toString());
        }
        
        return Ok!(InputSpec[], BuildError)(inputs);
    }
    
    /// Download output artifacts from remote store
    /// 
    /// Responsibility: Download all output artifacts specified
    Result!BuildError downloadOutputs(ArtifactId[] artifacts) @trusted
    {
        foreach (artifactId; artifacts)
        {
            // Download from artifact store
            auto downloadResult = cacheClient.get(artifactId.toString());
            if (downloadResult.isErr)
            {
                return Result!BuildError.err(downloadResult.unwrapErr());
            }
            
            Logger.debugLog("Downloaded output: " ~ artifactId.toString());
        }
        
        return Result!BuildError.ok(cast(BuildError)null);
    }
    
    /// Read artifact from filesystem
    /// 
    /// Responsibility: Read file/directory contents
    private Result!(ubyte[], string) readArtifact(string path) @trusted
    {
        if (!exists(path))
            return Err!(ubyte[], string)("File not found: " ~ path);
        
        try
        {
            auto data = cast(ubyte[])read(path);
            return Ok!(ubyte[], string)(data);
        }
        catch (Exception e)
        {
            return Err!(ubyte[], string)(e.msg);
        }
    }
    
    /// Compute artifact ID from content
    /// 
    /// Responsibility: Hash artifact content using Blake3
    /// Uses Blake3 for consistency across the system
    private ArtifactId computeArtifactId(const ubyte[] data) @trusted
    {
        import utils.crypto.blake3 : Blake3;
        
        auto hasher = Blake3(0);
        hasher.put(cast(const(ubyte)[])data);
        
        auto hashBytes = hasher.finish(32);
        ubyte[32] hash;
        hash[0 .. 32] = hashBytes[0 .. 32];
        
        return ArtifactId(hash);
    }
    
    /// Check if file is executable
    /// 
    /// Responsibility: Determine file execution permissions
    private bool isExecutable(string path) @trusted
    {
        version(Posix)
        {
            import core.sys.posix.sys.stat;
            import std.string : toStringz;
            
            stat_t statbuf;
            if (stat(toStringz(path), &statbuf) == 0)
            {
                return (statbuf.st_mode & S_IXUSR) != 0;
            }
        }
        
        return false;
    }
}

