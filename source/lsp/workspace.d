module lsp.workspace;

import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import std.datetime;
import lsp.protocol;
import config.workspace.ast;
import config.parsing.lexer;
import config.interpretation.dsl;
import errors;
import utils.logging.logger;

/// Document state in workspace
struct Document
{
    string uri;
    string text;
    int version_;
    BuildFile ast;
    Token[] tokens;
    Diagnostic[] diagnostics;
    SysTime lastModified;
}

/// Workspace manager for LSP
/// Tracks open documents, ASTs, and provides query operations
class WorkspaceManager
{
    private Document[string] documents;
    private string rootUri;
    
    this(string rootUri)
    {
        this.rootUri = rootUri;
    }
    
    /// Open a document
    void openDocument(string uri, string text, int version_)
    {
        Document doc;
        doc.uri = uri;
        doc.text = text;
        doc.version_ = version_;
        doc.lastModified = Clock.currTime;
        
        // Parse document
        parseDocument(doc);
        
        documents[uri] = doc;
        Logger.debugLog("Opened document: " ~ uri);
    }
    
    /// Update document content
    void updateDocument(string uri, string text, int version_)
    {
        if (uri !in documents)
        {
            // Document not open, open it
            openDocument(uri, text, version_);
            return;
        }
        
        Document* doc = &documents[uri];
        doc.text = text;
        doc.version_ = version_;
        doc.lastModified = Clock.currTime;
        
        // Re-parse document
        parseDocument(*doc);
        
        Logger.debugLog("Updated document: " ~ uri);
    }
    
    /// Close a document
    void closeDocument(string uri)
    {
        documents.remove(uri);
        Logger.debugLog("Closed document: " ~ uri);
    }
    
    /// Get document by URI
    const(Document)* getDocument(string uri) const
    {
        auto doc = uri in documents;
        return doc;
    }
    
    /// Get all documents
    const(Document)[] getAllDocuments() const
    {
        return documents.values;
    }
    
    /// Get diagnostics for a document
    Diagnostic[] getDiagnostics(string uri) const
    {
        auto doc = getDocument(uri);
        if (doc is null)
            return [];
        return doc.diagnostics.dup;
    }
    
    /// Find target at position
    const(TargetDecl)* findTargetAtPosition(string uri, Position pos) const
    {
        auto doc = getDocument(uri);
        if (doc is null)
            return null;
        
        // Find target that contains this position
        foreach (ref target; doc.ast.targets)
        {
            if (target.line <= pos.line + 1)
            {
                // Check if position is within target body
                // (simplified - would need better range tracking)
                return &target;
            }
        }
        
        return null;
    }
    
    /// Find field at position
    const(Field)* findFieldAtPosition(string uri, Position pos) const
    {
        auto target = findTargetAtPosition(uri, pos);
        if (target is null)
            return null;
        
        // Find field at this line
        foreach (ref field; target.fields)
        {
            if (field.line == pos.line + 1)
                return &field;
        }
        
        return null;
    }
    
    /// Get all target names in workspace
    string[] getAllTargetNames() const
    {
        string[] names;
        foreach (doc; documents.values)
        {
            foreach (ref target; doc.ast.targets)
            {
                names ~= target.name;
            }
        }
        return names;
    }
    
