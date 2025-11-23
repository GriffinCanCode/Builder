module engine.runtime.hermetic.determinism.detector;

import std.regex : regex, matchFirst;
import std.algorithm : canFind, map, filter;
import std.array : array;
import std.string : strip, toLower;
import std.file : readText, exists;
import engine.runtime.hermetic.determinism.enforcer;
import infrastructure.errors;

/// Compiler type for determinism analysis
enum CompilerType
{
    GCC,
    Clang,
    DMD,
    GDC,
    LDC,
    Rustc,
    Go,
    Javac,
    Zig,
    Unknown
}

/// Non-determinism source category
enum NonDeterminismSource
{
    Timestamp,           // Embedded timestamps
    RandomValue,         // Random values (UUIDs, etc.)
    ThreadScheduling,    // Non-deterministic thread scheduling
    CompilerVersion,     // Compiler version changes
    FileOrdering,        // Non-deterministic file ordering
    PointerAddress,      // Embedded pointer addresses
    ASLR,               // Address space layout randomization
    BuildPath,          // Build path embedded in binary
    Unknown
}

/// Detection result for non-determinism
struct DetectionResult
{
    NonDeterminismSource source;
    string description;
    string[] affectedFiles;
    string[] compilerFlags;     // Suggested compiler flags
    string[] envVars;           // Suggested environment variables
    string explanation;         // Why this causes non-determinism
}

/// Automatic detector for non-determinism sources
/// 
/// Analyzes compiler output, binary files, and build logs to identify
/// sources of non-determinism. Provides actionable repair suggestions.
struct NonDeterminismDetector
{
    /// Detect non-determinism in compiler command
    static DetectionResult[] analyzeCompilerCommand(
        string[] command,
        CompilerType compiler = CompilerType.Unknown
    ) @safe
    {
        DetectionResult[] results;
        
        // Auto-detect compiler if not specified
        if (compiler == CompilerType.Unknown && command.length > 0)
            compiler = detectCompiler(command[0]);
        
        // Check for missing determinism flags
        final switch (compiler)
        {
            case CompilerType.GCC:
            case CompilerType.GDC:
                results ~= detectGCCFlags(command);
                break;
            
            case CompilerType.Clang:
                results ~= detectClangFlags(command);
                break;
            
            case CompilerType.DMD:
            case CompilerType.LDC:
                results ~= detectDFlags(command);
                break;
            
            case CompilerType.Rustc:
                results ~= detectRustFlags(command);
                break;
            
            case CompilerType.Go:
                results ~= detectGoFlags(command);
                break;
            
            case CompilerType.Zig:
                results ~= detectZigFlags(command);
                break;
            
            case CompilerType.Javac:
            case CompilerType.Unknown:
                break;
        }
        
        return results;
    }
    
    /// Detect non-determinism in build output
    static DetectionResult[] analyzeBuildOutput(string stdout, string stderr) @safe
    {
        DetectionResult[] results;
        
        // Check for timing information in output
        if (containsTimestamp(stdout) || containsTimestamp(stderr))
        {
            DetectionResult result;
            result.source = NonDeterminismSource.Timestamp;
            result.description = "Build output contains timestamps";
            result.explanation = "Timestamps in logs can leak into build artifacts";
            result.envVars = ["SOURCE_DATE_EPOCH=1640995200"];
            results ~= result;
        }
        
        // Check for random values (UUIDs)
        if (containsUUID(stdout) || containsUUID(stderr))
        {
            DetectionResult result;
            result.source = NonDeterminismSource.RandomValue;
            result.description = "Build output contains UUID or random values";
            result.explanation = "Random UUIDs break determinism";
            result.envVars = ["RANDOM_SEED=42"];
            results ~= result;
        }
        
        return results;
    }
    
    /// Compare two build outputs for differences
    static DeterminismViolation[] compareBuildOutputs(
        string outputHash1,
        string outputHash2,
        string[] outputFiles
    ) @safe
    {
        DeterminismViolation[] violations;
        
        if (outputHash1 != outputHash2)
        {
            DeterminismViolation violation;
            violation.source = "output_mismatch";
            violation.description = "Build outputs differ between runs";
            violation.affectedFiles = outputFiles;
            violation.suggestion = "Enable determinism flags for your compiler";
            violations ~= violation;
        }
        
        return violations;
    }
    
    private:
    
    /// Detect compiler type from executable name
    static CompilerType detectCompiler(string executable) @safe pure
    {
        import std.path : baseName;
        
        auto name = baseName(executable).toLower();
        
        // Check clang first since "clang++" contains "g++"
        if (name.canFind("clang"))
            return CompilerType.Clang;
        if (name.canFind("gcc") || name.canFind("g++"))
            return CompilerType.GCC;
        if (name == "dmd")
            return CompilerType.DMD;
        if (name == "ldc" || name == "ldc2")
            return CompilerType.LDC;
        if (name == "gdc")
            return CompilerType.GDC;
        if (name == "rustc")
            return CompilerType.Rustc;
        if (name == "go")
            return CompilerType.Go;
        if (name == "javac")
            return CompilerType.Javac;
        if (name == "zig")
            return CompilerType.Zig;
        
        return CompilerType.Unknown;
    }
    
