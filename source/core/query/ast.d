module core.query.ast;

/// Abstract Syntax Tree for bldrquery DSL
/// Immutable, composable query expressions

/// Query expression node (sum type pattern)
interface QueryExpr
{
    /// Accept visitor pattern for traversal
    void accept(QueryVisitor visitor);
}

/// Visitor interface for AST traversal
interface QueryVisitor
{
    void visit(TargetPattern node);
    void visit(DepsExpr node);
    void visit(RdepsExpr node);
    void visit(AllPathsExpr node);
    void visit(SomePathExpr node);
    void visit(ShortestPathExpr node);
    void visit(KindExpr node);
    void visit(AttrExpr node);
    void visit(FilterExpr node);
    void visit(SiblingsExpr node);
    void visit(BuildFilesExpr node);
    void visit(UnionExpr node);
    void visit(IntersectExpr node);
    void visit(ExceptExpr node);
    void visit(LetExpr node);
}

/// Target pattern: //path/..., //path:target, //path:*
final class TargetPattern : QueryExpr
{
    string pattern;
    
    this(string pattern) pure nothrow @safe
    {
        this.pattern = pattern;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// deps(expr) or deps(expr, depth)
final class DepsExpr : QueryExpr
{
    QueryExpr inner;
    int depth = -1;  // -1 = unlimited
    
    this(QueryExpr inner, int depth = -1) pure nothrow @safe
    {
        this.inner = inner;
        this.depth = depth;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// rdeps(expr) - reverse dependencies
final class RdepsExpr : QueryExpr
{
    QueryExpr inner;
    int depth = -1;  // -1 = unlimited
    
    this(QueryExpr inner, int depth = -1) pure nothrow @safe
    {
        this.inner = inner;
        this.depth = depth;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// allpaths(from, to) - all paths between targets
final class AllPathsExpr : QueryExpr
{
    QueryExpr from;
    QueryExpr to;
    
    this(QueryExpr from, QueryExpr to) pure nothrow @safe
    {
        this.from = from;
        this.to = to;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// somepath(from, to) - any single path
final class SomePathExpr : QueryExpr
{
    QueryExpr from;
    QueryExpr to;
    
    this(QueryExpr from, QueryExpr to) pure nothrow @safe
    {
        this.from = from;
        this.to = to;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// shortest(from, to) - shortest path
final class ShortestPathExpr : QueryExpr
{
    QueryExpr from;
    QueryExpr to;
    
    this(QueryExpr from, QueryExpr to) pure nothrow @safe
    {
        this.from = from;
        this.to = to;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// kind(type, expr) - filter by target type
final class KindExpr : QueryExpr
{
    string kind;
    QueryExpr inner;
    
    this(string kind, QueryExpr inner) pure nothrow @safe
    {
        this.kind = kind;
        this.inner = inner;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// attr(name, value, expr) - filter by attribute
final class AttrExpr : QueryExpr
{
    string name;
    string value;
    QueryExpr inner;
    
    this(string name, string value, QueryExpr inner) pure nothrow @safe
    {
        this.name = name;
        this.value = value;
        this.inner = inner;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// filter(attr, regex, expr) - regex-based filtering
final class FilterExpr : QueryExpr
{
    string attribute;
    string regex;
    QueryExpr inner;
    
    this(string attribute, string regex, QueryExpr inner) pure nothrow @safe
    {
        this.attribute = attribute;
        this.regex = regex;
        this.inner = inner;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// siblings(target) - targets in same directory
final class SiblingsExpr : QueryExpr
{
    QueryExpr inner;
    
    this(QueryExpr inner) pure nothrow @safe
    {
        this.inner = inner;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// buildfiles(pattern) - find Builderfile files
final class BuildFilesExpr : QueryExpr
{
    string pattern;
    
    this(string pattern) pure nothrow @safe
    {
        this.pattern = pattern;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// expr1 + expr2 - union
final class UnionExpr : QueryExpr
{
    QueryExpr left;
    QueryExpr right;
    
    this(QueryExpr left, QueryExpr right) pure nothrow @safe
    {
        this.left = left;
        this.right = right;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// expr1 & expr2 - intersection
final class IntersectExpr : QueryExpr
{
    QueryExpr left;
    QueryExpr right;
    
    this(QueryExpr left, QueryExpr right) pure nothrow @safe
    {
        this.left = left;
        this.right = right;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// expr1 - expr2 - set difference
final class ExceptExpr : QueryExpr
{
    QueryExpr left;
    QueryExpr right;
    
    this(QueryExpr left, QueryExpr right) pure nothrow @safe
    {
        this.left = left;
        this.right = right;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

/// let(var, expr) - variable binding
final class LetExpr : QueryExpr
{
    string variable;
    QueryExpr value;
    QueryExpr body;
    
    this(string variable, QueryExpr value, QueryExpr body) pure nothrow @safe
    {
        this.variable = variable;
        this.value = value;
        this.body = body;
    }
    
    override void accept(QueryVisitor visitor)
    {
        visitor.visit(this);
    }
}

