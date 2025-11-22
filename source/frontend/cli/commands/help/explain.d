module frontend.cli.commands.help.explain;

import std.stdio;
import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import std.json;
import infrastructure.utils.logging.logger;
import frontend.cli.display.format;
import frontend.cli.control.terminal;

/// Explain command - AI-optimized documentation system
/// Provides instant, queryable documentation for AI assistants
struct ExplainCommand
{
    /// Execute explain command with subcommands
    static void execute(string[] args) @system
    {
        if (args.length < 2)
        {
            showUsage();
            return;
        }
        
        const subcommand = args[1];
        
        switch (subcommand)
        {
            case "list":
                listTopics();
                break;
            
            case "search":
                if (args.length < 3)
                {
                    Logger.error("Usage: builder explain search <query>");
                    return;
                }
                searchTopics(args[2 .. $].join(" "));
                break;
            
            case "example":
                if (args.length < 3)
                {
                    Logger.error("Usage: builder explain example <topic>");
                    return;
                }
                showExamples(args[2]);
                break;
            
            case "workflow":
                if (args.length < 3)
                {
                    Logger.error("Usage: builder explain workflow <workflow-name>");
                    return;
                }
                showWorkflow(args[2]);
                break;
            
            default:
                // Direct topic query
                showTopic(subcommand);
                break;
        }
    }
    
    /// Show usage information
    private static void showUsage() @system
    {
        writeln();
        Formatter.printHeader("Builder Explain - AI-Optimized Documentation");
        writeln();
        writeln("USAGE:");
        writeln("  builder explain <topic>              Show topic definition");
        writeln("  builder explain list                 List all available topics");
        writeln("  builder explain search <query>       Search across all topics");
        writeln("  builder explain example <topic>      Show working examples");
        writeln("  builder explain workflow <name>      Show step-by-step workflow");
        writeln();
        writeln("AVAILABLE TOPICS:");
        writeln("  blake3           BLAKE3 hash function - 3-5x faster than SHA-256");
        writeln("  caching          Multi-tier caching: target, action, remote");
        writeln("  determinism      Bit-for-bit reproducible builds");
        writeln("  incremental      Module-level incremental compilation");
        writeln("  action-cache     Fine-grained action caching");
        writeln("  remote-cache     Distributed cache for teams/CI");
        writeln();
        writeln("EXAMPLES:");
        writeln("  builder explain blake3");
        writeln("  builder explain search \"fast builds\"");
        writeln("  builder explain example caching");
        writeln();
    }
    
    /// List all available topics
    private static void listTopics() @system
    {
        auto indexPath = buildPath(getDocsPath(), "ai", "index.yaml");
        
        if (!exists(indexPath))
        {
            Logger.error("AI documentation index not found at: " ~ indexPath);
            return;
        }
        
        try
        {
            auto index = parseYAMLIndex(indexPath);
            
            writeln();
            Formatter.printHeader("Available Topics");
            writeln();
            
            if ("concepts" in index && index["concepts"].type == JSON_TYPE.OBJECT)
            {
                writeln(Formatter.bold("CONCEPTS:"));
                foreach (topic, data; index["concepts"].object)
                {
                    if (data.type == JSON_TYPE.OBJECT && "summary" in data)
                    {
                        writefln("  %-20s %s", 
                                Formatter.colorize(topic, Color.Cyan),
                                data["summary"].str);
                    }
                }
                writeln();
            }
        }
        catch (Exception e)
        {
            Logger.error("Failed to read index: " ~ e.msg);
        }
    }
    
    /// Search topics by keyword
    private static void searchTopics(string query) @system
    {
        auto indexPath = buildPath(getDocsPath(), "ai", "index.yaml");
        
        if (!exists(indexPath))
        {
            Logger.error("AI documentation index not found");
            return;
        }
        
        try
        {
            auto index = parseYAMLIndex(indexPath);
            auto queryLower = query.toLower();
            JSONValue[] matches;
            
            if ("concepts" in index && index["concepts"].type == JSON_TYPE.OBJECT)
            {
                foreach (topic, data; index["concepts"].object)
                {
                    if (data.type != JSON_TYPE.OBJECT) continue;
                    
                    bool match = topic.toLower().canFind(queryLower);
                    
                    if (!match && "summary" in data)
                        match = data["summary"].str.toLower().canFind(queryLower);
                    
                    if (!match && "keywords" in data && data["keywords"].type == JSON_TYPE.ARRAY)
                    {
                        foreach (keyword; data["keywords"].array)
                            if (keyword.str.toLower().canFind(queryLower))
                            {
                                match = true;
                                break;
                            }
                    }
                    
                    if (match)
                    {
                        auto matchData = data.object.dup;
                        matchData["topic"] = topic;
                        matches ~= JSONValue(matchData);
                    }
                }
            }
            
            writeln();
            if (matches.length == 0)
            {
                Logger.info("No topics found matching: " ~ query);
                writeln("\nTry: builder explain list");
            }
            else
            {
                Formatter.printHeader("Search Results for: " ~ query);
                writeln();
                foreach (match; matches)
                {
                    writefln("  %s", Formatter.colorize(match["topic"].str, Color.Cyan));
                    writefln("    %s", match["summary"].str);
                    writeln();
                }
                writefln("Found %d topic(s). Use 'builder explain <topic>' for details.", matches.length);
            }
        }
        catch (Exception e)
        {
            Logger.error("Search failed: " ~ e.msg);
        }
    }
    
