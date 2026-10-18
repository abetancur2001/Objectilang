module AST


// Programa
data Init
    = init(Objs objs, Main main);


// Objetos
data Objs
    = objs(list[Obj] objects, list[Metho] methods);

data Obj
    = obj(str name, list[Ext] ext, list[Thing] thing);

data Ext
    = ext(str parent);

data Thing
    = thing(Variance variance, list[ConsOp] consOp);

data Variance
    = variance(
        Mod firstMod,
        str firstName,
        list[tuple[Mod, str]] rest
    );

data Mod
    = none()
    | covariant()
    | contravariant();

data ConsOp
    = consOp(
        str firstName,
        str firstType,
        list[tuple[str, str]] rest
    );


// Declaraciones de métodos
data Metho
    = metho(
        str obj,
        str name,
        list[Parameters] params,
        Type retType,
        list[Instructions] body
    );

data Main
    = main(Instructions instructions);

data Instructions
    = instructions(list[Instruction] instructions);

data Instruction
    = declarationInstruction(Declaration decl)
    | assignmentInstruction(Assignment assign)
    | methodCallInstruction(MethodCall call)
    | printInstruction(Print printNode)
    | ifInstruction(IfExpression conditionalExpr)
    | forInstruction(For loop)
    | newInstruction(NewExpression creationExpr);


// Declaraciones y tipos
data Declaration
    = declaration(
        DeclKind kind,
        str name,
        list[Type] annotation,
        Expression val
    );

data DeclKind
    = valDecl()
    | varDecl();

data Type
    = basic(BasicType basicTypeValue)
    | named(str name, list[TypeArguments] args);

data BasicType
    = integer()
    | boolean()
    | string();

data TypeArguments
    = typeArgs(Type first, list[Type] rest);


// Expresiones
data Expression
    = literalExpr(Literal literalValue)
    | variableExpr(str name)
    | newExpression(NewExpression newValue)
    | methodCallExpr(MethodCall callValue)
    | conditionalExpr(IfExpression conditionalValue)
    | binaryExpr(BinaryExpression binaryValue)
    | paren(Expression expr)
    | fieldAccess(Expression obj, str field);

data Literal
    = intLit(str intValue)
    | boolLit(BooleanLiteral booleanValue)
    | strLit(str stringValue);

data BooleanLiteral
    = trueLit()
    | falseLit();

data NewExpression
    = newExpr(
        str name,
        list[TypeArguments] typeArgs,
        list[ConstructorArg] consArg,
        list[OverrideBlock] overrides
    );

data ConstructorArg
    = consArg(list[Arguments] args);

data Arguments
    = arguments(Expression first, list[Expression] rest);

data OverrideBlock
    = overrideBlock(list[Override] overrides);

data Override
    = overrideDef(
        str name,
        list[Parameters] params,
        Type retType,
        Instructions body
    );

data Parameters
    = parameters(Parameter first, list[Parameter] rest);

data Parameter
    = parameter(str name, Type typ);

data MethodCall
    = methodCall(
        str obj,
        str name,
        list[Arguments] args
    );

data IfExpression
    = ifExpr(
        Expression cond,
        Expression thenExpr,
        Expression elseExpr
    );

data BinaryExpression
    = binary(Expression lhs, Operator op, Expression rhs);


// Operadores
data Operator
    = mul()
    | div()
    | sub()
    | add()
    | pow()
    | modulo()
    | lt()
    | gt()
    | le()
    | ge()
    | ne()
    | eq()
    | andOp()
    | orOp()
    | negOp()
    | arrow()
    | inOp()
    | implies();


// Asignaciones e impresión
data Assignment
    = assignment(str name, Expression val);

data Print
    = print(PrintKind kind, Expression expr);

data PrintKind
    = printKind()
    | printlnKind();


// Ciclos
data For
    = forLoop(
        str key,
        str val,
        Expression coll,
        Instruction body
    );