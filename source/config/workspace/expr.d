module config.workspace.expr;

import std.conv;
import std.algorithm;
import std.array;
import config.workspace.ast;
import errors;

/// Expression node types for programmability features
/// 
/// This module defines AST nodes for expressions in the Builder DSL:
/// - Binary operations (+, -, *, /, %, ==, !=, <, >, <=, >=, &&, ||)
/// - Unary operations (-, !)
/// - Function calls
/// - Array/map indexing
/// - Member access
/// - Ternary operator

/// Base expression interface
interface Expr
{
    /// Get expression type name for debugging
    string exprType() const pure nothrow @safe;
    
    /// Get line number
    size_t line() const pure nothrow @nogc @safe;
    
    /// Get column number
    size_t column() const pure nothrow @nogc @safe;
}

/// Binary operation expression
class BinaryExpr : Expr
{
    Expr left;
    string operator;
    Expr right;
    size_t line_;
    size_t column_;
    
    this(Expr left, string operator, Expr right, size_t line, size_t column) pure nothrow @safe
    {
        this.left = left;
        this.operator = operator;
        this.right = right;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "BinaryExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Unary operation expression
class UnaryExpr : Expr
{
    string operator;
    Expr operand;
    size_t line_;
    size_t column_;
    
    this(string operator, Expr operand, size_t line, size_t column) pure nothrow @safe
    {
        this.operator = operator;
        this.operand = operand;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "UnaryExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Function call expression
class CallExpr : Expr
{
    string callee;  // Function name
    Expr[] arguments;
    size_t line_;
    size_t column_;
    
    this(string callee, Expr[] arguments, size_t line, size_t column) pure nothrow @safe
    {
        this.callee = callee;
        this.arguments = arguments;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "CallExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Index expression (array[index] or map[key])
class IndexExpr : Expr
{
    Expr object;
    Expr index;
    size_t line_;
    size_t column_;
    
    this(Expr object, Expr index, size_t line, size_t column) pure nothrow @safe
    {
        this.object = object;
        this.index = index;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "IndexExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Slice expression (array[start:end])
class SliceExpr : Expr
{
    Expr object;
    Expr start;  // null for [:end]
    Expr end;    // null for [start:]
    size_t line_;
    size_t column_;
    
    this(Expr object, Expr start, Expr end, size_t line, size_t column) pure nothrow @safe
    {
        this.object = object;
        this.start = start;
        this.end = end;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "SliceExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Member access expression (object.member)
class MemberExpr : Expr
{
    Expr object;
    string member;
    size_t line_;
    size_t column_;
    
    this(Expr object, string member, size_t line, size_t column) pure nothrow @safe
    {
        this.object = object;
        this.member = member;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "MemberExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Ternary operator expression (condition ? trueExpr : falseExpr)
class TernaryExpr : Expr
{
    Expr condition;
    Expr trueExpr;
    Expr falseExpr;
    size_t line_;
    size_t column_;
    
    this(Expr condition, Expr trueExpr, Expr falseExpr, size_t line, size_t column) pure nothrow @safe
    {
        this.condition = condition;
        this.trueExpr = trueExpr;
        this.falseExpr = falseExpr;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "TernaryExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Literal expression (wraps existing ExpressionValue from AST)
class LiteralExpr : Expr
{
    ExpressionValue value;
    size_t line_;
    size_t column_;
    
    this(ExpressionValue value, size_t line, size_t column) pure nothrow @safe
    {
        this.value = value;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "LiteralExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Lambda/closure expression (for filter, map, etc.)
class LambdaExpr : Expr
{
    string[] parameters;
    Expr body;  // Single expression body
    size_t line_;
    size_t column_;
    
    this(string[] parameters, Expr body, size_t line, size_t column) pure nothrow @safe
    {
        this.parameters = parameters;
        this.body = body;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "LambdaExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Assignment expression (variable = value)
class AssignExpr : Expr
{
    string name;
    Expr value;
    size_t line_;
    size_t column_;
    
    this(string name, Expr value, size_t line, size_t column) pure nothrow @safe
    {
        this.name = name;
        this.value = value;
        this.line_ = line;
        this.column_ = column;
    }
    
    override string exprType() const pure nothrow @safe { return "AssignExpr"; }
    override size_t line() const pure nothrow @nogc @safe { return line_; }
    override size_t column() const pure nothrow @nogc @safe { return column_; }
}

/// Expression visitor pattern for extensible traversal
interface ExprVisitor(T)
{
    T visitBinaryExpr(BinaryExpr expr);
    T visitUnaryExpr(UnaryExpr expr);
    T visitCallExpr(CallExpr expr);
    T visitIndexExpr(IndexExpr expr);
    T visitSliceExpr(SliceExpr expr);
    T visitMemberExpr(MemberExpr expr);
    T visitTernaryExpr(TernaryExpr expr);
    T visitLiteralExpr(LiteralExpr expr);
    T visitLambdaExpr(LambdaExpr expr);
    T visitAssignExpr(AssignExpr expr);
}

/// Accept visitor method for double dispatch
T accept(T)(Expr expr, ExprVisitor!T visitor)
{
    if (auto binaryExpr = cast(BinaryExpr)expr)
        return visitor.visitBinaryExpr(binaryExpr);
    else if (auto unaryExpr = cast(UnaryExpr)expr)
        return visitor.visitUnaryExpr(unaryExpr);
    else if (auto callExpr = cast(CallExpr)expr)
        return visitor.visitCallExpr(callExpr);
    else if (auto indexExpr = cast(IndexExpr)expr)
        return visitor.visitIndexExpr(indexExpr);
    else if (auto sliceExpr = cast(SliceExpr)expr)
        return visitor.visitSliceExpr(sliceExpr);
    else if (auto memberExpr = cast(MemberExpr)expr)
        return visitor.visitMemberExpr(memberExpr);
    else if (auto ternaryExpr = cast(TernaryExpr)expr)
        return visitor.visitTernaryExpr(ternaryExpr);
    else if (auto literalExpr = cast(LiteralExpr)expr)
        return visitor.visitLiteralExpr(literalExpr);
    else if (auto lambdaExpr = cast(LambdaExpr)expr)
        return visitor.visitLambdaExpr(lambdaExpr);
    else if (auto assignExpr = cast(AssignExpr)expr)
        return visitor.visitAssignExpr(assignExpr);
    else
        assert(false, "Unknown expression type");
}

/// Pretty printer for debugging expressions
class ExprPrinter : ExprVisitor!string
{
    string print(Expr expr)
    {
        return accept(expr, this);
    }
    
    override string visitBinaryExpr(BinaryExpr expr)
    {
        return "(" ~ print(expr.left) ~ " " ~ expr.operator ~ " " ~ print(expr.right) ~ ")";
    }
    
    override string visitUnaryExpr(UnaryExpr expr)
    {
        return "(" ~ expr.operator ~ print(expr.operand) ~ ")";
    }
    
    override string visitCallExpr(CallExpr expr)
    {
        auto args = expr.arguments.map!(a => print(a)).join(", ");
        return expr.callee ~ "(" ~ args ~ ")";
    }
    
    override string visitIndexExpr(IndexExpr expr)
    {
        return print(expr.object) ~ "[" ~ print(expr.index) ~ "]";
    }
    
    override string visitSliceExpr(SliceExpr expr)
    {
        string start = expr.start ? print(expr.start) : "";
        string end = expr.end ? print(expr.end) : "";
        return print(expr.object) ~ "[" ~ start ~ ":" ~ end ~ "]";
    }
    
    override string visitMemberExpr(MemberExpr expr)
    {
        return print(expr.object) ~ "." ~ expr.member;
    }
    
    override string visitTernaryExpr(TernaryExpr expr)
    {
        return "(" ~ print(expr.condition) ~ " ? " ~ print(expr.trueExpr) ~ " : " ~ print(expr.falseExpr) ~ ")";
    }
    
    override string visitLiteralExpr(LiteralExpr expr)
    {
        final switch (expr.value.kind)
        {
            case ExpressionValue.Kind.String:
                return `"` ~ expr.value.stringValue.value ~ `"`;
            case ExpressionValue.Kind.Number:
                return expr.value.numberValue.value.to!string;
            case ExpressionValue.Kind.Identifier:
                return expr.value.identifierValue.name;
            case ExpressionValue.Kind.Array:
                auto elements = expr.value.arrayValue.elements.map!(e => 
                    print(new LiteralExpr(e, expr.line_, expr.column_))
                ).join(", ");
                return "[" ~ elements ~ "]";
            case ExpressionValue.Kind.Map:
                string[] pairs;
                foreach (key, value; expr.value.mapValue.pairs)
                {
                    pairs ~= key ~ ": " ~ print(new LiteralExpr(value, expr.line_, expr.column_));
                }
                return "{" ~ pairs.join(", ") ~ "}";
        }
    }
    
    override string visitLambdaExpr(LambdaExpr expr)
    {
        auto params = expr.parameters.join(", ");
        return "|" ~ params ~ "| " ~ print(expr.body);
    }
    
    override string visitAssignExpr(AssignExpr expr)
    {
        return expr.name ~ " = " ~ print(expr.value);
    }
}