    /// Show topic documentation
    private static void showTopic(string topic) @system
    {
        // Resolve aliases
        topic = resolveAlias(topic);
        
        const topicPath = buildPath(getDocsPath(), "ai", "concepts", topic ~ ".yaml");
        
        if (!exists(topicPath))
        {
            Logger.error("Topic not found: " ~ topic);
            writeln("\nAvailable topics:");
            writeln("  builder explain list");
            return;
        }
        
        try
        {
            auto content = readText(topicPath);
            auto doc = parseSimpleYAML(content);
            
            displayTopic(doc);
        }
        catch (Exception e)
        {
            Logger.error("Failed to read topic: " ~ e.msg);
        }
    }
    
    /// Show examples for a topic
    private static void showExamples(string topic) @system
    {
        topic = resolveAlias(topic);
        const topicPath = buildPath(getDocsPath(), "ai", "concepts", topic ~ ".yaml");
        
        if (!exists(topicPath))
        {
            Logger.error("Topic not found: " ~ topic);
            return;
        }
        
        try
        {
            auto content = readText(topicPath);
            auto doc = parseSimpleYAML(content);
            
            displayExamples(doc);
        }
        catch (Exception e)
        {
            Logger.error("Failed to read examples: " ~ e.msg);
        }
    }
    
    /// Show workflow documentation
    private static void showWorkflow(string workflow) @system
    {
        Logger.info("Workflows not yet implemented. Coming soon!");
        writeln("\nCurrently available: builder explain <topic>");
    }
    
    /// Display topic documentation
    private static void displayTopic(JSONValue doc) @system
    {
        writeln();
        
        if ("topic" in doc)
        {
            Formatter.printHeader(doc["topic"].str.toUpper());
            writeln();
        }
        
        if ("summary" in doc)
        {
            writeln(Formatter.bold("SUMMARY:"));
            writeln("  " ~ doc["summary"].str);
            writeln();
        }
        
        if ("definition" in doc)
        {
            writeln(Formatter.bold("DEFINITION:"));
            foreach (line; doc["definition"].str.split("\n"))
                if (line.strip().length > 0)
                    writeln("  " ~ line.strip());
            writeln();
        }
        
        if ("key_points" in doc && doc["key_points"].type == JSON_TYPE.ARRAY)
        {
            writeln(Formatter.bold("KEY POINTS:"));
            foreach (point; doc["key_points"].array)
                writeln("  • " ~ point.str);
            writeln();
        }
        
        if ("usage_examples" in doc && doc["usage_examples"].type == JSON_TYPE.ARRAY)
        {
            writeln(Formatter.bold("USAGE:"));
            foreach (example; doc["usage_examples"].array)
            {
                if (example.type == JSON_TYPE.OBJECT)
                {
                    if ("description" in example)
                        writeln("  " ~ example["description"].str ~ ":");
                    if ("code" in example)
                    {
                        foreach (line; example["code"].str.split("\n"))
                            if (line.strip().length > 0)
                                writeln("    " ~ line);
                        writeln();
                    }
                }
            }
        }
        
        if ("related" in doc && doc["related"].type == JSON_TYPE.ARRAY)
        {
            writeln(Formatter.bold("RELATED:"));
            auto related = doc["related"].array.map!(r => r.str).array;
            writeln("  " ~ related.join(", "));
            writeln();
        }
        
        if ("next_steps" in doc)
        {
            writeln(Formatter.bold("NEXT STEPS:"));
            foreach (line; doc["next_steps"].str.split("\n"))
                if (line.strip().length > 0)
                    writeln("  " ~ line.strip());
            writeln();
        }
    }
    
