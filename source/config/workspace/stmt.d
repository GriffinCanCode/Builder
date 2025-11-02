module config.workspace.stmt;

import std.conv;
import std.algorithm;
import std.array;
import config.workspace.ast;
import config.workspace.expr;
import errors;

/// Statement node types for programmability features
/// 
/// This module defines AST nodes for statements in the Builder DSL:
/// - Variable declarations (let, const)
/// - Function definitions (fn)
/// - Macro definitions (macro)
/// - Control flow (if, for)
/// - Target declarations
/// - Expressions as statements

/// Base statement interface
interface Stmt
{
    /// Get statement type name for debugging
    string stmtType() const pure nothrow @safe;
    
    /// Get line number
    size_t line() const pure nothrow @nogc @safe;
    
    /// Get column number
    size_t column() const pure nothrow @nogc @safe;
}

/// Variable declaration (let or const)
class VarDecl : Stmt
{
    string name;
    Expr initializer;
    bool isConst;  // true for const, false for let
    size_t line_;
    size_t column_;
    
    this(string name, Expr initializer, bool isConst, size_t line, size_t column) pure nothrow @safe
    {
        this.name = name;
        this.initializer = initializer;
        this.isConst = isConst;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return isConst ? "ConstDecl" : "LetDecl"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Function parameter
struct Parameter
{
    string name;
    bool hasDefault;
    Expr defaultValue;
}

/// Function definition
class FunctionDecl : Stmt
{
    string name;
    Parameter[] parameters;
    Stmt[] body;
    size_t line_;
    size_t column_;
    
    this(string name, Parameter[] parameters, Stmt[] body, size_t line, size_t column) pure nothrow @safe
    {
        this.name = name;
        this.parameters = parameters;
        this.body = body;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return "FunctionDecl"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Macro definition
class MacroDecl : Stmt
{
    string name;
    string[] parameters;
    Stmt[] body;
    size_t line_;
    size_t column_;
    
    this(string name, string[] parameters, Stmt[] body, size_t line, size_t column) pure nothrow @safe
    {
        this.name = name;
        this.parameters = parameters;
        this.body = body;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return "MacroDecl"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// If statement
class IfStmt : Stmt
{
    Expr condition;
    Stmt[] thenBranch;
    Stmt[] elseBranch;
    size_t line_;
    size_t column_;
    
    this(Expr condition, Stmt[] thenBranch, Stmt[] elseBranch, size_t line, size_t column) pure nothrow @safe
    {
        this.condition = condition;
        this.thenBranch = thenBranch;
        this.elseBranch = elseBranch;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return "IfStmt"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// For loop statement
class ForStmt : Stmt
{
    string variable;
    Expr iterable;
    Stmt[] body;
    size_t line_;
    size_t column_;
    
    this(string variable, Expr iterable, Stmt[] body, size_t line, size_t column) pure nothrow @safe
    {
        this.variable = variable;
        this.iterable = iterable;
        this.body = body;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return "ForStmt"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Return statement
class ReturnStmt : Stmt
{
    Expr value;  // null for empty return
    size_t line_;
    size_t column_;
    
    this(Expr value, size_t line, size_t column) pure nothrow @safe
    {
        this.value = value;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return "ReturnStmt"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Import statement (for Tier 2 D macros)
class ImportStmt : Stmt
{
    string modulePath;
    size_t line_;
    size_t column_;
    
    this(string modulePath, size_t line, size_t column) pure nothrow @safe
    {
        this.modulePath = modulePath;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return "ImportStmt"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Target declaration statement
class TargetStmt : Stmt
{
    TargetDecl target;
    size_t line_;
    size_t column_;
    
    this(TargetDecl target, size_t line, size_t column) pure nothrow @safe
    {
        this.target = target;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return "TargetStmt"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Expression statement (expression evaluated for side effects)
class ExprStmt : Stmt
{
    Expr expression;
    size_t line_;
    size_t column_;
    
    this(Expr expression, size_t line, size_t column) pure nothrow @safe
    {
        this.expression = expression;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return "ExprStmt"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Block statement (scope)
class BlockStmt : Stmt
{
    Stmt[] statements;
    size_t line_;
    size_t column_;
    
    this(Stmt[] statements, size_t line, size_t column) pure nothrow @safe
    {
        this.statements = statements;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string stmtType() const pure nothrow @safe { return "BlockStmt"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Statement visitor pattern for extensible traversal
interface StmtVisitor(T)
{
    T visitVarDecl(VarDecl stmt);
    T visitFunctionDecl(FunctionDecl stmt);
    T visitMacroDecl(MacroDecl stmt);
    T visitIfStmt(IfStmt stmt);
    T visitForStmt(ForStmt stmt);
    T visitReturnStmt(ReturnStmt stmt);
    T visitImportStmt(ImportStmt stmt);
    T visitTargetStmt(TargetStmt stmt);
    T visitExprStmt(ExprStmt stmt);
    T visitBlockStmt(BlockStmt stmt);
}

/// Accept visitor method for double dispatch
T accept(T)(Stmt stmt, StmtVisitor!T visitor)
{
    if (auto varDecl = cast(VarDecl)stmt)
        return visitor.visitVarDecl(varDecl);
    else if (auto funcDecl = cast(FunctionDecl)stmt)
        return visitor.visitFunctionDecl(funcDecl);
    else if (auto macroDecl = cast(MacroDecl)stmt)
        return visitor.visitMacroDecl(macroDecl);
    else if (auto ifStmt = cast(IfStmt)stmt)
        return visitor.visitIfStmt(ifStmt);
    else if (auto forStmt = cast(ForStmt)stmt)
        return visitor.visitForStmt(forStmt);
    else if (auto returnStmt = cast(ReturnStmt)stmt)
        return visitor.visitReturnStmt(returnStmt);
    else if (auto importStmt = cast(ImportStmt)stmt)
        return visitor.visitImportStmt(importStmt);
    else if (auto targetStmt = cast(TargetStmt)stmt)
        return visitor.visitTargetStmt(targetStmt);
    else if (auto exprStmt = cast(ExprStmt)stmt)
        return visitor.visitExprStmt(exprStmt);
    else if (auto blockStmt = cast(BlockStmt)stmt)
        return visitor.visitBlockStmt(blockStmt);
    else
        assert(false, "Unknown statement type");
}

/// Pretty printer for debugging statements
class StmtPrinter : StmtVisitor!string
{
    private int indent;
    
    this() pure nothrow @safe
    {
        indent = 0;
    }
    
    string print(Stmt stmt)
    {
        return accept(stmt, this);
    }
    
    override string visitVarDecl(VarDecl stmt)
    {
        return spaces() ~ (stmt.isConst ? "const " : "let ") ~ stmt.name ~ " = ...";
    }
    
    override string visitFunctionDecl(FunctionDecl stmt)
    {
        auto params = stmt.parameters.map!(p => p.name).join(", ");
        return spaces() ~ "fn " ~ stmt.name ~ "(" ~ params ~ ") { ... }";
    }
    
    override string visitMacroDecl(MacroDecl stmt)
    {
        auto params = stmt.parameters.join(", ");
        return spaces() ~ "macro " ~ stmt.name ~ "(" ~ params ~ ") { ... }";
    }
    
    override string visitIfStmt(IfStmt stmt)
    {
        return spaces() ~ "if (...) { ... }" ~ (stmt.elseBranch.length > 0 ? " else { ... }" : "");
    }
    
    override string visitForStmt(ForStmt stmt)
    {
        return spaces() ~ "for " ~ stmt.variable ~ " in ... { ... }";
    }
    
    override string visitReturnStmt(ReturnStmt stmt)
    {
        return spaces() ~ "return" ~ (stmt.value ? " ..." : "");
    }
    
    override string visitImportStmt(ImportStmt stmt)
    {
        return spaces() ~ "import " ~ stmt.modulePath;
    }
    
    override string visitTargetStmt(TargetStmt stmt)
    {
        return spaces() ~ "target(\"" ~ stmt.target.name ~ "\") { ... }";
    }
    
    override string visitExprStmt(ExprStmt stmt)
    {
        return spaces() ~ "expr;";
    }
    
    override string visitBlockStmt(BlockStmt stmt)
    {
        return spaces() ~ "{ " ~ stmt.statements.length.to!string ~ " statements }";
    }
    
    private string spaces()
    {
        import std.range : repeat;
        import std.array : array;
        return "  ".repeat(indent).join();
    }
}

