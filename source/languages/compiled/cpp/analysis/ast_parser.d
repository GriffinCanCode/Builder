module languages.compiled.cpp.analysis.ast_parser;

import std.algorithm;
import std.array;
import std.conv : to;
import std.file;
import std.path;
import std.regex;
import std.string;
import std.datetime;
import engine.caching.incremental.ast_dependency;
import infrastructure.analysis.ast.parser;
import infrastructure.utils.files.hash;
import infrastructure.utils.logging.logger;
import infrastructure.errors;

/// C++ AST parser using regex-based pattern matching
/// Extracts classes, functions, methods, and their dependencies
final class CppASTParser : BaseASTParser
{
    // Regex patterns for C++ constructs
    private static Regex!char classPattern;
    private static Regex!char structPattern;
    private static Regex!char functionPattern;
    private static Regex!char methodPattern;
    private static Regex!char namespacePattern;
    private static Regex!char templatePattern;
    private static Regex!char includePattern;
    
    static this()
    {
        // Match class declarations
        classPattern = regex(r"^\s*class\s+(\w+)\s*(?::\s*(?:public|private|protected)\s+(\w+))?\s*\{?", "m");
        
        // Match struct declarations
        structPattern = regex(r"^\s*struct\s+(\w+)\s*(?::\s*(?:public|private|protected)\s+(\w+))?\s*\{?", "m");
        
        // Match standalone functions (not in class)
        functionPattern = regex(r"^\s*(?:(?:inline|static|extern|virtual)\s+)*(\w+(?:<[^>]+>)?)\s+(\w+)\s*\([^)]*\)\s*(?:const)?\s*(?:override)?\s*\{?", "m");
        
        // Match methods inside classes
        methodPattern = regex(r"^\s*(?:(?:public|private|protected):\s*)?(?:(?:inline|static|virtual)\s+)*(\w+(?:<[^>]+>)?)\s+(\w+)\s*\([^)]*\)\s*(?:const)?\s*(?:override)?\s*\{?", "m");
        
        // Match namespace declarations
        namespacePattern = regex(r"^\s*namespace\s+(\w+)\s*\{?", "m");
        
        // Match template declarations
        templatePattern = regex(r"^\s*template\s*<([^>]+)>", "m");
        
        // Match #include directives
        includePattern = regex(`^\s*#\s*include\s+[<"]([^>"]+)[>"]`, "m");
    }
    
    this() @safe
    {
        super("C++", [".cpp", ".cxx", ".cc", ".c++", ".C", ".h", ".hpp", ".hxx", ".h++"]);
    }
    
    override Result!(FileAST, BuildError) parseFile(string filePath) @system
    {
        if (!exists(filePath) || !isFile(filePath))
        {
            return Result!(FileAST, BuildError).err(
                new GenericError("File not found: " ~ filePath, ErrorCode.FileNotFound));
        }
        
        try
        {
            auto content = readText(filePath);
            return parseContent(content, filePath);
        }
        catch (Exception e)
        {
            return Result!(FileAST, BuildError).err(
                new GenericError("Failed to read file: " ~ filePath ~ " - " ~ e.msg,
                               ErrorCode.FileReadFailed));
        }
    }
    
    override Result!(FileAST, BuildError) parseContent(string content, string filePath) @system
    {
        try
        {
            FileAST ast;
            ast.filePath = filePath;
            ast.fileHash = FastHash.hashString(content);
            ast.timestamp = Clock.currTime();
            
            auto lines = content.split("\n");
            
            // Extract includes
            ast.includes = extractIncludes(content);
            
            // Extract symbols
            ast.symbols = extractSymbols(content, lines);
            
            Logger.debugLog("Parsed " ~ filePath ~ ": " ~ 
                          ast.symbols.length.to!string ~ " symbols, " ~
                          ast.includes.length.to!string ~ " includes");
            
            return Result!(FileAST, BuildError).ok(ast);
        }
        catch (Exception e)
        {
            return Result!(FileAST, BuildError).err(
                new GenericError("Failed to parse C++ file: " ~ filePath ~ " - " ~ e.msg,
                               ErrorCode.ParseFailed));
        }
    }
    
    /// Extract include directives
    private string[] extractIncludes(string content) @safe
    {
        string[] includes;
        
        foreach (match; matchAll(content, includePattern))
        {
            auto includePath = match[1].to!string;
            
            // Skip standard library headers
            if (!isStandardHeader(includePath))
                includes ~= includePath;
        }
        
        return includes;
    }
    
