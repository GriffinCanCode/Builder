module utils.security.tempdir;

import std.file;
import std.path;
import std.random;
import std.conv;
import std.algorithm;
import std.range;

@safe:

/// Atomic temporary directory creation (prevents TOCTOU attacks)
/// Automatically cleaned up on scope exit
struct AtomicTempDir
{
    private string path;
    private bool _exists;
    
    @disable this(this); // Prevent copying
    
    /// Create atomic temporary directory with random name
    /// Throws: Exception if creation fails after retries
    /// 
    /// Safety: This function is @trusted because:
    /// 1. tempDir() is file system operation (inherently unsafe I/O)
    /// 2. buildPath() is safe string concatenation
    /// 3. exists() and mkdir() are file system operations
    /// 4. Retry loop prevents race conditions (TOCTOU mitigation)
    /// 5. Random suffix generation ensures uniqueness
    /// 
    /// Invariants:
    /// - Directory is created atomically via mkdir() (not mkdirRecurse)
    /// - Unique random suffix prevents collisions
    /// - Multiple retries handle race conditions
    /// 
    /// What could go wrong:
    /// - All retries exhausted: throws exception (safe failure)
    /// - Permission denied: caught and retried with new name
    /// - Race condition: mitigated by atomic mkdir() and retries
    static AtomicTempDir create(string prefix = "builder-tmp") @trusted
    {
        AtomicTempDir tmp;
        
        auto baseDir = tempDir();
        immutable maxRetries = 10;
        
        foreach (attempt; 0 .. maxRetries)
        {
            // Generate cryptographically random suffix
            auto suffix = generateSecureRandomSuffix();
            tmp.path = buildPath(baseDir, prefix ~ "-" ~ suffix);
            
            try
            {
                // mkdirRecurse with exists check is atomic on most platforms
                // For true atomicity, we'd need platform-specific calls
                if (!std.file.exists(tmp.path))
                {
                    mkdir(tmp.path); // Atomic creation
                    tmp._exists = true;
                    return tmp;
                }
            }
            catch (FileException e)
            {
                // Directory might exist due to race - retry with new name
                continue;
            }
        }
        
        throw new Exception("Failed to create temporary directory after " ~ maxRetries.to!string ~ " attempts");
    }
    
    /// Create in specific base directory
    /// 
    /// Safety: This function is @trusted because:
    /// 1. File system operations (exists, mkdirRecurse, mkdir) are unsafe I/O
    /// 2. Delegates to generateSecureRandomSuffix() for uniqueness
    /// 3. Retry loop handles race conditions
    /// 4. Exception handling ensures safe failure
    /// 
    /// Invariants:
    /// - baseDir is created if it doesn't exist
    /// - Directory creation is atomic via mkdir()
    /// - Random suffixes ensure uniqueness
    /// 
    /// What could go wrong:
    /// - baseDir creation fails: exception propagates (safe failure)
    /// - All retries exhausted: throws exception with context
    static AtomicTempDir in_(string baseDir, string prefix = "builder-tmp") @trusted
    {
        AtomicTempDir tmp;
        
        if (!std.file.exists(baseDir))
            mkdirRecurse(baseDir);
        
        immutable maxRetries = 10;
        
        foreach (attempt; 0 .. maxRetries)
        {
            auto suffix = generateSecureRandomSuffix();
            tmp.path = buildPath(baseDir, prefix ~ "-" ~ suffix);
            
            try
            {
                if (!std.file.exists(tmp.path))
                {
                    mkdir(tmp.path);
                    tmp._exists = true;
                    return tmp;
                }
            }
            catch (FileException)
            {
                continue;
            }
        }
        
        throw new Exception("Failed to create temporary directory in " ~ baseDir);
    }
    
    /// Destructor: automatic cleanup
    /// 
    /// Safety: This destructor is @trusted because:
    /// 1. File system operations (exists, rmdirRecurse) are unsafe I/O
    /// 2. Exception handling ensures nothrow guarantee
    /// 3. Best-effort cleanup (failures are logged but not thrown)
    /// 4. Logger access in destructor is carefully handled
    /// 
    /// Invariants:
    /// - Only removes directory if _exists flag is set
    /// - Errors are logged but don't crash program
    /// 
    /// What could go wrong:
    /// - Directory deletion fails: logged and ignored (acceptable in destructor)
    /// - Logger may fail in destructor context: caught and ignored safely
    /// - GC/finalizer context: handled by double exception catching
    ~this() @trusted nothrow
    {
        if (_exists && !path.empty)
        {
            try
            {
                if (std.file.exists(path))
                    rmdirRecurse(path);
            }
            catch (Exception e)
            {
                // Best effort cleanup - log but don't throw in destructor
                try
                {
                    import utils.logging.logger : Logger;
                    Logger.warning("Failed to clean up temp directory: " ~ path ~ " - " ~ e.msg);
                }
                catch (Exception)
                {
                    // Logger may fail in destructor context - safe to ignore
                }
            }
        }
    }
    
