module caching.incremental.storage;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.datetime;
import std.conv;
import caching.incremental.dependency;
import utils.logging.logger;
import errors;

/// Binary storage for dependency cache
/// Uses efficient binary serialization for fast I/O
final class DependencyStorage
{
    private string storageDir;
    private immutable string storageFile;
    
    this(string storageDir) @safe
    {
        this.storageDir = storageDir;
        this.storageFile = buildPath(storageDir, "dependencies.bin");
    }
    
    /// Load dependencies from disk
    Result!(FileDependency[], BuildError) load() @system
    {
        if (!exists(storageFile))
        {
            return Result!(FileDependency[], BuildError).ok([]);
        }
        
        try
        {
            auto file = File(storageFile, "rb");
            scope(exit) file.close();
            
            // Read version
            ubyte version_;
            file.rawRead((&version_)[0..1]);
            
            if (version_ != 1)
            {
                return Result!(FileDependency[], BuildError).err(
                    new GenericError("Unsupported dependency cache version: " ~ 
                                 version_.to!string, ErrorCode.InvalidJson)
                );
            }
            
            // Read entry count
            uint count;
            file.rawRead((&count)[0..1]);
            
            FileDependency[] deps;
            deps.reserve(count);
            
            // Read each entry
            foreach (i; 0 .. count)
            {
                FileDependency dep;
                
                // Read source file path
                dep.sourceFile = readString(file);
                
                // Read dependencies
                uint depCount;
                file.rawRead((&depCount)[0..1]);
                dep.dependencies.reserve(depCount);
                
                foreach (j; 0 .. depCount)
                {
                    dep.dependencies ~= readString(file);
                }
                
                // Read source hash
                dep.sourceHash = readString(file);
                
                // Read dependency hashes
                uint hashCount;
                file.rawRead((&hashCount)[0..1]);
                dep.depHashes.reserve(hashCount);
                
                foreach (j; 0 .. hashCount)
                {
                    dep.depHashes ~= readString(file);
                }
                
                // Read timestamp
                long timestamp;
                file.rawRead((&timestamp)[0..1]);
                dep.timestamp = SysTime(timestamp);
                
                deps ~= dep;
            }
            
            return Result!(FileDependency[], BuildError).ok(deps);
        }
        catch (Exception e)
        {
            return Result!(FileDependency[], BuildError).err(
                new GenericError("Failed to load dependency cache: " ~ e.msg,
                             ErrorCode.FileReadFailed)
            );
        }
    }
    
    /// Save dependencies to disk
    Result!BuildError save(FileDependency[] deps) @system
    {
        try
        {
            // Ensure directory exists
            if (!exists(storageDir))
                mkdirRecurse(storageDir);
            
            // Write to temporary file first
            auto tempFile = storageFile ~ ".tmp";
            auto file = File(tempFile, "wb");
            scope(exit) 
            {
                file.close();
                if (exists(tempFile))
                    remove(tempFile);
            }
            
            // Write version
            ubyte version_ = 1;
            file.rawWrite((&version_)[0..1]);
            
            // Write entry count
            uint count = cast(uint)deps.length;
            file.rawWrite((&count)[0..1]);
            
            // Write each entry
            foreach (ref dep; deps)
            {
                // Write source file path
                writeString(file, dep.sourceFile);
                
                // Write dependencies
                uint depCount = cast(uint)dep.dependencies.length;
                file.rawWrite((&depCount)[0..1]);
                
                foreach (dependency; dep.dependencies)
                {
                    writeString(file, dependency);
                }
                
                // Write source hash
                writeString(file, dep.sourceHash);
                
                // Write dependency hashes
                uint hashCount = cast(uint)dep.depHashes.length;
                file.rawWrite((&hashCount)[0..1]);
                
                foreach (hash; dep.depHashes)
                {
                    writeString(file, hash);
                }
                
                // Write timestamp
                long timestamp = dep.timestamp.stdTime;
                file.rawWrite((&timestamp)[0..1]);
            }
            
            file.close();
            
            // Atomic rename
            if (exists(storageFile))
                remove(storageFile);
            rename(tempFile, storageFile);
            
            return Result!BuildError.ok();
        }
        catch (Exception e)
        {
            return Result!BuildError.err(
                new GenericError("Failed to save dependency cache: " ~ e.msg,
                             ErrorCode.FileReadFailed)
            );
        }
    }
    
    private string readString(ref File file) @system
    {
        uint length;
        file.rawRead((&length)[0..1]);
        
        if (length == 0)
            return "";
        
        auto buffer = new char[length];
        file.rawRead(buffer);
        
        return buffer.idup;
    }
    
    private void writeString(ref File file, string str) @system
    {
        uint length = cast(uint)str.length;
        file.rawWrite((&length)[0..1]);
        
        if (length > 0)
            file.rawWrite(str);
    }
}