    /// Extract all symbols (classes, functions, etc.)
    private ASTSymbol[] extractSymbols(string content, string[] lines) @system
    {
        ASTSymbol[] symbols;
        
        // Remove comments to avoid false matches
        auto cleanContent = removeComments(content);
        auto cleanLines = cleanContent.split("\n");
        
        // Extract classes
        symbols ~= extractClasses(cleanContent, cleanLines);
        
        // Extract structs
        symbols ~= extractStructs(cleanContent, cleanLines);
        
        // Extract namespaces
        symbols ~= extractNamespaces(cleanContent, cleanLines);
        
        // Extract standalone functions (outside classes)
        symbols ~= extractFunctions(cleanContent, cleanLines);
        
        return symbols;
    }
    
    /// Extract class definitions
    private ASTSymbol[] extractClasses(string content, string[] lines) @system
    {
        ASTSymbol[] classes;
        
        foreach (match; matchAll(content, classPattern))
        {
            auto className = match[1].to!string;
            auto lineNum = findLineNumber(lines, match.pre.length + match[0].length);
            
            // Find class body bounds
            auto bounds = findBlockBounds(lines, lineNum);
            
            ASTSymbol symbol = makeSymbol(className, SymbolType.Class,
                                         lineNum, bounds.endLine);
            symbol.signature = match[0].to!string.strip;
            symbol.contentHash = hashSymbolContent(lines, lineNum, bounds.endLine);
            
            // Extract base class if present
            if (match[2].length > 0)
                symbol.dependencies ~= match[2].to!string;
            
            // Extract types used in class (simplified)
            symbol.usedTypes = extractUsedTypes(lines[lineNum-1..bounds.endLine]);
            
            classes ~= symbol;
            
            // Extract methods within this class
            classes ~= extractMethods(className, lines[lineNum-1..bounds.endLine], lineNum);
        }
        
        return classes;
    }
    
    /// Extract struct definitions
    private ASTSymbol[] extractStructs(string content, string[] lines) @system
    {
        ASTSymbol[] structs;
        
        foreach (match; matchAll(content, structPattern))
        {
            auto structName = match[1].to!string;
            auto lineNum = findLineNumber(lines, match.pre.length + match[0].length);
            
            auto bounds = findBlockBounds(lines, lineNum);
            
            ASTSymbol symbol = makeSymbol(structName, SymbolType.Struct,
                                         lineNum, bounds.endLine);
            symbol.signature = match[0].to!string.strip;
            symbol.contentHash = hashSymbolContent(lines, lineNum, bounds.endLine);
            
            if (match[2].length > 0)
                symbol.dependencies ~= match[2].to!string;
            
            symbol.usedTypes = extractUsedTypes(lines[lineNum-1..bounds.endLine]);
            
            structs ~= symbol;
        }
        
        return structs;
    }
    
    /// Extract namespace definitions
    private ASTSymbol[] extractNamespaces(string content, string[] lines) @system
    {
        ASTSymbol[] namespaces;
        
        foreach (match; matchAll(content, namespacePattern))
        {
            auto namespaceName = match[1].to!string;
            auto lineNum = findLineNumber(lines, match.pre.length + match[0].length);
            
            auto bounds = findBlockBounds(lines, lineNum);
            
            ASTSymbol symbol = makeSymbol(namespaceName, SymbolType.Namespace,
                                         lineNum, bounds.endLine);
            symbol.signature = match[0].to!string.strip;
            symbol.contentHash = hashSymbolContent(lines, lineNum, bounds.endLine);
            
            namespaces ~= symbol;
        }
        
        return namespaces;
    }
    
    /// Extract standalone functions
    private ASTSymbol[] extractFunctions(string content, string[] lines) @system
    {
        ASTSymbol[] functions;
        
        foreach (match; matchAll(content, functionPattern))
        {
            auto returnType = match[1].to!string;
            auto funcName = match[2].to!string;
            auto lineNum = findLineNumber(lines, match.pre.length + match[0].length);
            
            // Skip if this looks like it's inside a class (simple heuristic)
            if (isInsideClass(lines, lineNum))
                continue;
            
            auto bounds = findBlockBounds(lines, lineNum);
            
            ASTSymbol symbol = makeSymbol(funcName, SymbolType.Function,
                                         lineNum, bounds.endLine);
            symbol.signature = match[0].to!string.strip;
            symbol.contentHash = hashSymbolContent(lines, lineNum, bounds.endLine);
            symbol.usedTypes = [returnType] ~ extractUsedTypes(lines[lineNum-1..bounds.endLine]);
            
            functions ~= symbol;
        }
        
        return functions;
    }
    
