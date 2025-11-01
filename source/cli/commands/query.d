module cli.commands.query;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.regex;
import config.parsing.parser;
import config.schema.schema;
import core.graph.graph;
import core.services;
import utils.logging.logger;
import errors;

/// Query command - executes graph queries like "deps(//...)"
struct QueryCommand
{
    /// Execute a query
    static void execute(string queryExpression)
    {
        if (queryExpression.length == 0)
        {
            Logger.error("No query expression provided");
            showQueryHelp();
            return;
        }
        
        // Parse the workspace
        auto configResult = ConfigParser.parseWorkspace(".");
        if (configResult.isErr)
        {
            Logger.error("Failed to parse workspace configuration");
            import errors.formatting.format : format;
            Logger.error(format(configResult.unwrapErr()));
            return;
        }
        
        auto config = configResult.unwrap();
        
        // Create services and build graph
        auto services = new BuildServices(config, config.options);
        auto graph = services.analyzer.analyze("");
        
        // Parse and execute query
        auto queryResult = parseQuery(queryExpression);
        if (queryResult.isErr)
        {
            Logger.error("Invalid query: " ~ queryResult.unwrapErr());
            showQueryHelp();
            return;
        }
        
        auto query = queryResult.unwrap();
        auto results = executeQuery(query, graph);
        
        // Display results
        displayResults(results, query);
    }
    
    private static void showQueryHelp()
    {
        writeln();
        writeln("Query Syntax:");
        writeln("  //...                    All targets");
        writeln("  //path/...               All targets in path");
        writeln("  //path:target            Specific target");
        writeln("  deps(expr)               Direct dependencies of expr");
        writeln("  deps(expr, depth)        Dependencies up to depth");
        writeln("  rdeps(expr)              Reverse dependencies (what depends on expr)");
        writeln("  allpaths(from, to)       All paths between two targets");
        writeln("  kind(type, expr)         Filter by target type");
        writeln("  attr(name, value, expr)  Filter by attribute");
        writeln();
        writeln("Examples:");
        writeln("  builder query '//...'");
        writeln("  builder query 'deps(//src:app)'");
        writeln("  builder query 'rdeps(//lib:utils)'");
        writeln("  builder query 'kind(binary, //...)'");
        writeln();
    }
}

/// Query types
enum QueryType
{
    AllTargets,
    Targets,
    Dependencies,
    ReverseDependencies,
    AllPaths,
    Kind,
    Attr
}

/// Parsed query structure
struct Query
{
    QueryType type;
    string pattern;          // Target pattern (//path/to:target or //path/...)
    string[] args;           // Additional arguments
    int depth = -1;          // Depth limit (-1 = unlimited)
    Query* innerQuery;       // Nested query for functions like kind(type, expr)
}

/// Parse a query expression
Result!(Query, string) parseQuery(string expr) @safe
{
    expr = expr.strip();
    
    // Handle function queries: func(args)
    auto funcMatch = matchFirst(expr, regex(r"^(\w+)\((.*)\)$"));
    if (!funcMatch.empty)
    {
        string funcName = funcMatch[1];
        string funcArgs = funcMatch[2].strip();
        
        switch (funcName)
        {
            case "deps":
                return parseDepsQuery(funcArgs);
            case "rdeps":
                return parseRdepsQuery(funcArgs);
            case "allpaths":
                return parseAllPathsQuery(funcArgs);
            case "kind":
                return parseKindQuery(funcArgs);
            case "attr":
                return parseAttrQuery(funcArgs);
            default:
                return Result!(Query, string).err("Unknown query function: " ~ funcName);
        }
    }
    
    // Handle simple target patterns: //path/... or //path:target
    if (expr.startsWith("//"))
    {
        Query q;
        q.type = expr.endsWith("...") ? QueryType.AllTargets : QueryType.Targets;
        q.pattern = expr;
        return Result!(Query, string).ok(q);
    }
    
    return Result!(Query, string).err("Invalid query expression: " ~ expr);
}

/// Parse deps(expr) or deps(expr, depth)
Result!(Query, string) parseDepsQuery(string args) @safe
{
    auto parts = splitArgs(args);
    if (parts.length == 0)
        return Result!(Query, string).err("deps() requires at least one argument");
    
    auto innerResult = parseQuery(parts[0]);
    if (innerResult.isErr)
        return Result!(Query, string).err(innerResult.unwrapErr());
    
    Query q;
    q.type = QueryType.Dependencies;
    auto inner = innerResult.unwrap();
    q.innerQuery = new Query();
    *q.innerQuery = inner;
    
    if (parts.length > 1)
    {
        try {
            q.depth = parts[1].strip().to!int;
        } catch (Exception e) {
            return Result!(Query, string).err("Invalid depth value: " ~ parts[1]);
        }
    }
    
    return Result!(Query, string).ok(q);
}

