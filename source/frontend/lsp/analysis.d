module frontend.lsp.analysis;

import std.algorithm;
import std.array;
import std.string;
import frontend.lsp.protocol;
import frontend.lsp.index;
import infrastructure.config.workspace.ast : BuildFile, TargetDeclStmt, Field, Expr, LiteralExpr, LiteralKind, ASTLocation = Location;
import infrastructure.config.schema.schema;

/// LSP semantic analyzer for Builderfiles
/// Performs deep validation beyond syntax checking
struct LSPSemanticAnalyzer
{
    private Index* index;
    
    this(Index* index)
    {
        this.index = index;
    }
    
    /// Analyze document and return semantic diagnostics
    Diagnostic[] analyze(string uri, const ref BuildFile ast)
    {
        Diagnostic[] diagnostics;
        
        foreach (ref target; ast.targets)
        {
            // Check for undefined dependencies
            auto depDiags = validateDependencies(uri, target);
            diagnostics ~= depDiags;
            
            // Check for type-specific validations
            auto typeDiags = validateTargetType(uri, target);
            diagnostics ~= typeDiags;
            
            // Validate sources exist (when possible)
            auto sourceDiags = validateSources(uri, target);
            diagnostics ~= sourceDiags;
        }
        
        // Check for cyclic dependencies
        auto cycleDiags = detectCyclicDependencies(uri, ast);
        diagnostics ~= cycleDiags;
        
        return diagnostics;
    }
    
    /// Validate all dependencies are defined
    private Diagnostic[] validateDependencies(string uri, const ref TargetDeclStmt target)
    {
        Diagnostic[] diagnostics;
        
        auto depsField = target.getField("deps");
        if (depsField is null)
            return diagnostics;
        
        // Check if value is a literal expression with array type
        auto litExpr = cast(const LiteralExpr)depsField.value;
        if (litExpr is null || litExpr.value.kind != LiteralKind.Array)
            return diagnostics;
        
        auto arr = litExpr.value.asArray();
        if (arr is null)
            return diagnostics;
        
        foreach (elem; arr)
        {
            if (elem.kind != LiteralKind.String)
                continue;
            
            auto str = elem.asString();
            
            string depName = str;
            
            // Normalize dependency name
            if (depName.startsWith(":"))
            {
                // Local dependency - extract target name
                depName = depName[1 .. $];
            }
            else if (depName.startsWith("//"))
            {
                // Absolute dependency - extract target part
                auto colonPos = depName.lastIndexOf(':');
                if (colonPos != -1)
                    depName = depName[colonPos + 1 .. $];
            }
            
            // Check if target exists in index
            if (!index.hasTarget(depName))
            {
                Diagnostic diag;
                diag.severity = DiagnosticSeverity.Error;
                diag.message = "Undefined target reference: " ~ str;
                diag.range = Range(
                    Position(cast(uint)(depsField.loc.line - 1), 0),
                    Position(cast(uint)(depsField.loc.line - 1), 100)
                );
                diag.source = "builder-lsp";
                diagnostics ~= diag;
            }
        }
        
        return diagnostics;
    }
    
    /// Validate target type requirements
    private Diagnostic[] validateTargetType(string uri, const ref TargetDeclStmt target)
    {
        Diagnostic[] diagnostics;
        
        import infrastructure.config.workspace.ast : IdentExpr;
        
        auto typeField = target.getField("type");
        if (typeField is null)
            return diagnostics; // Already validated in workspace.d
        
        auto sourcesField = target.getField("sources");
        
        // Executables and tests require sources
        auto identExpr = cast(const IdentExpr)typeField.value;
        if (identExpr !is null)
        {
            string typeName = identExpr.name;
            if ((typeName == "executable" || typeName == "test") && sourcesField is null)
            {
                Diagnostic diag;
                diag.severity = DiagnosticSeverity.Warning;
                diag.message = "Target of type '" ~ typeName ~ "' should have sources";
                diag.range = Range(
                    Position(cast(uint)(target.loc.line - 1), 0),
                    Position(cast(uint)(target.loc.line - 1), 50)
                );
                diag.source = "builder-lsp";
                diagnostics ~= diag;
            }
        }
        
        return diagnostics;
    }
    
    /// Validate sources (basic checks)
    private Diagnostic[] validateSources(string uri, const ref TargetDeclStmt target)
    {
        Diagnostic[] diagnostics;
        
        auto sourcesField = target.getField("sources");
        if (sourcesField is null)
            return diagnostics;
        
        auto litExpr = cast(const LiteralExpr)sourcesField.value;
        if (litExpr is null || litExpr.value.kind != LiteralKind.Array)
            return diagnostics;
        
        auto arr = litExpr.value.asArray();
        if (arr is null || arr.length == 0)
        {
            Diagnostic diag;
            diag.severity = DiagnosticSeverity.Warning;
            diag.message = "Target has empty sources array";
            diag.range = Range(
                Position(cast(uint)(sourcesField.loc.line - 1), 0),
                Position(cast(uint)(sourcesField.loc.line - 1), 100)
            );
            diag.source = "builder-lsp";
            diagnostics ~= diag;
        }
        
        return diagnostics;
    }
    
    /// Detect cyclic dependencies using DFS
    private Diagnostic[] detectCyclicDependencies(string uri, const ref BuildFile ast)
    {
        Diagnostic[] diagnostics;
        
        // Build local dependency graph
        string[][string] graph;
        TargetDeclStmt[string] targetMap;
        
        foreach (target; ast.targets)
        {
            targetMap[target.name] = target;
            
            auto depsField = target.getField("deps");
            if (depsField is null)
                continue;
            
            auto litExpr2 = cast(const LiteralExpr)depsField.value;
            if (litExpr2 is null || litExpr2.value.kind != LiteralKind.Array)
                continue;
            
            auto arr = litExpr2.value.asArray();
            if (arr is null)
                continue;
            
            string[] deps;
            foreach (elem; arr)
            {
                if (elem.kind == LiteralKind.String)
                {
                    auto str = elem.asString();
                    if (str !is null && str.length > 0)
                    {
                        string depName = str;
                        // Normalize for local check
                        if (depName.startsWith(":"))
                            depName = depName[1 .. $];
                        deps ~= depName;
                    }
                }
            }
            
            graph[target.name] = deps;
        }
        
        // DFS to detect cycles
        bool[string] visited;
        bool[string] inStack;
        
        bool hasCycle(string node, ref string[] path)
        {
            if (node in inStack)
            {
                // Found cycle
                return true;
            }
            
            if (node in visited)
                return false;
            
            visited[node] = true;
            inStack[node] = true;
            path ~= node;
            
            if (node in graph)
            {
                foreach (dep; graph[node])
                {
                    if (dep in targetMap && hasCycle(dep, path))
                        return true;
                }
            }
            
            inStack.remove(node);
            path = path[0 .. $ - 1];
            return false;
        }
        
        foreach (target; ast.targets)
        {
            if (target.name !in visited)
            {
                string[] path;
                if (hasCycle(target.name, path))
                {
                    Diagnostic diag;
                    diag.severity = DiagnosticSeverity.Error;
                    diag.message = "Cyclic dependency detected: " ~ path.join(" -> ");
                    diag.range = Range(
                        Position(cast(uint)(target.loc.line - 1), 0),
                        Position(cast(uint)(target.loc.line - 1), 50)
                    );
                    diag.source = "builder-lsp";
                    diagnostics ~= diag;
                    break; // Report first cycle only
                }
            }
        }
        
        return diagnostics;
    }
}

