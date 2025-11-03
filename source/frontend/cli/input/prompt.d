module frontend.cli.input.prompt;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import frontend.cli.control.terminal;
import frontend.cli.display.format;

/// Interactive prompt system for CLI input
/// Provides select, confirm, and text input with arrow key navigation

/// Select option in a menu
struct SelectOption(T)
{
    string label;
    T value;
    string description;
    
    this(string label, T value, string description = "")
    {
        this.label = label;
        this.value = value;
        this.description = description;
    }
}

/// Prompt utilities for interactive CLI
struct Prompt
{
    private static Terminal terminal;
    private static Formatter formatter;
    private static Capabilities caps;
    private static bool initialized = false;
    
    /// Initialize prompt system
    private static void init()
    {
        if (!initialized)
        {
            caps = Capabilities.detect();
            terminal = Terminal(caps);
            formatter = Formatter(caps);
            initialized = true;
        }
    }
    
    /// Select from options with arrow keys
    static T select(T)(string question, SelectOption!T[] options, size_t defaultIdx = 0)
    {
        init();
        
        if (!caps.isInteractive)
        {
            // Non-interactive mode: return default
            return options[defaultIdx].value;
        }
        
        size_t selected = defaultIdx;
        bool done = false;
        
        // Hide cursor
        terminal.write(ANSI.cursorHide());
        terminal.flush();
        
        scope(exit)
        {
            // Show cursor on exit
            terminal.write(ANSI.cursorShow());
            terminal.flush();
        }
        
        // Initial render
        renderSelectMenu(question, options, selected);
        
        // Read input character by character
        while (!done)
        {
            import core.sys.posix.unistd : read;
            import core.sys.posix.termios;
            
            char[3] buf;
            auto bytesRead = read(0, buf.ptr, 3);
            
            if (bytesRead == -1)
                break;
            
            // Handle arrow keys (ESC [ A/B) or Enter
            if (bytesRead == 3 && buf[0] == '\x1b' && buf[1] == '[')
            {
                if (buf[2] == 'A' && selected > 0) // Up arrow
                {
                    selected--;
                    clearSelectMenu(options.length);
                    renderSelectMenu(question, options, selected);
                }
                else if (buf[2] == 'B' && selected < options.length - 1) // Down arrow
                {
                    selected++;
                    clearSelectMenu(options.length);
                    renderSelectMenu(question, options, selected);
                }
            }
            else if (bytesRead == 1)
            {
                if (buf[0] == '\n' || buf[0] == '\r') // Enter
                {
                    done = true;
                }
                else if (buf[0] == 'j' && selected < options.length - 1) // vim-style down
                {
                    selected++;
                    clearSelectMenu(options.length);
                    renderSelectMenu(question, options, selected);
                }
                else if (buf[0] == 'k' && selected > 0) // vim-style up
                {
                    selected--;
                    clearSelectMenu(options.length);
                    renderSelectMenu(question, options, selected);
                }
            }
        }
        
        // Clear menu and show final selection
        clearSelectMenu(options.length);
        terminal.writeColored("? ", Color.Green);
        terminal.write(question ~ " ");
        terminal.writeColored(options[selected].label, Color.Cyan, Style.Bold);
        terminal.writeln();
        terminal.flush();
        
        return options[selected].value;
    }
    
