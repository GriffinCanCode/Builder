module infrastructure.config.caching.schema;

import infrastructure.utils.serialization;

/// Serializable location for AST nodes
@Serializable(SchemaVersion(1, 0))
struct SerializableLocation
{
    @Field(1) string file;
    @Field(2) @Packed ulong line;
    @Field(3) @Packed ulong column;
}

/// Serializable literal value for AST
@Serializable(SchemaVersion(1, 0))
struct SerializableLiteral
{
    @Field(1) uint kind;  // LiteralKind enum
    @Field(2) @Optional bool boolValue;
    @Field(3) @Optional @Packed long numberValue;
    @Field(4) @Optional string stringValue;
    @Field(5) @Optional SerializableLiteral[] arrayValue;
    @Field(6) @Optional string[] mapKeys;
    @Field(7) @Optional SerializableLiteral[] mapValues;
}

/// Expression type discriminator
enum ExprType : uint
{
    Literal = 0,
    Ident = 1,
    Binary = 2,
    Unary = 3,
    Call = 4,
    Index = 5,
    Slice = 6,
    Member = 7,
    Ternary = 8,
    Lambda = 9
}

/// Serializable expression for AST
@Serializable(SchemaVersion(1, 0))
struct SerializableExpr
{
    @Field(1) uint exprType;  // ExprType enum
    @Field(2) SerializableLocation loc;
    
    // Literal
    @Field(3) @Optional SerializableLiteral literal;
    
    // Ident
    @Field(4) @Optional string identifier;
    
    // Binary
    @Field(5) @Optional SerializableExpr* left;
    @Field(6) @Optional SerializableExpr* right;
    @Field(7) @Optional string binaryOp;
    
    // Unary
    @Field(8) @Optional SerializableExpr* operand;
    @Field(9) @Optional string unaryOp;
    
    // Call
    @Field(10) @Optional string callee;
    @Field(11) @Optional SerializableExpr[] arguments;
    
    // Index
    @Field(12) @Optional SerializableExpr* object;
    @Field(13) @Optional SerializableExpr* index;
    
    // Slice
    @Field(14) @Optional SerializableExpr* sliceStart;
    @Field(15) @Optional SerializableExpr* sliceEnd;
    
    // Member
    @Field(16) @Optional string member;
    
    // Ternary
    @Field(17) @Optional SerializableExpr* condition;
    @Field(18) @Optional SerializableExpr* trueExpr;
    @Field(19) @Optional SerializableExpr* falseExpr;
    
    // Lambda
    @Field(20) @Optional string[] lambdaParams;
    @Field(21) @Optional SerializableExpr* lambdaBody;
}

/// Serializable field for target declaration
@Serializable(SchemaVersion(1, 0))
struct SerializableField
{
    @Field(1) string name;
    @Field(2) SerializableLocation loc;
    @Field(3) SerializableExpr value;
}

/// Serializable target declaration
@Serializable(SchemaVersion(1, 0))
struct SerializableTarget
{
    @Field(1) string name;
    @Field(2) SerializableLocation loc;
    @Field(3) SerializableField[] fields;
}

/// Serializable BuildFile AST
/// Schema version 1.0 - initial release
@Serializable(SchemaVersion(1, 0), 0x41535443) // "ASTC" - AST Cache
struct SerializableBuildFile
{
    @Field(1) string filePath;
    @Field(2) SerializableTarget[] targets;
}

/// Convert from runtime Location to serializable format
SerializableLocation toSerializableLocation(T)(auto ref const T loc) @trusted
{
    SerializableLocation serializable;
    serializable.file = loc.file;
    serializable.line = loc.line;
    serializable.column = loc.column;
    return serializable;
}

