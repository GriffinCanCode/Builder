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
    
    @trusted // I/O operations are trusted
    static void info(in string msg)
    {
        writeln("\x1b[36m[INFO]\x1b[0m ", msg);
        stdout.flush();
    }
    
    @trusted // I/O operations are trusted
    static void success(in string msg)
    {
        writeln("\x1b[32m[SUCCESS]\x1b[0m ", msg);
        stdout.flush();
    }
    
    @trusted // I/O operations are trusted
    static void warning(in string msg)
    {
        writeln("\x1b[33m[WARNING]\x1b[0m ", msg);
        stdout.flush();
    }
    
    @trusted // I/O operations are trusted
    static void error(in string msg)
    {
        stderr.writeln("\x1b[31m[ERROR]\x1b[0m ", msg);
        stderr.flush();
    }
    
    @trusted // I/O operations are trusted
    static void debug_(in string msg)
    {
        if (verbose)
        {
            writeln("\x1b[90m[DEBUG]\x1b[0m ", msg);
            stdout.flush();
        }
    }
}

