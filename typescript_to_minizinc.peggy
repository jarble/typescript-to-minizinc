{
  // --- Helper mappings and utilities (MiniZinc target) ---
  const typeMap = {
    number: "float",
    boolean: "bool",
    string: "string"
  };

  function mapType(tsType){
    if(!tsType) return "float";
    if(tsType.endsWith("[]")){
      const base = mapType(tsType.slice(0,-2));
      return "array[int] of " + base;
    }
    return typeMap[tsType] || tsType;
  }

  function emitComment(c){
    if(c.startsWith("//")) return "% " + c.slice(2).trim() + "\n";
    return "% " + c.slice(2,-2).replace(/\n/g, "\n% ") + "\n";
  }

  function formatNumber(n){ return n.includes(".") ? n : n + ".0"; }

  function compileIdent(id){ return id; }

  function stringText(s){ return s; }
}

/* --- Start --- */
Start = _ items:(TopLevelItem (_ TopLevelItem)*)? _ {
  const arr = items ? [items[0]].concat(items[1].map(t=>t[1])) : [];
  return arr.join("\n");
}

/* --- Top-level items --- */
TopLevelItem
  = CommentStmt
  / TypeAliasDecl
  / EnumDecl
  / FunctionDecl
  / FunctionDeclOnly
  / ConstDecl
  / TopLevelVarDecl
  / AssignmentStmt
  / AssignmentNoSemi
  / IfStmt
  / ForStmt
  / ExprStmt

/* --- Type aliases --- */
TypeAliasDecl
  = "type" __ id:Identifier _ "=" _ t:Type _ ";" {
      return "type " + compileIdent(id) + " = " + mapType(t) + ";";
    }

/* --- Enums --- */
EnumDecl
  = "enum" __ id:Identifier _ "{" _ members:EnumMemberList? _ "}" {
      const mems = members || [];
      const list = mems.map(m => m.name).join(", ");
      return "enum " + compileIdent(id) + " = { " + list + " };";
    }
  / "enum" __ id:Identifier ";" { return "enum " + compileIdent(id) + ";"; }

EnumMemberList
  = head:EnumMember tail:(_ "," _ EnumMember)* _ ","? { return [head].concat(tail.map(t=>t[3])); }
EnumMember
  = name:Identifier { return {name}; }

/* --- Statements --- */
Statement
  = CommentStmt
  / ConstStmt
  / VarDecl
  / AssignmentStmt
  / ReturnStmt
  / IfStmt
  / ExprStmt
  / Block
  / ForStmt

/* --- Comments --- */
CommentStmt = c:Comment { return emitComment(c); }
Comment = SingleLineComment / MultiLineComment
SingleLineComment = c:$("//" [^\r\n]*) { return c; }
MultiLineComment = c:$("/*" (!"*/" .)* "*/") { return c; }

/* --- Const --- */
ConstDecl
  = "const" __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return mapType(t) + ": " + compileIdent(id) + " = " + expr + ";";
    }
  / "const" __ id:Identifier _ "=" _ expr:Expression _ ";" {
      return "constraint " + expr + ";";
    }

ConstStmt
  = "const" __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return mapType(t) + ": " + compileIdent(id) + " = " + expr + ";";
    }

/* --- Blocks (nested let chaining) --- */
Block
  = "{" _ stmts:(Statement (_ Statement)*)? _ "}" {
      const all = stmts ? [stmts[0]].concat(stmts[1].map(t=>t[1])) : [];
      if(all.length === 0) return "true"; // empty block
      let expr = all[all.length - 1]; // last statement
      for(let i = all.length - 2; i >= 0; i--){
        expr = "let {\n" + all[i] + "\n} in " + expr;
      }
      return expr;
    }

/* --- Top-level variable declarations --- */
TopLevelVarDecl
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return "var " + mapType(t) + ": " + compileIdent(id) + " = " + expr + ";";
    }
  / ("var"/"let") __ id:Identifier _ "=" _ expr:Expression _ ";" {
      return "var float: " + compileIdent(id) + " = " + expr + ";";
    }

/* --- Function-scope var decl --- */
VarDecl
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return "var " + mapType(t) + ": " + compileIdent(id) + " = " + expr + ";";
    }