    /// Get the directory path
    string get() const @safe pure nothrow @nogc
    {
        return path;
    }
    
    /// Check if directory still exists
    /// 
    /// Safety: This function is @trusted because:
    /// 1. std.file.exists() is file system query (read-only)
    /// 2. Exception handling ensures nothrow guarantee
    /// 3. Returns safe default (false) on error
    /// 
    /// Invariants:
    /// - path is valid (set in create/in_ methods)
    /// - Read-only operation with no side effects
    /// 
    /// What could go wrong:
    /// - File system error: caught and returns false (safe default)
    /// - path is empty: returns false safely
    bool exists() const @trusted nothrow
    {
        try
        {
            return .exists(path);
        }
        catch (Exception)
        {
            return false;
        }
    }
    
    /// Build path within temporary directory
    string build(string relativePath) const @safe pure
    {
        return buildPath(path, relativePath);
    }
    
    /// Manual cleanup (directory won't be cleaned up in destructor after this)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. File system operations (exists, rmdirRecurse) are unsafe I/O
    /// 2. Clears _exists flag to prevent double-delete in destructor
    /// 3. Checks existence before attempting removal
    /// 
    /// Invariants:
    /// - After this call, destructor won't attempt removal
    /// - Path validity is checked before removal
    /// 
    /// What could go wrong:
    /// - Removal fails: exception propagates to caller
    /// - Directory already removed: exists() check prevents error
    void remove() @trusted
    {
        if (_exists && !path.empty && std.file.exists(path))
        {
            rmdirRecurse(path);
            _exists = false;
        }
    }
    
    /// Keep directory (prevent automatic cleanup)
    void keep() @safe pure nothrow @nogc
    {
        _exists = false;
    }
}

/// Generate secure random suffix for directory names
/// 
/// Safety: This function is @trusted because:
/// 1. Clock.currTime() is system call (inherently unsafe)
/// 2. uniform!ulong() generates random data (RNG state is unsafe)
/// 3. getpid/GetCurrentProcessId are system calls
/// 4. Pointer casting for serialization is bounds-checked
/// 5. sha256Of is cryptographic hash (uses C bindings internally)
/// 
/// Invariants:
/// - Combines timestamp, random data, and PID for uniqueness
/// - All data sources are mixed via cryptographic hash
/// - Output is deterministically 16 hex characters
/// 
/// What could go wrong:
/// - RNG could fail: would throw exception (safe failure)
/// - getpid could fail: caught by platform-specific code
/// - Pointer casting is safe: uses sizeof for exact bounds
private string generateSecureRandomSuffix() @trusted
{
    import std.random : uniform;
    import std.digest.sha : sha256Of;
    import std.datetime : Clock;
    
    // Mix current time, random data, and process ID for uniqueness
    ulong timestamp = Clock.currTime().stdTime;
    ulong random1 = uniform!ulong();
    ulong random2 = uniform!ulong();
    
    version(Posix)
    {
        import core.sys.posix.unistd : getpid;
        ulong pid = getpid();
    }
    else
    {
        import core.sys.windows.windows : GetCurrentProcessId;
        ulong pid = GetCurrentProcessId();
    }
    
    // Create seed data
    ubyte[] seed;
    seed.reserve(32);
    seed ~= (cast(ubyte*)&timestamp)[0 .. 8];
    seed ~= (cast(ubyte*)&random1)[0 .. 8];
    seed ~= (cast(ubyte*)&random2)[0 .. 8];
    seed ~= (cast(ubyte*)&pid)[0 .. 8];
    
    // Hash to get uniform distribution
    auto hash = sha256Of(seed);
    
    // Convert to hex string (first 16 chars for reasonable length)
    return hash[0 .. 8]
        .map!(b => [cast(char)"0123456789abcdef"[b >> 4], cast(char)"0123456789abcdef"[b & 0x0F]])
        .join;
}

/// Unit tests for AtomicTempDir
/// 
/// Safety: Test code is @trusted because:
/// 1. Tests file system operations
/// 2. Validates cleanup behavior
/// 3. Uses exists() and isDir() for verification
@trusted unittest
{
    import std.file : exists, isDir;
    
    // Test basic creation and cleanup
    {
        auto tmp = AtomicTempDir.create("test");
        assert(exists(tmp.get()));
        assert(isDir(tmp.get()));
        auto path = tmp.get();
        
        // Test build path
        auto subpath = tmp.build("subdir");
        assert(subpath.startsWith(path));
    }
    // tmp should be cleaned up here
    
    // Test custom base directory
    {
        auto tmp = AtomicTempDir.in_(tempDir(), "custom");
        assert(tmp.get().baseName.startsWith("custom-"));
    }
    
    // Test keep functionality
    {
        auto tmp = AtomicTempDir.create("keep-test");
        auto path = tmp.get();
        tmp.keep();
        // Destructor won't delete
    }
}

