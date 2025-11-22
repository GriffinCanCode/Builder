module infrastructure.errors.utils.snippets;

import std.file : readText, exists;
import std.string : splitLines, strip;
import std.array : empty;
import std.algorithm : min, max;
import std.conv : to;

/// Extract source code snippet around an error location
/// 
/// Responsibility: Read source file and extract context lines
string extractSnippet(string filePath, size_t line, size_t contextLines = 2) nothrow
{
    try
    {
        if (filePath.empty || !exists(filePath))
            return "";
        
        auto content = readText(filePath);
        auto lines = content.splitLines();
        
        if (line == 0 || line > lines.length)
            return "";
        
        // Calculate range (1-indexed -> 0-indexed)
        size_t startLine = line > contextLines ? line - contextLines - 1 : 0;
        size_t endLine = min(line + contextLines, lines.length);
        
        string snippet;
        foreach (i; startLine .. endLine)
        {
            if (snippet.length > 0)
                snippet ~= "\n";
            snippet ~= lines[i];
        }
        
        return snippet;
    }
    catch (Exception e)
    {
        return "";
    }
}

/// Extract single line from file
string extractLine(string filePath, size_t line) nothrow
{
    try
    {
        if (filePath.empty || !exists(filePath))
            return "";
        
        auto content = readText(filePath);
        auto lines = content.splitLines();
        
        if (line == 0 || line > lines.length)
            return "";
        
        return lines[line - 1].strip();
    }
    catch (Exception e)
    {
        return "";
    }
}

/// Create pointer indicator for column position
string createPointer(size_t column, char pointerChar = '^') pure nothrow
{
    if (column == 0)
        return "";
    
    string result;
    result.reserve(column);
    
    foreach (i; 0 .. column - 1)
        result ~= ' ';
    result ~= pointerChar;
    
    return result;
}

/// Format snippet with line numbers and pointer
string formatSnippetWithPointer(string snippet, size_t errorLine, size_t column, size_t firstLine = 1) pure
{
    import std.array : appender, split;
    import std.format : format;
    
    auto result = appender!string;
    auto lines = snippet.split("\n");
    
    foreach (i, line; lines)
    {
        size_t lineNum = firstLine + i;
        result.put(format("%4d | %s\n", lineNum, line));
        
        // Add pointer on error line
        if (lineNum == errorLine && column > 0)
        {
            result.put("     | ");
            result.put(createPointer(column));
            result.put("\n");
        }
    }
    
    return result.data;
}

