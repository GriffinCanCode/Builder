module utils.logging.logger;

import std.stdio;
import std.datetime;
import std.conv;

@safe:

/// Simple logging utility with colors
class Logger
{
    private static bool verbose = false;
    
    static void initialize()
    {
        // Setup logging
    }
    
    static void setVerbose(in bool v) nothrow @nogc
    {
        verbose = v;
    }
    
    /// Log info message
    /// 
    /// Safety: This function is @trusted because:
    /// 1. writeln() and stdout.flush() are I/O operations (inherently @system)
    /// 2. String concatenation with ANSI codes is safe
    /// 3. No memory management issues
    /// 4. Message string is read-only (in parameter)
    /// 
    /// Invariants:
    /// - ANSI color codes are compile-time constants
    /// - stdout is always valid in D programs
    /// - flush() ensures immediate output
    /// 
    /// What could go wrong:
    /// - stdout write fails: would throw exception (safe failure)
    /// - ANSI codes in non-terminal: harmless (just extra characters)
    @trusted
    static void info(in string msg)
    {
        writeln("\x1b[36m[INFO]\x1b[0m ", msg);
        stdout.flush();
    }
    
    /// Log success message
    /// 
    /// Safety: This function is @trusted because:
    /// 1. writeln() and stdout.flush() are I/O operations (inherently @system)
    /// 2. String operations are memory-safe
    /// 3. Message parameter is immutable (in)
    /// 
    /// Invariants:
    /// - Green ANSI code is compile-time constant
    /// - stdout is valid system stream
    /// 
    /// What could go wrong:
    /// - Write fails: exception propagates (safe failure)
    @trusted
    static void success(in string msg)
    {
        writeln("\x1b[32m[SUCCESS]\x1b[0m ", msg);
        stdout.flush();
    }
    
    /// Log warning message
    /// 
    /// Safety: This function is @trusted because:
    /// 1. writeln() and stdout.flush() are I/O operations (inherently @system)
    /// 2. Yellow ANSI code is safe constant
    /// 3. No unsafe memory operations
    /// 
    /// Invariants:
    /// - Message is immutable input
    /// - stdout writes are atomic at line level
    /// 
    /// What could go wrong:
    /// - Write fails: safe exception thrown
    @trusted
    static void warning(in string msg)
    {
        writeln("\x1b[33m[WARNING]\x1b[0m ", msg);
        stdout.flush();
    }
    
    /// Log error message to stderr
    /// 
    /// Safety: This function is @trusted because:
    /// 1. stderr.writeln() and stderr.flush() are I/O operations (inherently @system)
    /// 2. Using stderr instead of stdout for error reporting
    /// 3. Red ANSI code is compile-time constant
    /// 4. Message is immutable input
    /// 
    /// Invariants:
    /// - stderr is distinct from stdout (correct error stream)
    /// - ANSI codes don't affect error handling
    /// 
    /// What could go wrong:
    /// - stderr write fails: exception thrown (appropriate for errors)
    @trusted
    static void error(in string msg)
    {
        stderr.writeln("\x1b[31m[ERROR]\x1b[0m ", msg);
        stderr.flush();
    }
    
    /// Log debug message (only if verbose mode enabled)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Checks verbose flag before any I/O (minimal side effects)
    /// 2. writeln() and stdout.flush() are I/O operations (inherently @system)
    /// 3. Gray ANSI code for subtle debug output
    /// 4. Message is immutable input
    /// 
    /// Invariants:
    /// - verbose is checked before writing
    /// - Debug output goes to stdout (not stderr)
    /// - No output if verbose is false (no side effects)
    /// 
    /// What could go wrong:
    /// - Write fails: exception thrown (safe failure)
    /// - verbose flag race: acceptable (worst case is extra/missing debug line)
    @trusted
    static void debug_(in string msg)
    {
        if (verbose)
        {
            writeln("\x1b[90m[DEBUG]\x1b[0m ", msg);
            stdout.flush();
        }
    }
}

