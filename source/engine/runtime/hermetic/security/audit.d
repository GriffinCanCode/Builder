module engine.runtime.hermetic.security.audit;

import std.datetime : Clock, SysTime;
import std.conv : to;
import std.file : exists, append, mkdirRecurse;
import std.path : buildPath, dirName;
import std.json;
import infrastructure.utils.logging.structured;

/// Sandbox violation event
struct SandboxViolation
{
    SysTime timestamp;
    string violationType;     // "filesystem_write", "network_access", "process_fork", etc.
    string attemptedPath;     // Path or resource attempted
    string command;           // Command that attempted the violation
    string pid;              // Process ID
    string[] stackTrace;     // Stack trace if available
    string[string] metadata; // Additional context
}

/// Audit logger for hermetic execution violations
struct HermeticAuditLogger
{
    private string auditLogPath;
    private bool enabled;
    private StructuredLogger logger;  // Injected logger (null if not available)
    
    /// Create audit logger with optional structured logger
    static HermeticAuditLogger create(string logPath = "", StructuredLogger logger = null) @safe
    {
        HermeticAuditLogger auditLogger;
        auditLogger.logger = logger;
        
        if (logPath.length > 0)
        {
            auditLogger.auditLogPath = logPath;
            auditLogger.enabled = true;
            
            // Ensure directory exists
            try
            {
                immutable dir = dirName(logPath);
                if (!exists(dir))
                    mkdirRecurse(dir);
            }
            catch (Exception) {}
        }
        else
        {
            auditLogger.enabled = false;
        }
        
        return auditLogger;
    }
    
    /// Log a sandbox violation
    void logViolation(SandboxViolation violation) @trusted
    {
        if (!enabled)
            return;
        
        try
        {
            // Log to structured logger if available
            if (logger !is null)
            {
                string[string] fields;
                fields["violation.type"] = violation.violationType;
                fields["violation.path"] = violation.attemptedPath;
                fields["violation.command"] = violation.command;
                fields["violation.pid"] = violation.pid;
                logger.log(LogLevel.Warning, "Sandbox violation detected", fields);
            }
            
            // Log to audit file
            if (auditLogPath.length > 0)
            {
                auto json = toJSON(violation);
                append(auditLogPath, json ~ "\n");
            }
        }
        catch (Exception e)
        {
            // Best-effort logging - don't fail on audit errors
        }
    }
    
    /// Log filesystem access attempt
    void logFilesystemAccess(string path, string accessType, string command, bool allowed) @safe
    {
        if (!allowed)
        {
            SandboxViolation violation;
            violation.timestamp = Clock.currTime;
            violation.violationType = "filesystem_" ~ accessType;
            violation.attemptedPath = path;
            violation.command = command;
            violation.pid = getProcessId();
            violation.metadata["allowed"] = "false";
            
            logViolation(violation);
        }
    }
    
    /// Log network access attempt
    void logNetworkAccess(string host, string port, string protocol, string command, bool allowed) @safe
    {
        if (!allowed)
        {
            SandboxViolation violation;
            violation.timestamp = Clock.currTime;
            violation.violationType = "network_access";
            violation.attemptedPath = protocol ~ "://" ~ host ~ ":" ~ port;
            violation.command = command;
            violation.pid = getProcessId();
            violation.metadata["allowed"] = "false";
            violation.metadata["protocol"] = protocol;
            
            logViolation(violation);
        }
    }
    
    /// Log process creation attempt
    void logProcessCreation(string executable, string[] args, string command, bool allowed) @safe
    {
        if (!allowed)
        {
            SandboxViolation violation;
            violation.timestamp = Clock.currTime;
            violation.violationType = "process_creation";
            violation.attemptedPath = executable;
            violation.command = command;
            violation.pid = getProcessId();
            violation.metadata["allowed"] = "false";
            violation.metadata["args"] = args.to!string;
            
            logViolation(violation);
        }
    }
    
    /// Get current process ID as string
    private static string getProcessId() @trusted
    {
        version(Posix)
        {
            import core.sys.posix.unistd : getpid;
            return getpid().to!string;
        }
        else version(Windows)
        {
            import core.sys.windows.windows : GetCurrentProcessId;
            return GetCurrentProcessId().to!string;
        }
        else
        {
            return "unknown";
        }
    }
    
    /// Convert violation to JSON string
    private static string toJSON(SandboxViolation violation) @safe
    {
        JSONValue json = JSONValue.emptyObject;
        json["timestamp"] = violation.timestamp.toISOExtString();
        json["type"] = violation.violationType;
        json["path"] = violation.attemptedPath;
        json["command"] = violation.command;
        json["pid"] = violation.pid;
        
        if (violation.stackTrace.length > 0)
            json["stack_trace"] = JSONValue(violation.stackTrace);
        
        if (violation.metadata.length > 0)
        {
            JSONValue meta = JSONValue.emptyObject;
            foreach (key, value; violation.metadata)
                meta[key] = value;
            json["metadata"] = meta;
        }
        
        return json.toString();
    }
}


@safe unittest
{
    // Test audit logger creation
    auto logger = HermeticAuditLogger.create("");
    assert(!logger.enabled, "Logger should be disabled with empty path");
    
    // Test violation logging (should not throw)
    SandboxViolation violation;
    violation.timestamp = Clock.currTime;
    violation.violationType = "test";
    violation.attemptedPath = "/test/path";
    violation.command = "test command";
    
    logger.logViolation(violation);
}