    /// Render select menu
    private static void renderSelectMenu(T)(string question, SelectOption!T[] options, size_t selected)
    {
        terminal.writeColored("? ", Color.Green);
        terminal.writeColored(question, Color.White, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("(arrow keys)", Color.BrightBlack);
        terminal.writeln();
        
        foreach (i, opt; options)
        {
            if (i == selected)
            {
                terminal.writeColored("  > ", Color.Cyan, Style.Bold);
                terminal.writeColored(opt.label, Color.Cyan, Style.Bold);
            }
            else
            {
                terminal.write("    ");
                terminal.write(opt.label);
            }
            
            if (opt.description.length > 0)
            {
                terminal.write(" ");
                terminal.writeColored("(" ~ opt.description ~ ")", Color.BrightBlack);
            }
            
            terminal.writeln();
        }
        
        terminal.flush();
    }
    
    /// Clear select menu
    private static void clearSelectMenu(size_t optionCount)
    {
        // Move cursor up (question + options)
        terminal.write(ANSI.cursorUp(cast(ushort)(optionCount + 1)));
        
        // Clear each line
        foreach (_; 0 .. optionCount + 1)
        {
            terminal.write(ANSI.clearLine());
            terminal.write(ANSI.cursorDown(1));
        }
        
        // Move back to start
        terminal.write(ANSI.cursorUp(cast(ushort)(optionCount + 1)));
        terminal.flush();
    }
    
    /// Confirm (yes/no) prompt
    static bool confirm(string question, bool defaultYes = true)
    {
        init();
        
        if (!caps.isInteractive)
        {
            return defaultYes;
        }
        
        string prompt = defaultYes ? " (Y/n) " : " (y/N) ";
        
        terminal.writeColored("? ", Color.Green);
        terminal.write(question);
        terminal.writeColored(prompt, Color.BrightBlack);
        terminal.flush();
        
        string response = strip(stdin.readln());
        
        if (response.length == 0)
            return defaultYes;
        
        char first = cast(char)toLower(response[0]);
        bool result = first == 'y';
        
        // Show result
        terminal.write(ANSI.cursorUp(1));
        terminal.write(ANSI.clearLine());
        terminal.writeColored("? ", Color.Green);
        terminal.write(question ~ " ");
        terminal.writeColored(result ? "Yes" : "No", Color.Cyan, Style.Bold);
        terminal.writeln();
        terminal.flush();
        
        return result;
    }
    
    /// Text input prompt
    static string input(string question, string defaultValue = "")
    {
        init();
        
        if (!caps.isInteractive)
        {
            return defaultValue;
        }
        
        terminal.writeColored("? ", Color.Green);
        terminal.write(question);
        
        if (defaultValue.length > 0)
        {
            terminal.write(" ");
            terminal.writeColored("(" ~ defaultValue ~ ")", Color.BrightBlack);
        }
        
        terminal.write(": ");
        terminal.flush();
        
        string response = strip(stdin.readln());
        
        if (response.length == 0 && defaultValue.length > 0)
            response = defaultValue;
        
        return response;
    }
    
    /// Multi-select with checkboxes
    static T[] multiSelect(T)(string question, SelectOption!T[] options, bool[] defaultSelected)
    {
        init();
        
        if (!caps.isInteractive)
        {
            // Non-interactive: return defaults
            T[] result;
            foreach (i, opt; options)
            {
                if (i < defaultSelected.length && defaultSelected[i])
                    result ~= opt.value;
            }
            return result;
        }
        
        bool[] selected = defaultSelected.dup;
        if (selected.length != options.length)
        {
            selected = new bool[options.length];
            if (defaultSelected.length > 0)
                selected[0 .. min(defaultSelected.length, options.length)] = 
                    defaultSelected[0 .. min(defaultSelected.length, options.length)];
        }
        
        size_t cursor = 0;
        bool done = false;
        
        terminal.write(ANSI.cursorHide());
        terminal.flush();
        
        scope(exit)
        {
            terminal.write(ANSI.cursorShow());
            terminal.flush();
        }
        
        renderMultiSelectMenu(question, options, selected, cursor);
        
        while (!done)
        {
            import core.sys.posix.unistd : read;
            
            char[3] buf;
            auto bytesRead = read(0, buf.ptr, 3);
            
            if (bytesRead == -1)
                break;
            
            if (bytesRead == 3 && buf[0] == '\x1b' && buf[1] == '[')
            {
                if (buf[2] == 'A' && cursor > 0)
                {
                    cursor--;
                    clearMultiSelectMenu(options.length);
                    renderMultiSelectMenu(question, options, selected, cursor);
                }
                else if (buf[2] == 'B' && cursor < options.length - 1)
                {
                    cursor++;
                    clearMultiSelectMenu(options.length);
                    renderMultiSelectMenu(question, options, selected, cursor);
                }
            }
            else if (bytesRead == 1)
            {
                if (buf[0] == '\n' || buf[0] == '\r')
                {
                    done = true;
                }
                else if (buf[0] == ' ') // Space to toggle
                {
                    selected[cursor] = !selected[cursor];
                    clearMultiSelectMenu(options.length);
                    renderMultiSelectMenu(question, options, selected, cursor);
                }
            }
        }
        
        // Build result
        T[] result;
        foreach (i, opt; options)
        {
            if (selected[i])
                result ~= opt.value;
        }
        
        clearMultiSelectMenu(options.length);
        terminal.writeColored("? ", Color.Green);
        terminal.write(question ~ " ");
        terminal.writeColored(format("%d selected", result.length), Color.Cyan, Style.Bold);
        terminal.writeln();
        terminal.flush();
        
        return result;
    }
    
    /// Render multi-select menu
    private static void renderMultiSelectMenu(T)(string question, SelectOption!T[] options, 
                                                   bool[] selected, size_t cursor)
    {
        terminal.writeColored("? ", Color.Green);
        terminal.writeColored(question, Color.White, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("(space to toggle, enter to confirm)", Color.BrightBlack);
        terminal.writeln();
        
        foreach (i, opt; options)
        {
            if (i == cursor)
            {
                terminal.writeColored("  > ", Color.Cyan, Style.Bold);
            }
            else
            {
                terminal.write("    ");
            }
            
            // Checkbox
            if (selected[i])
            {
                terminal.writeColored("[✓] ", Color.Green);
            }
            else
            {
                terminal.writeColored("[ ] ", Color.BrightBlack);
            }
            
            if (i == cursor)
            {
                terminal.writeColored(opt.label, Color.Cyan, Style.Bold);
            }
            else
            {
                terminal.write(opt.label);
            }
            
            terminal.writeln();
        }
        
        terminal.flush();
    }
    
    /// Clear multi-select menu
    private static void clearMultiSelectMenu(size_t optionCount)
    {
        clearSelectMenu(optionCount); // Same implementation
    }
    
    /// Success message
    static void success(string message)
    {
        init();
        terminal.writeColored("✓ ", Color.Green, Style.Bold);
        terminal.write(message);
        terminal.writeln();
        terminal.flush();
    }
    
    /// Info message
    static void info(string message)
    {
        init();
        terminal.writeColored("ℹ ", Color.Cyan);
        terminal.write(message);
        terminal.writeln();
        terminal.flush();
    }
    
    /// Restore terminal to normal mode
    static void cleanup()
    {
        if (initialized)
        {
            terminal.write(ANSI.cursorShow());
            terminal.flush();
        }
    }
}

/// Setup raw terminal mode for arrow key capture
void enableRawMode()
{
    version(Posix)
    {
        import core.sys.posix.termios;
        import core.sys.posix.unistd : STDIN_FILENO;
        
        termios raw;
        tcgetattr(STDIN_FILENO, &raw);
        raw.c_lflag &= ~(ICANON | ECHO);
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
    }
}

/// Restore terminal to normal mode
void disableRawMode()
{
    version(Posix)
    {
        import core.sys.posix.termios;
        import core.sys.posix.unistd : STDIN_FILENO;
        
        termios raw;
        tcgetattr(STDIN_FILENO, &raw);
        raw.c_lflag |= (ICANON | ECHO);
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
    }
}