/// Convert from runtime Literal to serializable format
SerializableLiteral toSerializableLiteral(T)(auto ref const T literal) @trusted
{
    SerializableLiteral serializable;
    serializable.kind = cast(uint)literal.kind;
    
    import std.traits : hasMember;
    
    // Handle different literal types
    switch (literal.kind)
    {
        case 0: // Null
            break;
        case 1: // Bool
            static if (hasMember!(T, "asBool"))
                serializable.boolValue = literal.asBool();
            break;
        case 2: // Number
            static if (hasMember!(T, "asNumber"))
                serializable.numberValue = literal.asNumber();
            break;
        case 3: // String
            static if (hasMember!(T, "asString"))
                serializable.stringValue = literal.asString();
            break;
        case 4: // Array
            static if (hasMember!(T, "asArray"))
            {
                foreach (elem; literal.asArray())
                    serializable.arrayValue ~= toSerializableLiteral(elem);
            }
            break;
        case 5: // Map
            static if (hasMember!(T, "asMap"))
            {
                foreach (k, v; literal.asMap())
                {
                    serializable.mapKeys ~= k;
                    serializable.mapValues ~= toSerializableLiteral(v);
                }
            }
            break;
        default:
            break;
    }
    
    return serializable;
}

/// Convert from runtime Expr to serializable format
SerializableExpr toSerializableExpr(Expr expr) @trusted
{
    import infrastructure.config.workspace.ast;
    
    SerializableExpr serializable;
    serializable.loc = toSerializableLocation(expr.location());
    
    // Handle each expression type
    if (auto lit = cast(LiteralExpr)expr)
    {
        serializable.exprType = ExprType.Literal;
        serializable.literal = toSerializableLiteral(lit.value);
    }
    else if (auto ident = cast(IdentExpr)expr)
    {
        serializable.exprType = ExprType.Ident;
        serializable.identifier = ident.name;
    }
    else if (auto bin = cast(BinaryExpr)expr)
    {
        serializable.exprType = ExprType.Binary;
        serializable.binaryOp = bin.op;
        serializable.left = new SerializableExpr(toSerializableExpr(bin.left));
        serializable.right = new SerializableExpr(toSerializableExpr(bin.right));
    }
    else if (auto unary = cast(UnaryExpr)expr)
    {
        serializable.exprType = ExprType.Unary;
        serializable.unaryOp = unary.op;
        serializable.operand = new SerializableExpr(toSerializableExpr(unary.operand));
    }
    else if (auto call = cast(CallExpr)expr)
    {
        serializable.exprType = ExprType.Call;
        serializable.callee = call.callee;
        foreach (arg; call.args)
            serializable.arguments ~= toSerializableExpr(arg);
    }
    else if (auto index = cast(IndexExpr)expr)
    {
        serializable.exprType = ExprType.Index;
        serializable.object = new SerializableExpr(toSerializableExpr(index.object));
        serializable.index = new SerializableExpr(toSerializableExpr(index.index));
    }
    else if (auto slice = cast(SliceExpr)expr)
    {
        serializable.exprType = ExprType.Slice;
        serializable.object = new SerializableExpr(toSerializableExpr(slice.object));
        if (slice.start)
            serializable.sliceStart = new SerializableExpr(toSerializableExpr(slice.start));
        if (slice.end)
            serializable.sliceEnd = new SerializableExpr(toSerializableExpr(slice.end));
    }
    else if (auto member = cast(MemberExpr)expr)
    {
        serializable.exprType = ExprType.Member;
        serializable.object = new SerializableExpr(toSerializableExpr(member.object));
        serializable.member = member.member;
    }
    else if (auto ternary = cast(TernaryExpr)expr)
    {
        serializable.exprType = ExprType.Ternary;
        serializable.condition = new SerializableExpr(toSerializableExpr(ternary.condition));
        serializable.trueExpr = new SerializableExpr(toSerializableExpr(ternary.trueExpr));
        serializable.falseExpr = new SerializableExpr(toSerializableExpr(ternary.falseExpr));
    }
    else if (auto lambda = cast(LambdaExpr)expr)
    {
        serializable.exprType = ExprType.Lambda;
        serializable.lambdaParams = lambda.params.dup;
        serializable.lambdaBody = new SerializableExpr(toSerializableExpr(lambda.body));
    }
    
    return serializable;
}

/// Convert from runtime Field to serializable format
SerializableField toSerializableField(T)(auto ref const T field) @trusted
{
    SerializableField serializable;
    serializable.name = field.name;
    serializable.loc = toSerializableLocation(field.loc);
    serializable.value = toSerializableExpr(field.value);
    return serializable;
}

/// Convert from runtime TargetDeclStmt to serializable format
SerializableTarget toSerializableTarget(T)(T target) @trusted
{
    SerializableTarget serializable;
    serializable.name = target.name;
    serializable.loc = toSerializableLocation(target.loc);
    
    foreach (field; target.fields)
        serializable.fields ~= toSerializableField(field);
    
    return serializable;
}