/// Parse rdeps(expr)
Result!(Query, string) parseRdepsQuery(string args) @safe
{
    auto innerResult = parseQuery(args.strip());
    if (innerResult.isErr)
        return Result!(Query, string).err(innerResult.unwrapErr());
    
    Query q;
    q.type = QueryType.ReverseDependencies;
    auto inner = innerResult.unwrap();
    q.innerQuery = new Query();
    *q.innerQuery = inner;
    return Result!(Query, string).ok(q);
}

/// Parse allpaths(from, to)
Result!(Query, string) parseAllPathsQuery(string args) @safe
{
    auto parts = splitArgs(args);
    if (parts.length != 2)
        return Result!(Query, string).err("allpaths() requires exactly two arguments");
    
    Query q;
    q.type = QueryType.AllPaths;
    q.args = parts;
    return Result!(Query, string).ok(q);
}

/// Parse kind(type, expr)
Result!(Query, string) parseKindQuery(string args) @safe
{
    auto parts = splitArgs(args);
    if (parts.length != 2)
        return Result!(Query, string).err("kind() requires exactly two arguments");
    
    auto innerResult = parseQuery(parts[1]);
    if (innerResult.isErr)
        return Result!(Query, string).err(innerResult.unwrapErr());
    
    Query q;
    q.type = QueryType.Kind;
    q.pattern = parts[0].strip();  // The type to filter by
    auto inner = innerResult.unwrap();
    q.innerQuery = new Query();
    *q.innerQuery = inner;
    return Result!(Query, string).ok(q);
}

/// Parse attr(name, value, expr)
Result!(Query, string) parseAttrQuery(string args) @safe
{
    auto parts = splitArgs(args);
    if (parts.length != 3)
        return Result!(Query, string).err("attr() requires exactly three arguments");
    
    auto innerResult = parseQuery(parts[2]);
    if (innerResult.isErr)
        return Result!(Query, string).err(innerResult.unwrapErr());
    
    Query q;
    q.type = QueryType.Attr;
    q.args = [parts[0].strip(), parts[1].strip()];  // name, value
    auto inner = innerResult.unwrap();
    q.innerQuery = new Query();
    *q.innerQuery = inner;
    return Result!(Query, string).ok(q);
}

/// Split function arguments by comma (respecting nested parentheses)
string[] splitArgs(string args) @safe
{
    string[] result;
    string current;
    int parenDepth = 0;
    
    foreach (c; args)
    {
        if (c == '(' || c == '[' || c == '{')
            parenDepth++;
        else if (c == ')' || c == ']' || c == '}')
            parenDepth--;
        else if (c == ',' && parenDepth == 0)
        {
            result ~= current.strip();
            current = "";
            continue;
        }
        
        current ~= c;
    }
    
    if (current.strip().length > 0)
        result ~= current.strip();
    
    return result;
}

/// Execute a query on the graph
BuildNode[] executeQuery(Query query, BuildGraph graph) @trusted
{
    final switch (query.type)
    {
        case QueryType.AllTargets:
        case QueryType.Targets:
            return matchTargets(query.pattern, graph);
        
        case QueryType.Dependencies:
            auto targets = executeQuery(*query.innerQuery, graph);
            return getDependencies(targets, query.depth);
        
        case QueryType.ReverseDependencies:
            auto targets = executeQuery(*query.innerQuery, graph);
            return getReverseDependencies(targets);
        
        case QueryType.AllPaths:
            return getAllPaths(query.args[0], query.args[1], graph);
        
        case QueryType.Kind:
            auto targets = executeQuery(*query.innerQuery, graph);
            return filterByKind(targets, query.pattern);
        
        case QueryType.Attr:
            auto targets = executeQuery(*query.innerQuery, graph);
            return filterByAttr(targets, query.args[0], query.args[1]);
    }
}

/// Match targets by pattern
BuildNode[] matchTargets(string pattern, BuildGraph graph) @trusted
{
    BuildNode[] results;
    
    if (pattern == "//...")
    {
        // All targets
        foreach (node; graph.nodes.values)
            results ~= node;
    }
    else if (pattern.endsWith("..."))
    {
        // All targets in a path: //path/...
        string pathPrefix = pattern[0 .. $ - 3];  // Remove "..."
        foreach (node; graph.nodes.values)
        {
            if (node.id.startsWith(pathPrefix))
                results ~= node;
        }
    }
    else if (pattern.endsWith(":*"))
    {
        // All targets in a specific directory: //path:*
        string pathPrefix = pattern[0 .. $ - 1];  // Remove "*", keep ":"
        foreach (node; graph.nodes.values)
        {
            if (node.id.startsWith(pathPrefix))
                results ~= node;
        }
    }
    else
    {
        // Specific target: //path:target
        if (pattern in graph.nodes)
            results ~= graph.nodes[pattern];
    }
    
    return results;
}

