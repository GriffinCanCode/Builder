module cli.stream;

import cli.terminal;
import cli.format;
import cli.events : Severity;
import std.stdio : stdout, stderr;
import core.sync.mutex : Mutex;
import std.algorithm : filter;
import std.array : array;
import std.datetime : Duration;

/// Output stream multiplexer for parallel build output
/// Manages multiple concurrent output streams with clean formatting

/// Stream level for filtering
enum StreamLevel
{
    Debug,
    Info,
    Warning,
    Error
}

/// Single output stream
struct OutputStream
{
    string id;
    StreamLevel level;
    string[] buffer;
    bool active;
    Duration startTime;
    
    /// Add line to buffer
    void writeln(string line)
    {
        buffer ~= line;
    }
    
    /// Clear buffer
    void clear()
    {
        buffer = [];
    }
}

/// Stream multiplexer with thread-safe operations
class StreamMultiplexer
{
    private OutputStream[string] streams;
    private Mutex mutex;
    private StreamLevel minLevel;
    private Terminal terminal;
    private Formatter formatter;
    private bool captureOutput;
    private size_t maxBufferSize;
    
    this(Terminal terminal, Formatter formatter, 
         StreamLevel minLevel = StreamLevel.Info,
         bool captureOutput = false,
         size_t maxBufferSize = 1000)
    {
        this.terminal = terminal;
        this.formatter = formatter;
        this.minLevel = minLevel;
        this.captureOutput = captureOutput;
        this.maxBufferSize = maxBufferSize;
        this.mutex = new Mutex();
    }
    
    /// Create a new stream
    void createStream(string id, StreamLevel level)
    {
        synchronized (mutex)
        {
            if (id !in streams)
            {
                streams[id] = OutputStream(id, level, [], true);
            }
        }
    }
    
    /// Write to stream
    void write(string streamId, string message, StreamLevel level = StreamLevel.Info)
    {
        if (level < minLevel)
            return;
        
        synchronized (mutex)
        {
            // Create stream if it doesn't exist
            if (streamId !in streams)
                streams[streamId] = OutputStream(streamId, level, [], true);
            
            auto stream = &streams[streamId];
            
            if (captureOutput)
            {
                // Buffer output
                stream.writeln(message);
                
                // Trim buffer if too large
                if (stream.buffer.length > maxBufferSize)
                    stream.buffer = stream.buffer[$ - maxBufferSize .. $];
            }
            else
            {
                // Write directly to terminal
                writeToTerminal(message, level);
            }
        }
    }
    
    /// Flush stream to terminal
    void flushStream(string streamId)
    {
        synchronized (mutex)
        {
            if (streamId !in streams)
                return;
            
            auto stream = &streams[streamId];
            
            if (stream.buffer.length > 0)
            {
                foreach (line; stream.buffer)
                    writeToTerminal(line, stream.level);
                
                stream.clear();
            }
        }
    }
    
    /// Flush all streams
    void flushAll()
    {
        synchronized (mutex)
        {
            foreach (id; streams.keys)
                flushStream(id);
        }
    }
    
    /// Close stream
    void closeStream(string streamId)
    {
        synchronized (mutex)
        {
            if (streamId in streams)
            {
                flushStream(streamId);
                streams[streamId].active = false;
            }
        }
    }
    
    /// Get stream buffer (for testing or inspection)
    string[] getStreamBuffer(string streamId)
    {
        synchronized (mutex)
        {
            if (streamId in streams)
                return streams[streamId].buffer.dup;
            return [];
        }
    }
    
    /// Get active streams
    string[] getActiveStreams()
    {
        synchronized (mutex)
        {
            return streams.values
                .filter!(s => s.active)
                .map!(s => s.id)
                .array;
        }
    }
    
    /// Clear all streams
    void clearAll()
    {
        synchronized (mutex)
        {
            foreach (ref stream; streams)
                stream.clear();
        }
    }
    
    /// Write to terminal with appropriate formatting
    private void writeToTerminal(string message, StreamLevel level)
    {
        final switch (level)
        {
            case StreamLevel.Debug:
                terminal.writeln(formatter.formatDebug(message));
                break;
            case StreamLevel.Info:
                terminal.writeln(formatter.formatInfo(message));
                break;
            case StreamLevel.Warning:
                terminal.writeln(formatter.formatWarning(message));
                break;
            case StreamLevel.Error:
                terminal.writeln(formatter.formatError(message));
                break;
        }
        terminal.flush();
    }
}

/// Status line manager for real-time updates
/// Uses cursor manipulation to update a single line in place
class StatusLine
{
    private Terminal terminal;
    private Formatter formatter;
    private bool enabled;
    private string currentLine;
    private bool lineActive;
    private Mutex mutex;
    
    this(Terminal terminal, Formatter formatter)
    {
        this.terminal = terminal;
        this.formatter = formatter;
        this.enabled = terminal.getCapabilities().supportsProgressBar;
        this.lineActive = false;
        this.mutex = new Mutex();
    }
    
    /// Update status line (in place)
    void update(string status)
    {
        if (!enabled)
            return;
        
        synchronized (mutex)
        {
            // Clear current line
            if (lineActive)
            {
                terminal.write(ANSI.clearLine());
                terminal.write("\r");
            }
            
            // Truncate to terminal width
            auto maxWidth = terminal.getCapabilities().width;
            if (status.length > maxWidth)
                status = truncate(status, maxWidth - 3) ~ "...";
            
            // Write new status
            terminal.write(status);
            terminal.flush();
            
            currentLine = status;
            lineActive = true;
        }
    }
    
    /// Clear status line
    void clear()
    {
        if (!enabled || !lineActive)
            return;
        
        synchronized (mutex)
        {
            terminal.write(ANSI.clearLine());
            terminal.write("\r");
            terminal.flush();
            lineActive = false;
            currentLine = "";
        }
    }
    
    /// Temporarily clear to write other output, then restore
    void withClear(void delegate() func)
    {
        synchronized (mutex)
        {
            auto savedLine = currentLine;
            auto wasActive = lineActive;
            
            if (wasActive)
                clear();
            
            func();
            
            if (wasActive)
                update(savedLine);
        }
    }
    
    /// Check if enabled
    bool isEnabled() const
    {
        return enabled;
    }
}

/// Helper to map event level to stream level
StreamLevel toStreamLevel(Severity severity)
{
    final switch (severity)
    {
        case Severity.Debug:
            return StreamLevel.Debug;
        case Severity.Info:
            return StreamLevel.Info;
        case Severity.Warning:
            return StreamLevel.Warning;
        case Severity.Error:
        case Severity.Critical:
            return StreamLevel.Error;
    }
}

// Import map for array operations
private import std.algorithm : map;

