module Syntax

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r] !>> "//";
lexical WhitespaceAndComment
  = [\ \t\n\r]
  | @category="Comment" "//" ![\n]* $
  ;

start syntax Init = init: Objs objs Main main;

syntax Obj = obj: "object" Word name Ext? ext Thing? thing;

syntax Objs = objs: Obj+ objects Metho* methods;

syntax Ext = ext: "extends" Word parent;

lexical Letter = [a-zA-Z];

lexical Num = [0-9];

lexical Word = (Letter (Letter | Num)* !>> [a-zA-Z0-9]) \ ReservedWord;

keyword ReservedWord
  = "object" | "extends" | "method" | "val" | "var" | "new" | "override"
  | "if" | "then" | "else" | "for" | "main"
  | "true" | "false" | "print" | "println"
  | "and" | "or" | "neg" | "in"
  | "Integer" | "Boolean" | "String"
  ;

syntax Thing = thing: Variance variance ConsOp? consOp;

syntax Variance = variance: "[" Mod Word ("," Mod Word)* "]";

syntax Operator
  = mul: "*" | div: "/" | sub: "-" | add: "+" | pow: "**" | modulo: "%"
  | lt: "\<" | gt: "\>" | le: "\<=" | ge: "\>=" | ne: "\<\>" | eq: "="
  | andOp: "and" | orOp: "or" | negOp: "neg" | arrow: "-\>" | inOp: "in" | implies: "=\>"
  ;

syntax Punctuation
  = dot: "." | lparen: "(" | rparen: ")" | lbracket: "[" | rbracket: "]" | colon: ":"
  ;

syntax Mod
  = none: ()
  | covariant: "+"
  | contravariant: "-"
  ;

syntax ConsOp = consOp: "(" "val" Word ":" Word ("," "val" Word ":" Word)* ")";

syntax Metho = metho: Word obj "." Word name "=" "method" "(" Parameters? params ")" ":" Type retType ("{" Instructions "}")?;

syntax Main = main: "method" "main" "{" Instructions instructions "}";

syntax Instructions = instructions: Instruction*;

syntax Instruction
  = declaration: Declaration
  | assignment: Assignment
  | methodCall: MethodCall
  | print: Print
  | ifExpr: IfExpression
  | forLoop: For
  | newInstr: NewExpression
  ;

syntax Declaration = declaration: ("val" | "var") kind Word name (":" Type)? "=" Expression val;

syntax Type
  = basic: BasicType
  | named: Word name TypeArguments? args
  ;

syntax BasicType
  = integer: "Integer"
  | boolean: "Boolean"
  | string: "String"
  ;

syntax TypeArguments = typeArgs: "[" Type ("," Type)* "]";

syntax Expression
  = literal: Literal
  | variable: Word name
  | newExpr: NewExpression
  | methodCall: MethodCall
  | ifExpr: IfExpression
  | binary: BinaryExpression
  | paren: "(" Expression expr ")"
  | fieldAccess: Expression obj "." Word field
  ;

syntax Literal
  = intLit: IntLiteral
  | boolLit: BooleanLiteral
  | strLit: StringLiteral
  ;

lexical IntLiteral = Num+ !>> [0-9];

syntax BooleanLiteral
  = trueLit: "true"
  | falseLit: "false"
  ;

lexical StringLiteral = "\"" StringContent* "\"";

lexical StringContent = StringText | Interpolation;

lexical Interpolation = "$" Word | "$" "{" Expression "}";

lexical StringText = ![\"$\n];

syntax NewExpression = newExpr: "new" Word name TypeArguments? typeArgs ConstructorArg? consArg OverrideBlock? overrides;

syntax ConstructorArg = consArg: "(" Arguments? args ")";

syntax Arguments = arguments: Expression ("," Expression)*;

syntax OverrideBlock = overrideBlock: "{" Override* overrides "}";

syntax Override = overrideDef: "override" Word name "(" Parameters? params ")" ":" Type retType "=" "{" Instructions body "}";

syntax Parameters = parameters: Parameter ("," Parameter)*;

syntax Parameter = parameter: Word name ":" Type typ;

syntax MethodCall = methodCall: Word obj "." Word name "(" Arguments? args ")";

syntax IfExpression = ifExpr: "if" Expression cond "then" Expression thenExpr "else" Expression elseExpr;

syntax BinaryExpression = binary: Expression lhs Operator op Expression rhs;

syntax Assignment = assignment: Word name "=" Expression val;

syntax Print = print: ("print" | "println") kind "(" Expression expr ")";

syntax For = forLoop: "for" "(" "(" Word key "," Word val ")" "\<-" Expression coll ")" Instruction body;