module cli.display.format;

import cli.control.terminal;
import cli.events.events;
import std.format : format;
import std.string : leftJustify, rightJustify, center;
import std.algorithm : min, max;
import std.conv : to;
import std.datetime : Duration;

/// Message formatter with styling
/// Formats build events into styled terminal output

struct Formatter
{
    private Capabilities caps;
    private Symbols symbols;
    private bool useColors;
    
    this(Capabilities caps)
    {
        this.caps = caps;
        this.symbols = Symbols.detect(caps);
        this.useColors = caps.supportsColor;
    }
    
    /// Format build started message
    string formatBuildStarted(in size_t totalTargets, in size_t maxParallelism) const @safe
    {
        immutable msg = format("Building %d targets (parallelism: %d)...", 
                         totalTargets, maxParallelism);
        return styled(msg, Color.Cyan, Style.Bold);
    }
    
    /// Format build completed message
    string formatBuildCompleted(in size_t built, in size_t cached, in Duration duration) const @safe
    {
        immutable msg = format("%s Build completed in %s", 
                         symbols.checkmark, formatDuration(duration));
        immutable stats = format("  Built: %d, Cached: %d", built, cached);
        return styled(msg, Color.Green, Style.Bold) ~ "\n" ~ 
               styled(stats, Color.Green);
    }
    
    /// Format build failed message
    string formatBuildFailed(in size_t failed, in Duration duration) const @safe
    {
        immutable msg = format("%s Build failed with %d errors in %s",
                         symbols.cross, failed, formatDuration(duration));
        return styled(msg, Color.Red, Style.Bold);
    }
    
    /// Format target started message
    string formatTargetStarted(in string targetId, in size_t index, in size_t total) const @safe
    {
        immutable msg = format("[%d/%d] %s Building %s", 
                         index, total, symbols.building, targetId);
        return styled(msg, Color.Cyan);
    }
    
    /// Format target completed message
    string formatTargetCompleted(in string targetId, in Duration duration) const @safe
    {
        immutable msg = format("%s %s", symbols.checkmark, targetId);
        immutable time = format("(%s)", formatDuration(duration));
        return styled(msg, Color.Green) ~ " " ~ styled(time, Color.BrightBlack);
    }
    
    /// Format target cached message
    string formatTargetCached(in string targetId) const @safe
    {
        immutable msg = format("%s %s", symbols.cached, targetId);
        return styled(msg, Color.Yellow) ~ " " ~ 
               styled("(cached)", Color.BrightBlack);
    }
    
    /// Format target failed message
    string formatTargetFailed(in string targetId, in string error) const @safe
    {
        immutable msg = format("%s %s", symbols.cross, targetId);
        immutable errorMsg = format("  Error: %s", error);
        return styled(msg, Color.Red, Style.Bold) ~ "\n" ~ 
               styled(errorMsg, Color.Red);
    }
    
    /// Format info message
    string formatInfo(in string message) const @safe
    {
        return styled("[INFO] ", Color.Cyan) ~ message;
    }
    
    /// Format warning message
    string formatWarning(in string message) const @safe
    {
        return styled("[WARN] ", Color.Yellow, Style.Bold) ~ message;
    }
    
    /// Format error message
    string formatError(in string message) const @safe
    {
        return styled("[ERROR] ", Color.Red, Style.Bold) ~ message;
    }
    
    /// Format debug message
    string formatDebug(string message)
    {
        return styled("[DEBUG] ", Color.BrightBlack) ~ message;
    }
    
    /// Format cache statistics
    string formatCacheStats(CacheStats stats)
    {
        auto lines = [
            styled("Cache Statistics:", Color.Cyan, Style.Bold),
            format("  Hit rate:      %3.1f%% (%d hits, %d misses)", 
                   stats.hitRate, stats.hits, stats.misses),
            format("  Total entries: %d", stats.totalEntries),
            format("  Total size:    %s", formatSize(stats.totalSize))
        ];
        
        return lines.join("\n");
    }
    