    /// Detect missing GCC determinism flags
    static DetectionResult[] detectGCCFlags(string[] command) @safe pure
    {
        DetectionResult[] results;
        
        // Check for -frandom-seed
        if (!hasFlag(command, "-frandom-seed"))
        {
            DetectionResult result;
            result.source = NonDeterminismSource.RandomValue;
            result.description = "GCC without -frandom-seed";
            result.compilerFlags = ["-frandom-seed=42"];
            result.explanation = "GCC uses random seeds for register allocation";
            results ~= result;
        }
        
        // Check for -ffile-prefix-map or -fdebug-prefix-map
        if (!hasFlag(command, "-ffile-prefix-map") && 
            !hasFlag(command, "-fdebug-prefix-map"))
        {
            DetectionResult result;
            result.source = NonDeterminismSource.BuildPath;
            result.description = "GCC embeds build paths in debug info";
            result.compilerFlags = ["-ffile-prefix-map=/workspace/=./"];
            result.explanation = "Absolute paths in debug info break determinism";
            results ~= result;
        }
        
        return results;
    }
    
    /// Detect missing Clang determinism flags
    static DetectionResult[] detectClangFlags(string[] command) @safe pure
    {
        DetectionResult[] results;
        
        // Check for -fdebug-prefix-map
        if (!hasFlag(command, "-fdebug-prefix-map"))
        {
            DetectionResult result;
            result.source = NonDeterminismSource.BuildPath;
            result.description = "Clang embeds build paths in debug info";
            result.compilerFlags = ["-fdebug-prefix-map=/workspace/=./"];
            result.explanation = "Absolute paths in debug info break determinism";
            results ~= result;
        }
        
        return results;
    }
    
    /// Detect missing D compiler flags
    static DetectionResult[] detectDFlags(string[] command) @safe pure
    {
        DetectionResult[] results;
        
        // D compilers embed timestamps by default in debug builds
        if (!hasFlag(command, "-release") && !hasFlag(command, "-g"))
        {
            DetectionResult result;
            result.source = NonDeterminismSource.Timestamp;
            result.description = "D compiler may embed timestamps";
            result.envVars = ["SOURCE_DATE_EPOCH=1640995200"];
            result.explanation = "D compilers can embed build timestamps";
            results ~= result;
        }
        
        return results;
    }
    
    /// Detect missing Rust determinism flags
    static DetectionResult[] detectRustFlags(string[] command) @safe pure
    {
        DetectionResult[] results;
        
        // Rust is mostly deterministic by default, but check for incremental
        if (hasFlag(command, "-Cincremental"))
        {
            DetectionResult result;
            result.source = NonDeterminismSource.FileOrdering;
            result.description = "Incremental compilation may be non-deterministic";
            result.explanation = "Rust incremental cache depends on filesystem state";
            result.compilerFlags = ["-Cincremental=false"];
            results ~= result;
        }
        
        return results;
    }
    
    /// Detect missing Go determinism flags
    static DetectionResult[] detectGoFlags(string[] command) @safe pure
    {
        DetectionResult[] results;
        
        // Check for -trimpath
        if (!hasFlag(command, "-trimpath"))
        {
            DetectionResult result;
            result.source = NonDeterminismSource.BuildPath;
            result.description = "Go embeds build paths without -trimpath";
            result.compilerFlags = ["-trimpath"];
            result.explanation = "Go embeds GOPATH in binaries by default";
            results ~= result;
        }
        
        return results;
    }
    
    /// Detect missing Zig determinism flags
    static DetectionResult[] detectZigFlags(string[] command) @safe pure
    {
        // Zig is deterministic by default
        DetectionResult[] results;
        return results;
    }
    
    /// Check if command contains flag
    static bool hasFlag(string[] command, string flag) @safe pure nothrow
    {
        foreach (arg; command)
        {
            if (arg == flag || arg.canFind(flag))
                return true;
        }
        return false;
    }
    
    /// Check if string contains timestamp pattern
    static bool containsTimestamp(string text) @safe
    {
        // Common timestamp patterns
        auto patterns = [
            r"\d{4}-\d{2}-\d{2}",                    // YYYY-MM-DD
            r"\d{2}:\d{2}:\d{2}",                    // HH:MM:SS
            r"\d{10}",                                // Unix timestamp
            r"[JFMASOND][a-z]{2}\s+\d{1,2}\s+\d{4}", // Month DD YYYY
        ];
        
        foreach (pattern; patterns)
        {
            auto re = regex(pattern);
            if (!matchFirst(text, re).empty)
                return true;
        }
        
        return false;
    }
    
    /// Check if string contains UUID pattern
    static bool containsUUID(string text) @safe
    {
        auto uuidPattern = regex(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
        return !matchFirst(text, uuidPattern).empty;
    }
}

@safe unittest
{
    import std.stdio : writeln;
    
    writeln("Testing non-determinism detector...");
    
    // Test compiler detection
    assert(NonDeterminismDetector.detectCompiler("gcc") == CompilerType.GCC);
    assert(NonDeterminismDetector.detectCompiler("clang++") == CompilerType.Clang);
    assert(NonDeterminismDetector.detectCompiler("dmd") == CompilerType.DMD);
    
    // Test GCC flag detection
    auto gccResults = NonDeterminismDetector.analyzeCompilerCommand(
        ["gcc", "main.c", "-o", "main"],
        CompilerType.GCC
    );
    assert(gccResults.length > 0);
    assert(gccResults[0].source == NonDeterminismSource.RandomValue);
    
    // Test timestamp detection
    assert(NonDeterminismDetector.containsTimestamp("Build on 2024-01-15"));
    assert(NonDeterminismDetector.containsTimestamp("Time: 14:23:45"));
    assert(!NonDeterminismDetector.containsTimestamp("No timestamps here"));
    
    // Test UUID detection
    assert(NonDeterminismDetector.containsUUID("ID: 550e8400-e29b-41d4-a716-446655440000"));
    assert(!NonDeterminismDetector.containsUUID("No UUIDs here"));
    
    writeln("✓ Non-determinism detector tests passed");
}

