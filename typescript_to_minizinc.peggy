{
  // --- Helpers for MiniZinc output generation ---
  const typeMap = { number: "float", boolean: "bool", string: "string" };

  function mapType(tsType){
    if(!tsType) return "float";
    if(tsType.endsWith("[]")){
      const base = mapType(tsType.slice(0,-2));
      return "array[int] of " + base;
    }
    return typeMap[tsType] || tsType;
  }

  function compileIdent(id){ return id; }

  function emitComment(c){
    if(c.startsWith("//")) return "% " + c.slice(2).trim();
    const inner = c.slice(2,-2).replace(/\r\n/g,"\n").replace(/\n/g,"\n% ");
    return "% " + inner.trim();
  }

  function formatNumber(n){ return n.indexOf(".") >= 0 ? n : n + ".0"; }

  function addInnerSemicolon(s){
    if(!s) return "";
    const t = s.trim();
    if(!t) return "";
    if(t.startsWith("%")) return t;
    if(t.indexOf("\n") !== -1) return t;
    if(t.startsWith("if ") || t.startsWith("let ")) return t;
    return t + ";";
  }
}

/* ---------------- Entry point ---------------- */
Start
  = _ items:(TopLevelItem (_ TopLevelItem)*)? _ {
      const all = items ? [items[0]].concat(items[1].map(t=>t[1])) : [];
      return all.map(s => addInnerSemicolon(s)).join("\n");
    }

/* ---------------- Top-level items ---------------- */
TopLevelItem
  = TypeAliasDecl
  / EnumDecl
  / FunctionDecl
  / FunctionDeclOnly
  / ConstDecl
  / TopLevelVarDecl
  / AssignmentStmt
  / ExprStmt
  / ForStmt

/* ---------------- Type alias and enums ---------------- */
TypeAliasDecl
  = "type" __ id:Identifier _ "=" _ t:Type _ ";" {
      return "type " + compileIdent(id) + " = " + mapType(t);
    }

EnumDecl
  = "enum" __ id:Identifier _ "{" _ members:EnumMemberList? _ "}" {
      const mems = members || [];
      const list = mems.map(m=>m.name).join(", ");
      return "enum " + compileIdent(id) + " = { " + list + " }";
    }

EnumMemberList = head:EnumMember tail:(_ "," _ EnumMember)* _ ","? { return [head].concat(tail.map(t=>t[3])); }
EnumMember = name:Identifier { return {name}; }

/* ---------------- Consts & vars ---------------- */
ConstDecl
  = "const" __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return "constraint " + compileIdent(id) + " = " + expr;
    }
  / "const" __ id:Identifier _ "=" _ expr:Expression _ ";" {
      return "constraint " + expr;
    }

/* Top-level var declarations with default "any" type */
TopLevelVarDecl
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return "var " + mapType(t) + ": " + compileIdent(id) + " = " + expr;
    }
  / ("var"/"let") __ id:Identifier _ "=" _ expr:Expression _ ";" {
      return "var any: " + compileIdent(id) + " = " + expr;
    }

/* ---------------- Statements ---------------- */
Statement
  = ConstStmt
  / VarDecl
  / AssignmentStmt
  / ReturnStmt
  / IfStmt
  / ExprStmt
  / Block
  / ForStmt

ConstStmt
  = "const" __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return mapType(t) + ": " + compileIdent(id) + " = " + expr;
    }

VarDecl
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return "var " + mapType(t) + ": " + compileIdent(id) + " = " + expr;
    }
  / ("var"/"let") __ id:Identifier _ "=" _ expr:Expression _ ";" {
      return "var any: " + compileIdent(id) + " = " + expr;
    }

VarDeclNoSemi
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression {
      return "var " + mapType(t) + ": " + compileIdent(id) + " = " + expr;
    }
  / ("var"/"let") __ id:Identifier _ "=" _ expr:Expression {
      return "var any: " + compileIdent(id) + " = " + expr;
    }

AssignmentStmt
  = lhs:Assignable _ "=" _ rhs:Expression _ ";" { return "constraint " + lhs + " = " + rhs; }
AssignmentNoSemi
  = lhs:Assignable _ "=" _ rhs:Expression { return "constraint " + lhs + " = " + rhs; }

ReturnStmt = "return" __ expr:Expression _ ";" { return expr; }

/* ---------------- If / Else ---------------- */
IfStmt
  = "if" _ "(" _ cond:Expression _ ")" _ then:Block _ elsePart:ElseClause? {
      return "if " + cond + " then\n" + then + (elsePart ? ("\nelse\n" + elsePart) : "") + "\nendif";
    }
ElseClause = "else" _ stmt:(IfStmt / Block) { return stmt; }

/* ---------------- For loops (placeholder) ---------------- */
ForStmt
  = "for" _ "(" _ init:(VarDeclNoSemi / AssignmentNoSemi / Expression)? _ ";" _ cond:Expression? _ ";" _ update:(AssignmentNoSemi / Expression)? _ ")" _ body:Block {
      const prefix = "% for (" + (init?init:"") + "; " + (cond?cond:"") + "; " + (update?update:"") + ") { ... }";
      return prefix + "\n" + body;
    }

/* ---------------- Functions ---------------- */
FunctionDecl
  = "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ _ body:Block {
      const ps = params ? params.join(", ") : "";
      return "function " + mapType(ret) + ": " + compileIdent(id) + "(" + ps + ") = " + body;
    }