VarDeclNoSemi
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression {
      return "var " + mapType(t) + ": " + compileIdent(id) + " = " + expr;
    }

/* --- Assignments --- */
AssignmentStmt
  = lhs:Assignable _ "=" _ rhs:Expression _ ";" { return lhs + " = " + rhs + ";"; }
AssignmentNoSemi
  = id:Assignable _ "=" _ expr:Expression { return id + " = " + expr; }

/* --- Return --- */
ReturnStmt = "return" __ expr:Expression _ ";" { return expr; }

/* --- If / else --- */
IfStmt
  = "if" _ "(" _ cond:Expression _ ")" _ then:Block _ elsePart:ElseClause? {
      return "if " + cond + " then\n" + then + (elsePart ? ("\nelse\n" + elsePart) : "") + "\nendif";
    }
ElseClause = "else" _ stmt:(IfStmt / Block) { return stmt; }

/* --- For loop --- */
ForStmt
  = "for" _ "(" _ init:VarDeclNoSemi _ ";" _ cond:Expression _ ";" _ update:AssignmentNoSemi _ ")" _ body:Block {
      return "% for (" + init + "; " + cond + "; " + update + ") { ... }\n" + body;
    }

/* --- Functions --- */
FunctionDecl
  = "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ _ body:Block {
      const ps = params ? params.join(", ") : "";
      return "function " + mapType(ret) + ": " + compileIdent(id) + "(" + ps + ") = " + body + ";";
    }

FunctionDeclOnly
  = "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ ";" {
      const ps = params ? params.join(", ") : "";
      return "% function prototype: " + mapType(ret) + " " + compileIdent(id) + "(" + ps + ");";
    }

/* --- Parameters --- */
ParamList = head:Param tail:(_ "," _ Param)* { return [head].concat(tail.map(t=>t[3])); }
Param = id:Identifier _ ":" _ t:Type { return mapType(t) + ": " + compileIdent(id); }

/* --- Expressions --- */
Expression = LogicalOr
LogicalOr = left:LogicalAnd tail:(_ "||" _ LogicalAnd)* { return tail.reduce((acc,t)=>acc+" \\/ "+t[3], left); }
LogicalAnd = left:Comparison tail:(_ "&&" _ Comparison)* { return tail.reduce((acc,t)=>acc+" /\\ "+t[3], left); }
Comparison = left:AddSub tail:(_ CompOp _ AddSub)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }
CompOp = "==" / "!=" / "<=" / ">=" / "<" / ">"

AddSub = left:MulDiv tail:(_ ("+" / "-") _ MulDiv)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }
MulDiv = left:Unary tail:(_ ("*" / "/") _ Unary)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }

Unary
  = "!" _ v:Unary { return "not " + v; }
  / "-" _ v:Unary { return "-" + v; }
  / Primary

/* --- Primary expressions --- */
Primary
  = "true" { return "true"; }
  / "false" { return "false"; }
  / "(" _ e:Expression _ ")" { return "(" + e + ")"; }
  / ArrayLiteral
  / FuncCall
  / Assignable
  / Identifier
  / StringLiteral
  / Number

/* --- Arrays --- */
ArrayLiteral = "[" _ elements:ExprList? _ "]" {
  const elems = elements ? elements : [];
  return "[" + elems.join(", ") + "]";
}
ExprList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Function calls --- */
FuncCall = id:Identifier "(" _ args:ArgList? _ ")" { return id + "(" + (args?args.join(", "):"") + ")"; }
ArgList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Assignable --- */
Assignable = Identifier

/* --- String literals --- */
StringLiteral = s:$("\"" ([^\"]*) "\"") { return stringText(s); }

/* --- Expression statements --- */
ExprStmt = expr:Expression _ ";" { return expr + ";"; }

/* --- Numbers --- */
Number = n:$([0-9]+ ("." [0-9]+)?) { return formatNumber(text()); }

/* --- Types --- */
Type = base:BaseType arr:("[]")* { return base + arr.join(""); }
BaseType = "number" / "boolean" / "string" / Identifier

/* --- Identifier --- */
Identifier = id:$([a-zA-Z_$][a-zA-Z0-9_$]*) { return id; }

/* --- Whitespace --- */
_ = [ \t\r\n]*
__ = [ \t\r\n]+
