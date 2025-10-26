module utils.logging.logger;

import std.stdio;
import std.datetime;
import std.conv;

/// Simple logging utility with colors
class Logger
{
    private static bool verbose = false;
    
    static void initialize() @safe
    {
        // Setup logging
    }
    
    static void setVerbose(in bool v) @safe nothrow @nogc
    {
        verbose = v;
    }
    
    static void info(in string msg) @trusted
    {
        writeln("\x1b[36m[INFO]\x1b[0m ", msg);
        stdout.flush();
    }
    
    static void success(in string msg) @trusted
    {
        writeln("\x1b[32m[SUCCESS]\x1b[0m ", msg);
        stdout.flush();
    }
    
    static void warning(in string msg) @trusted
    {
        writeln("\x1b[33m[WARNING]\x1b[0m ", msg);
        stdout.flush();
    }
    
    static void error(in string msg) @trusted
    {
        stderr.writeln("\x1b[31m[ERROR]\x1b[0m ", msg);
        stderr.flush();
    }
    
    static void debug_(in string msg) @trusted
    {
        if (verbose)
        {
            writeln("\x1b[90m[DEBUG]\x1b[0m ", msg);
            stdout.flush();
        }
    }
}