/// Get dependencies of targets (up to depth)
BuildNode[] getDependencies(BuildNode[] targets, int depth) @trusted
{
    BuildNode[] results;
    bool[BuildNode] visited;
    
    void traverse(BuildNode node, int currentDepth)
    {
        if (node in visited)
            return;
        
        visited[node] = true;
        
        if (currentDepth > 0 || depth == -1)
        {
            foreach (dep; node.dependencies)
            {
                if (dep is null)
                    continue;
                
                results ~= dep;
                
                if (depth == -1 || currentDepth < depth)
                    traverse(dep, currentDepth + 1);
            }
        }
    }
    
    foreach (target; targets)
    {
        if (target !is null)
            traverse(target, 1);
    }
    
    return results;
}

/// Get reverse dependencies (what depends on these targets)
BuildNode[] getReverseDependencies(BuildNode[] targets) @trusted
{
    BuildNode[] results;
    bool[BuildNode] targetSet;
    
    // Build a set of target nodes for fast lookup
    foreach (target; targets)
    {
        if (target !is null)
            targetSet[target] = true;
    }
    
    // Find all nodes that depend on any of the targets
    foreach (target; targets)
    {
        if (target is null)
            continue;
        
        foreach (dependent; target.dependents)
        {
            if (dependent is null || dependent in targetSet)
                continue;
            
            results ~= dependent;
            targetSet[dependent] = true;  // Avoid duplicates
        }
    }
    
    return results;
}

/// Get all paths between two targets
BuildNode[] getAllPaths(string from, string to, BuildGraph graph) @trusted
{
    // Find paths using DFS
    BuildNode[] results;
    
    if (from !in graph.nodes || to !in graph.nodes)
        return results;
    
    auto fromNode = graph.nodes[from];
    auto toNode = graph.nodes[to];
    
    BuildNode[] currentPath;
    bool[BuildNode] visited;
    
    void dfs(BuildNode node)
    {
        if (node is null || node in visited)
            return;
        
        visited[node] = true;
        currentPath ~= node;
        
        if (node is toNode)
        {
            // Found a path - add all nodes in the path to results
            foreach (pathNode; currentPath)
            {
                if (!results.canFind(pathNode))
                    results ~= pathNode;
            }
        }
        else
        {
            foreach (dep; node.dependencies)
            {
                dfs(dep);
            }
        }
        
        currentPath = currentPath[0 .. $ - 1];
        visited.remove(node);
    }
    
    dfs(fromNode);
    return results;
}

/// Filter targets by kind (type)
BuildNode[] filterByKind(BuildNode[] targets, string kind) @trusted
{
    // Convert string to TargetType for comparison
    TargetType targetType;
    switch (kind.toLower())
    {
        case "executable":
        case "binary":
            targetType = TargetType.Executable;
            break;
        case "library":
        case "lib":
            targetType = TargetType.Library;
            break;
        case "test":
            targetType = TargetType.Test;
            break;
        case "custom":
            targetType = TargetType.Custom;
            break;
        default:
            return [];  // Unknown type, return empty
    }
    
    return targets.filter!(n => n !is null && n.target.type == targetType).array;
}

/// Filter targets by attribute
BuildNode[] filterByAttr(BuildNode[] targets, string attrName, string attrValue) @trusted
{
    return targets.filter!(n => 
        n !is null && 
        attrName in n.target.langConfig && 
        n.target.langConfig[attrName] == attrValue
    ).array;
}

/// Display query results
void displayResults(BuildNode[] results, Query query) @safe
{
    if (results.empty)
    {
        Logger.warning("No targets matched the query");
        return;
    }
    
    writeln();
    Logger.success("Query matched " ~ results.length.to!string ~ " target(s):\n");
    
    // Sort by target name for consistent output
    auto sorted = results.sort!((a, b) => a.id < b.id).array;
    
    foreach (node; sorted)
    {
        if (node is null)
            continue;
        
        writeln("  ", node.id);
        
        // Show additional details for non-list queries
        if (query.type != QueryType.AllTargets)
        {
            writeln("    Type: ", node.target.type);
            if (!node.dependencies.empty)
            {
                writeln("    Dependencies: ", node.dependencies.length);
            }
            if (!node.dependents.empty)
            {
                writeln("    Dependents: ", node.dependents.length);
            }
        }
    }
    
    writeln();
}