    /// Display examples section
    private static void displayExamples(JSONValue doc) @system
    {
        writeln();
        
        if ("topic" in doc)
        {
            Formatter.printHeader("Examples: " ~ doc["topic"].str);
            writeln();
        }
        
        if ("usage_examples" in doc && doc["usage_examples"].type == JSON_TYPE.ARRAY)
        {
            foreach (i, example; doc["usage_examples"].array)
            {
                if (example.type == JSON_TYPE.OBJECT)
                {
                    writefln(Formatter.bold("EXAMPLE %d:"), i + 1);
                    if ("description" in example)
                        writeln("  " ~ example["description"].str);
                    if ("command" in example)
                        writeln("  Command: " ~ Formatter.colorize(example["command"].str, Color.Green));
                    if ("code" in example)
                    {
                        writeln("  Code:");
                        foreach (line; example["code"].str.split("\n"))
                            if (line.strip().length > 0)
                                writeln("    " ~ line);
                    }
                    writeln();
                }
            }
        }
        else
        {
            Logger.info("No examples available for this topic.");
        }
    }
    
    /// Resolve topic alias
    private static string resolveAlias(string topic) @system
    {
        auto indexPath = buildPath(getDocsPath(), "ai", "index.yaml");
        
        if (!exists(indexPath))
            return topic;
        
        try
        {
            auto index = parseYAMLIndex(indexPath);
            
            if ("aliases" in index && index["aliases"].type == JSON_TYPE.OBJECT)
            {
                if (topic in index["aliases"].object)
                    return index["aliases"][topic].str;
            }
        }
        catch (Exception e)
        {
            // Ignore and return original topic
        }
        
        return topic;
    }
    
    /// Get documentation path
    private static string getDocsPath() @system
    {
        // Look for docs relative to current directory or workspace root
        if (exists("docs"))
            return "docs";
        
        // Try parent directories
        string current = getcwd();
        while (current.length > 1)
        {
            auto docsPath = buildPath(current, "docs");
            if (exists(docsPath))
                return docsPath;
            
            auto parent = dirName(current);
            if (parent == current)
                break;
            current = parent;
        }
        
        return "docs"; // Fallback
    }
    
    /// Parse YAML index file (simple implementation)
    private static JSONValue parseYAMLIndex(string path) @system
    {
        auto content = readText(path);
        return parseSimpleYAML(content);
    }
    
    /// Simple YAML parser for our specific format
    /// This is a minimal parser for the specific YAML structure we use
    private static JSONValue parseSimpleYAML(string content) @system
    {
        JSONValue result;
        result.object = null;
        
        string[] lines = content.split("\n");
        JSONValue* currentSection = &result;
        string[] sectionStack;
        int[] indentStack = [0];
        
        foreach (line; lines)
        {
            if (line.strip().length == 0 || line.strip().startsWith("#"))
                continue;
            
            auto indent = line.length - line.stripLeft().length;
            auto stripped = line.strip();
            
            if (stripped.endsWith(":"))
            {
                // Section or key
                auto key = stripped[0 .. $ - 1];
                
                if (indent <= indentStack[$ - 1] && sectionStack.length > 0)
                {
                    // Pop stack
                    while (indentStack.length > 1 && indent <= indentStack[$ - 1])
                    {
                        sectionStack = sectionStack[0 .. $ - 1];
                        indentStack = indentStack[0 .. $ - 1];
                        currentSection = navigateToSection(&result, sectionStack);
                    }
                }
                
                (*currentSection).object[key] = JSONValue();
                (*currentSection)[key].object = null;
                
                sectionStack ~= key;
                indentStack ~= indent;
                currentSection = &(*currentSection)[key];
            }
            else if (stripped.startsWith("- "))
            {
                // Array item
                auto value = stripped[2 .. $].strip();
                
                if (value.startsWith("\"") && value.endsWith("\""))
                    value = value[1 .. $ - 1];
                
                if ((*currentSection).type != JSON_TYPE.ARRAY)
                    (*currentSection).array = null;
                
                (*currentSection).array ~= JSONValue(value);
            }
            else if (stripped.canFind(": "))
            {
                // Key-value pair
                auto parts = stripped.split(": ");
                if (parts.length >= 2)
                {
                    auto key = parts[0].strip();
                    auto value = parts[1 .. $].join(": ").strip();
                    
                    // Handle multiline strings (|)
                    if (value == "|")
                    {
                        (*currentSection).object[key] = JSONValue("");
                        continue;
                    }
                    
                    if (value.startsWith("\"") && value.endsWith("\""))
                        value = value[1 .. $ - 1];
                    
                    (*currentSection).object[key] = JSONValue(value);
                }
            }
        }
        
        return result;
    }
    
    /// Navigate to a section in nested JSON
    private static JSONValue* navigateToSection(JSONValue* root, string[] path) @system
    {
        JSONValue* current = root;
        foreach (segment; path)
        {
            if (segment in current.object)
                current = &(*current)[segment];
            else
                return root;
        }
        return current;
    }
}

