module utils.logger;

import std.stdio;
import std.datetime;
import std.conv;

/// Simple logging utility with colors
class Logger
{
    private static bool verbose = false;
    
    static void initialize()
    {
        // Setup logging
    }
    
    static void setVerbose(bool v)
    {
        verbose = v;
    }
    
    static void info(string msg)
    {
        writeln("\x1b[36m[INFO]\x1b[0m ", msg);
        stdout.flush();
    }
    
    static void success(string msg)
    {
        writeln("\x1b[32m[SUCCESS]\x1b[0m ", msg);
        stdout.flush();
    }
    
    static void warning(string msg)
    {
        writeln("\x1b[33m[WARNING]\x1b[0m ", msg);
        stdout.flush();
    }
    
    static void error(string msg)
    {
        stderr.writeln("\x1b[31m[ERROR]\x1b[0m ", msg);
        stderr.flush();
    }
    
    static void debug_(string msg)
    {
        if (verbose)
        {
            writeln("\x1b[90m[DEBUG]\x1b[0m ", msg);
            stdout.flush();
        }
    }
}