    /// Extract methods within a class
    private ASTSymbol[] extractMethods(string className, string[] classLines, size_t baseLineNum) @system
    {
        ASTSymbol[] methods;
        auto classContent = classLines.join("\n");
        
        foreach (match; matchAll(classContent, methodPattern))
        {
            auto returnType = match[1].to!string;
            auto methodName = match[2].to!string;
            auto lineNum = findLineNumber(classLines, match.pre.length + match[0].length) + baseLineNum - 1;
            
            auto bounds = findBlockBounds(classLines, lineNum - baseLineNum + 1);
            auto endLineNum = bounds.endLine + baseLineNum - 1;
            
            ASTSymbol symbol = makeSymbol(className ~ "::" ~ methodName, SymbolType.Method,
                                         lineNum, endLineNum);
            symbol.signature = match[0].to!string.strip;
            symbol.contentHash = hashSymbolContent(classLines, 
                                                  lineNum - baseLineNum + 1,
                                                  bounds.endLine);
            symbol.dependencies ~= className;
            symbol.usedTypes = [returnType] ~ extractUsedTypes(classLines[lineNum-baseLineNum..bounds.endLine]);
            
            methods ~= symbol;
        }
        
        return methods;
    }
    
    /// Find line number from character offset
    private size_t findLineNumber(string[] lines, size_t offset) @safe
    {
        size_t currentOffset;
        foreach (i, line; lines)
        {
            currentOffset += line.length + 1; // +1 for newline
            if (currentOffset >= offset)
                return i + 1;
        }
        return lines.length;
    }
    
    /// Find block bounds (matching braces)
    private struct BlockBounds
    {
        size_t startLine;
        size_t endLine;
    }
    
    private BlockBounds findBlockBounds(string[] lines, size_t startLine) @safe
    {
        BlockBounds bounds;
        bounds.startLine = startLine;
        
        int braceCount;
        bool foundOpenBrace;
        
        for (size_t i = startLine - 1; i < lines.length; i++)
        {
            foreach (ch; lines[i])
            {
                if (ch == '{')
                {
                    braceCount++;
                    foundOpenBrace = true;
                }
                else if (ch == '}')
                {
                    braceCount--;
                    if (foundOpenBrace && braceCount == 0)
                    {
                        bounds.endLine = i + 1;
                        return bounds;
                    }
                }
            }
            
            // Handle single-line declarations without body
            if (!foundOpenBrace && lines[i].strip.endsWith(";"))
            {
                bounds.endLine = i + 1;
                return bounds;
            }
        }
        
        bounds.endLine = lines.length;
        return bounds;
    }
    
    /// Check if a line is inside a class definition
    private bool isInsideClass(string[] lines, size_t lineNum) @safe
    {
        if (lineNum == 0 || lineNum > lines.length)
            return false;
        
        // Count class/struct opens and closes before this line
        int classDepth;
        
        for (size_t i; i < lineNum - 1 && i < lines.length; i++)
        {
            auto line = lines[i];
            if (line.canFind("class ") || line.canFind("struct "))
                classDepth++;
            
            // Simple brace counting (imperfect but works for most cases)
            foreach (ch; line)
            {
                if (ch == '{' && classDepth > 0)
                    break;
                if (ch == '}' && classDepth > 0)
                    classDepth--;
            }
        }
        
        return classDepth > 0;
    }
    
    /// Extract types used in code block
    private string[] extractUsedTypes(string[] lines) @safe
    {
        string[] types;
        auto typePattern = regex(r"\b([A-Z]\w+(?:<[^>]+>)?)\b");
        
        foreach (line; lines)
        {
            foreach (match; matchAll(line, typePattern))
            {
                auto typeName = match[1].to!string;
                if (!types.canFind(typeName))
                    types ~= typeName;
            }
        }
        
        return types;
    }
    
    /// Remove C/C++ comments from source
    private string removeComments(string content) @safe
    {
        // Remove single-line comments
        auto noSingleLine = replaceAll(content, regex(r"//.*$", "m"), "");
        
        // Remove multi-line comments
        auto noMultiLine = replaceAll(noSingleLine, regex(r"/\*.*?\*/", "s"), "");
        
        return noMultiLine;
    }
    
    /// Check if header is a standard library header
    private bool isStandardHeader(string header) @safe
    {
        static immutable string[] stdHeaders = [
            "iostream", "vector", "string", "map", "set", "algorithm",
            "memory", "thread", "mutex", "atomic", "chrono", "functional",
            "stdio.h", "stdlib.h", "string.h", "math.h"
        ];
        
        return stdHeaders.canFind(baseName(header));
    }
}