FunctionDeclOnly
  = "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ ";" {
      const ps = params ? params.join(", ") : "";
      return "% function prototype: " + mapType(ret) + " " + compileIdent(id) + "(" + ps + ")";
    }

ParamList = head:Param tail:(_ "," _ Param)* { return [head].concat(tail.map(t=>t[3])); }
Param = id:Identifier _ ":" _ t:Type { return mapType(t) + ": " + compileIdent(id); }

/* ---------------- Blocks ---------------- */
Block
  = "{" _ stmts:(Statement (_ Statement)*)? _ "}" {
      const all = stmts ? [stmts[0]].concat(stmts[1].map(t=>t[1])) : [];
      if(all.length === 0) return "true";
      let expr = all[all.length - 1];
      for(let i = all.length - 2; i >= 0; i--){
        const inner = addInnerSemicolon(all[i]);
        expr = "let {\n" + inner + "\n} in " + expr;
      }
      return expr;
    }

/* ---------------- Expressions ---------------- */
Expression = LogicalOr

LogicalOr
  = left:LogicalAnd tail:(_ "||" _ LogicalAnd)* { return tail.reduce((acc,t)=>acc + " \\/ " + t[3], left); }

LogicalAnd
  = left:Comparison tail:(_ "&&" _ Comparison)* { return tail.reduce((acc,t)=>acc + " /\\ " + t[3], left); }

Comparison
  = left:AddSub tail:(_ CompOp _ AddSub)* { return tail.reduce((acc,t)=>acc + " " + t[1] + " " + t[3], left); }
CompOp = "==" / "!=" / "<=" / ">=" / "<" / ">"

AddSub
  = left:MulDiv tail:(_ ("+" / "-") _ MulDiv)* { return tail.reduce((acc,t)=>acc + " " + t[1] + " " + t[3], left); }

MulDiv
  = left:Unary tail:(_ ("*" / "/") _ Unary)* { return tail.reduce((acc,t)=>acc + " " + t[1] + " " + t[3], left); }

/* Unary then Postfix */
Unary
  = "-" _ v:Unary { return "-" + v; }
  / "!" _ v:Unary { return "not " + v; }
  / Postfix

Postfix
  = base:Primary tail:PostfixPart* { return tail.reduce((acc, part) => part(acc), base); }

PostfixPart
  = "(" _ args:ArgList? _ ")" { return function(c){ const a = args ? args.join(", ") : ""; return c + "(" + a + ")"; }; }
  / "[" _ idx:Expression _ "]" { return function(a){ return a + "[" + idx + "]"; }; }
  / "." name:Identifier { return function(o){ return o + "." + name; }; }

/* ---------------- Primary ---------------- */
Primary
  = Number
  / Boolean
  / ArrayLiteral
  / ObjectLiteral
  / StructConstructor
  / Identifier
  / "(" _ e:Expression _ ")" { return "(" + e + ")"; }

/* ---------------- Object literals ---------------- */
ObjectLiteral
  = "{" _ fields:FieldList? _ "}" { const fs = fields ? fields.join(", ") : ""; return "(" + fs + ")"; }
FieldList = head:Field tail:(_ "," _ Field)* { return [head].concat(tail.map(t=>t[3])); }
Field = key:Identifier _ ":" _ value:Expression { return compileIdent(key) + ": " + value; }

/* ---------------- Arrays ---------------- */
ArrayLiteral = "[" _ elems:ExprList? _ "]" { const arr = elems ? elems : []; return "[" + arr.join(", ") + "]"; }
ExprList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* ---------------- Struct / Function calls ---------------- */
StructConstructor = id:Identifier "(" _ args:ArgList? _ ")" { const a = args ? args.join(", ") : ""; return compileIdent(id) + "(" + a + ")"; }
FuncCall = id:Identifier "(" _ args:ArgList? _ ")" { const a = args ? args.join(", ") : ""; return id + "(" + a + ")"; }
ArgList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* ---------------- Assignable ---------------- */
Assignable
  = base:IdentifierOrCall tail:(_ AccessPart)* { return tail.reduce((acc,t)=>{ const p=t[1]; return p.type==="member"?acc+"."+p.name:acc+"["+p.index+"]"; }, base); }

IdentifierOrCall
  = StructConstructor
  / FuncCall
  / Identifier

AccessPart
  = "." name:Identifier { return {type:"member", name}; }
  / "[" _ idx:Expression _ "]" { return {type:"index", index:idx}; }

/* ---------------- Tokens ---------------- */
StringLiteral = s:$("\"" ([^\"]*) "\"") { return s; }
Number = n:$([0-9]+ ("." [0-9]+)?) { return formatNumber(text()); }
Boolean = b:("true" / "false") { return b; }
Identifier = id:$([a-zA-Z_$][a-zA-Z0-9_$]*) { return id; }

/* Expression statement (top-level) */
ExprStmt = expr:Expression _ ";" { return expr; }

/* ---------------- Types ---------------- */
Type = base:BaseType arr:("[]")* { return base + arr.join(""); }
BaseType = "number" / "boolean" / "string" / Identifier

/* ---------------- Whitespace including comments ---------------- */
_ 
  = ws:([ \t\r\n] / Comment)* { 
      return ws.map(c => typeof c === "string" ? c : emitComment(c)).join(""); 
  }
__ = [ \t\r\n]+

Comment
  = SingleLineComment / MultiLineComment
SingleLineComment = c:$("//" [^\r\n]*) { return c; }
MultiLineComment = c:$("/*" (!"*/" .)* "*/") { return c; }