/// Convert from runtime BuildFile to serializable format
SerializableBuildFile toSerializable(T)(auto ref const T buildFile) @trusted
{
    SerializableBuildFile serializable;
    serializable.filePath = buildFile.filePath;
    
    foreach (target; buildFile.targets)
        serializable.targets ~= toSerializableTarget(target);
    
    return serializable;
}

/// Convert from serializable Literal to runtime Literal
Literal fromSerializableLiteral(ref const SerializableLiteral serializable) @trusted
{
    import infrastructure.config.workspace.ast;
    
    switch (cast(LiteralKind)serializable.kind)
    {
        case LiteralKind.Null:
            return Literal.makeNull();
        case LiteralKind.Bool:
            return Literal.makeBool(serializable.boolValue);
        case LiteralKind.Number:
            return Literal.makeNumber(serializable.numberValue);
        case LiteralKind.String:
            return Literal.makeString(cast(string)serializable.stringValue);
        case LiteralKind.Array:
            Literal[] arr;
            foreach (elem; serializable.arrayValue)
                arr ~= fromSerializableLiteral(elem);
            return Literal.makeArray(arr);
        case LiteralKind.Map:
            Literal[string] map;
            foreach (i; 0 .. serializable.mapKeys.length)
                map[serializable.mapKeys[i]] = fromSerializableLiteral(serializable.mapValues[i]);
            return Literal.makeMap(map);
        default:
            return Literal.makeNull();
    }
}

/// Convert from serializable Expr to runtime Expr
Expr fromSerializableExpr(ref const SerializableExpr serializable) @trusted
{
    import infrastructure.config.workspace.ast;
    
    Location loc = Location(
        serializable.loc.file,
        cast(size_t)serializable.loc.line,
        cast(size_t)serializable.loc.column
    );
    
    switch (cast(ExprType)serializable.exprType)
    {
        case ExprType.Literal:
            auto lit = fromSerializableLiteral(serializable.literal);
            return new LiteralExpr(lit, loc);
            
        case ExprType.Ident:
            return new IdentExpr(cast(string)serializable.identifier, loc);
            
        case ExprType.Binary:
            auto left = fromSerializableExpr(*serializable.left);
            auto right = fromSerializableExpr(*serializable.right);
            return new BinaryExpr(left, cast(string)serializable.binaryOp, right, loc);
            
        case ExprType.Unary:
            auto operand = fromSerializableExpr(*serializable.operand);
            return new UnaryExpr(cast(string)serializable.unaryOp, operand, loc);
            
        case ExprType.Call:
            Expr[] args;
            foreach (arg; serializable.arguments)
                args ~= fromSerializableExpr(arg);
            return new CallExpr(cast(string)serializable.callee, args, loc);
            
        case ExprType.Index:
            auto object = fromSerializableExpr(*serializable.object);
            auto index = fromSerializableExpr(*serializable.index);
            return new IndexExpr(object, index, loc);
            
        case ExprType.Slice:
            auto object = fromSerializableExpr(*serializable.object);
            Expr start = serializable.sliceStart ? fromSerializableExpr(*serializable.sliceStart) : null;
            Expr end = serializable.sliceEnd ? fromSerializableExpr(*serializable.sliceEnd) : null;
            return new SliceExpr(object, start, end, loc);
            
        case ExprType.Member:
            auto object = fromSerializableExpr(*serializable.object);
            return new MemberExpr(object, cast(string)serializable.member, loc);
            
        case ExprType.Ternary:
            auto condition = fromSerializableExpr(*serializable.condition);
            auto trueExpr = fromSerializableExpr(*serializable.trueExpr);
            auto falseExpr = fromSerializableExpr(*serializable.falseExpr);
            return new TernaryExpr(condition, trueExpr, falseExpr, loc);
            
        case ExprType.Lambda:
            auto body = fromSerializableExpr(*serializable.lambdaBody);
            string[] params = serializable.lambdaParams.dup;
            return new LambdaExpr(params, body, loc);
            
        default:
            // Fallback to null literal
            return new LiteralExpr(Literal.makeNull(), loc);
    }
}