    /// Format build statistics
    string formatBuildStats(BuildStats stats)
    {
        auto lines = [
            styled("Build Statistics:", Color.Cyan, Style.Bold),
            format("  Total targets:  %d", stats.totalTargets),
            format("  Completed:      %s%d%s", 
                   useColors ? ANSI.FG[Color.Green] : "",
                   stats.completedTargets,
                   useColors ? ANSI.reset() : ""),
            format("  Cached:         %s%d%s",
                   useColors ? ANSI.FG[Color.Yellow] : "",
                   stats.cachedTargets,
                   useColors ? ANSI.reset() : ""),
            format("  Failed:         %s%d%s",
                   useColors ? ANSI.FG[Color.Red] : "",
                   stats.failedTargets,
                   useColors ? ANSI.reset() : ""),
            format("  Elapsed:        %s", formatDuration(stats.elapsed)),
            format("  Throughput:     %.2f targets/sec", stats.targetsPerSecond)
        ];
        
        return lines.join("\n");
    }
    
    /// Format a separator line
    string formatSeparator(char c = '=', size_t length = 70)
    {
        char[] sep = new char[length];
        sep[] = c;
        return cast(string)sep;
    }
    
    /// Format separator with wide character
    private string formatSeparatorWide(dchar c, size_t length)
    {
        import std.array : replicate;
        import std.conv : to;
        return c.to!string.replicate(length);
    }
    
    /// Format a box around text
    string formatBox(string title, string[] lines)
    {
        size_t maxLen = title.length;
        foreach (line; lines)
            maxLen = max(maxLen, line.length);
        
        maxLen = min(maxLen + 4, caps.width - 4);
        
        auto topLine = "╔" ~ formatSeparatorWide('═', maxLen) ~ "╗";
        auto titleLine = "║ " ~ center(title, maxLen - 2) ~ " ║";
        auto midLine = "╠" ~ formatSeparatorWide('═', maxLen) ~ "╣";
        auto botLine = "╚" ~ formatSeparatorWide('═', maxLen) ~ "╝";
        
        string[] result = [topLine, titleLine];
        
        if (lines.length > 0)
        {
            result ~= midLine;
            foreach (line; lines)
                result ~= "║ " ~ leftJustify(line, maxLen - 2) ~ " ║";
        }
        
        result ~= botLine;
        
        return result.join("\n");
    }
    
    /// Apply styling to text
    private string styled(in string text, in Color color, in Style style = Style.None) const @safe
    {
        if (!useColors)
            return text;
        
        string result;
        
        if (style == Style.Bold)
            result ~= ANSI.BOLD;
        else if (style == Style.Dim)
            result ~= ANSI.DIM;
        
        result ~= ANSI.FG[color];
        result ~= text;
        result ~= ANSI.reset();
        
        return result;
    }
}

/// Duration formatting utilities
string formatDuration(in Duration d) pure @trusted
{
    immutable msecs = d.total!"msecs";
    
    if (msecs < 1000)
        return format("%dms", msecs);
    
    immutable secs = d.total!"seconds";
    if (secs < 60)
        return format("%.1fs", msecs / 1000.0);
    
    immutable mins = secs / 60;
    immutable secsRem = secs % 60;
    
    if (mins < 60)
        return format("%dm%ds", mins, secsRem);
    
    immutable hours = mins / 60;
    immutable minsRem = mins % 60;
    
    return format("%dh%dm", hours, minsRem);
}

/// Size formatting utilities
string formatSize(size_t bytes) pure
{
    if (bytes < 1024)
        return format("%d B", bytes);
    
    if (bytes < 1024 * 1024)
        return format("%.1f KB", bytes / 1024.0);
    
    if (bytes < 1024 * 1024 * 1024)
        return format("%.1f MB", bytes / (1024.0 * 1024));
    
    return format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
}

/// Percentage formatting
string formatPercent(double value) pure
{
    return format("%3.0f%%", value * 100);
}

/// Truncate string to fit width
string truncate(string text, size_t maxWidth, string ellipsis = "...") pure
{
    if (text.length <= maxWidth)
        return text;
    
    if (maxWidth <= ellipsis.length)
        return text[0 .. maxWidth];
    
    return text[0 .. maxWidth - ellipsis.length] ~ ellipsis;
}

/// Join string array helper
private string join(string[] arr, string sep) pure
{
    if (arr.length == 0)
        return "";
    if (arr.length == 1)
        return arr[0];
    
    size_t totalLen = (arr.length - 1) * sep.length;
    foreach (s; arr)
        totalLen += s.length;
    
    char[] result = new char[totalLen];
    size_t pos = 0;
    
    foreach (i, s; arr)
    {
        if (i > 0)
        {
            result[pos .. pos + sep.length] = sep;
            pos += sep.length;
        }
        result[pos .. pos + s.length] = s;
        pos += s.length;
    }
    
    return cast(string)result;
}