    /// Find all references to a target
    Location[] findReferences(string targetName) const
    {
        Location[] locations;
        
        foreach (doc; documents.values)
        {
            // Find in dependencies
            foreach (ref target; doc.ast.targets)
            {
                auto depsField = target.getField("deps");
                if (depsField is null)
                    continue;
                
                // Check if this target references the target we're looking for
                if (depsField.value.kind == ExpressionValue.Kind.Array)
                {
                    auto arr = depsField.value.getArray();
                    if (arr !is null)
                    {
                        foreach (elem; arr.elements)
                        {
                            if (elem.kind == ExpressionValue.Kind.String)
                            {
                                auto str = elem.getString();
                                if (str !is null && str.value == targetName)
                                {
                                    // Found a reference
                                    Location loc;
                                    loc.uri = doc.uri;
                                    loc.range = Range(
                                        Position(cast(uint)(depsField.line - 1), 0),
                                        Position(cast(uint)(depsField.line - 1), 100)
                                    );
                                    locations ~= loc;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return locations;
    }
    
    /// Find definition of a target
    Location* findDefinition(string targetName) const
    {
        foreach (doc; documents.values)
        {
            foreach (ref target; doc.ast.targets)
            {
                if (target.name == targetName)
                {
                    auto loc = new Location;
                    loc.uri = doc.uri;
                    loc.range = Range(
                        Position(cast(uint)(target.line - 1), 0),
                        Position(cast(uint)(target.line - 1), cast(uint)target.name.length)
                    );
                    return loc;
                }
            }
        }
        
        return null;
    }
    
    private void parseDocument(ref Document doc)
    {
        // Clear previous diagnostics
        doc.diagnostics = [];
        
        // Tokenize
        auto lexer = Lexer(doc.text, uriToPath(doc.uri));
        auto tokenResult = lexer.tokenize();
        
        if (tokenResult.isErr)
        {
            // Lexer error
            auto error = tokenResult.unwrapErr();
            doc.diagnostics ~= buildErrorToDiagnostic(error);
            return;
        }
        
        doc.tokens = tokenResult.unwrap();
        
        // Parse
        auto parser = DSLParser(doc.tokens, uriToPath(doc.uri));
        auto parseResult = parser.parse();
        
        if (parseResult.isErr)
        {
            // Parser error
            auto error = parseResult.unwrapErr();
            doc.diagnostics ~= buildErrorToDiagnostic(error);
            return;
        }
        
        doc.ast = parseResult.unwrap();
        
        // Validate (basic checks)
        validateDocument(doc);
    }
    
    private void validateDocument(ref Document doc)
    {
        // Check for duplicate target names in same file
        bool[string] targetNames;
        
        foreach (ref target; doc.ast.targets)
        {
            if (target.name in targetNames)
            {
                Diagnostic diag;
                diag.severity = DiagnosticSeverity.Error;
                diag.message = "Duplicate target name: " ~ target.name;
                diag.range = Range(
                    Position(cast(uint)(target.line - 1), 0),
                    Position(cast(uint)(target.line - 1), 100)
                );
                diag.source = "builder-lsp";
                doc.diagnostics ~= diag;
            }
            targetNames[target.name] = true;
            
            // Validate required fields
            if (!target.hasField("type"))
            {
                Diagnostic diag;
                diag.severity = DiagnosticSeverity.Error;
                diag.message = "Missing required field 'type'";
                diag.range = Range(
                    Position(cast(uint)(target.line - 1), 0),
                    Position(cast(uint)(target.line - 1), 100)
                );
                diag.source = "builder-lsp";
                doc.diagnostics ~= diag;
            }
        }
    }
    
    private Diagnostic buildErrorToDiagnostic(BuildError error)
    {
        Diagnostic diag;
        diag.severity = DiagnosticSeverity.Error;
        diag.message = error.message;
        diag.source = "builder-lsp";
        
        // Try to get line information
        import errors.types.types : ParseError;
        if (auto parseError = cast(ParseError)error)
        {
            if (parseError.line > 0)
            {
                diag.range = Range(
                    Position(cast(uint)(parseError.line - 1), cast(uint)(parseError.column > 0 ? parseError.column - 1 : 0)),
                    Position(cast(uint)(parseError.line - 1), 100)
                );
            }
            else
            {
                diag.range = Range(Position(0, 0), Position(0, 100));
            }
        }
        else
        {
            diag.range = Range(Position(0, 0), Position(0, 100));
        }
        
        return diag;
    }
    
    private string uriToPath(string uri) const
    {
        if (uri.startsWith("file://"))
            return uri[7 .. $];
        return uri;
    }
    
    private string pathToUri(string path) const
    {
        return "file://" ~ path;
    }
}

