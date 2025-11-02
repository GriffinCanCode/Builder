module errors.formatting.colors;

/// ANSI color codes for terminal output
/// 
/// Responsibility: Centralize color code definitions
enum Color : string
{
    Reset = "\x1b[0m",
    Bold = "\x1b[1m",
    Red = "\x1b[31m",
    Green = "\x1b[32m",
    Yellow = "\x1b[33m",
    Blue = "\x1b[36m",
    Gray = "\x1b[90m"
}

/// Color formatter - single responsibility: apply colors to text
/// 
/// Separation of concerns:
/// - ErrorFormatter: formats error structures
/// - ColorFormatter: applies terminal colors
/// - SuggestionGenerator: generates helpful suggestions
struct ColorFormatter
{
    private bool enableColors;
    
    this(bool enableColors) pure nothrow @safe @nogc
    {
        this.enableColors = enableColors;
    }
    
    /// Wrap text with color codes
    string colored(string text, Color color) const pure @safe
    {
        if (!enableColors)
            return text;
        
        return cast(string)color ~ text ~ cast(string)Color.Reset;
    }
    
    /// Apply bold styling
    string bold(string text) const pure @safe
    {
        if (!enableColors)
            return text;
        
        return cast(string)Color.Bold ~ text ~ cast(string)Color.Reset;
    }
    
    /// Apply error styling (bold red)
    string error(string text) const pure @safe
    {
        if (!enableColors)
            return text;
        
        return cast(string)(Color.Bold ~ Color.Red) ~ text ~ cast(string)Color.Reset;
    }
    
    /// Apply warning styling (yellow)
    string warning(string text) const pure @safe
    {
        if (!enableColors)
            return text;
        
        return cast(string)Color.Yellow ~ text ~ cast(string)Color.Reset;
    }
    
    /// Apply info styling (blue)
    string info(string text) const pure @safe
    {
        if (!enableColors)
            return text;
        
        return cast(string)Color.Blue ~ text ~ cast(string)Color.Reset;
    }
    
    /// Apply muted styling (gray)
    string muted(string text) const pure @safe
    {
        if (!enableColors)
            return text;
        
        return cast(string)Color.Gray ~ text ~ cast(string)Color.Reset;
    }
    
    /// Apply success styling (green)
    string success(string text) const pure @safe
    {
        if (!enableColors)
            return text;
        
        return cast(string)Color.Green ~ text ~ cast(string)Color.Reset;
    }
}

