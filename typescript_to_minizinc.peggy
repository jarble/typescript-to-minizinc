{
  const typeMap = { number: "float", boolean: "bool", string: "string" };

  function mapType(tsType){
    if(!tsType) return "float";
    if(tsType.endsWith("[]")){
      const base = mapType(tsType.slice(0,-2));
      return "array[int] of " + base;
    }
    return typeMap[tsType] || tsType;
  }

  function formatNumber(n){ return n.indexOf(".") >= 0 ? n : n + ".0"; }

  const jsFuncMap = {
    "abs":"abs","acos":"acos","asin":"asin","atan":"atan","atan2":"atan2","ceil":"ceil",
    "cos":"cos","exp":"exp","floor":"floor","log":"log","max":"max","min":"min","pow":"pow",
    "sin":"sin","sqrt":"sqrt","tan":"tan","sign":"sign","round":"round","trunc":"trunc","hypot":"hypot"
  };

  const jsConstMap = {
    "Math.PI": "3.141592653589793",
    "Math.E": "2.718281828459045",
    "Math.LN2": "0.6931471805599453",
    "Math.LN10": "2.302585092994046",
    "Math.LOG2E": "1.4426950408889634",
    "Math.LOG10E": "0.4342944819032518",
    "Math.SQRT2": "1.4142135623730951",
    "Math.SQRT1_2": "0.7071067811865476"
  };

  function translateBuiltin(callee, args){
    if(typeof callee !== "string") callee = String(callee);
    if(jsConstMap[callee] && (!args || args.length === 0)) return jsConstMap[callee];
    if(callee.startsWith("Math.")){
      const name = callee.slice(5);
      if(jsFuncMap[name]) return jsFuncMap[name] + "(" + (args ? args.join(", ") : "") + ")";
      return name + "(" + (args ? args.join(", ") : "") + ")";
    }
    return callee + "(" + (args ? args.join(", ") : "") + ")";
  }
}

/* ---------------- Entry ---------------- */
Start
  = items:TopLevelItem* { return items.join(""); }

/* ---------------- Top-level items ---------------- */
TopLevelItem
  = item:(TypeAliasDecl / EnumDecl / FunctionDecl / FunctionDeclOnly / ConstDecl / TopLevelVarDecl / AssignmentStmt / ExprStmt) { return item; }

/* ---------------- Type aliases and enums ---------------- */
TypeAliasDecl
  = _ "type" __ id:Identifier _ "=" _ t:Type _ ";" _ { return "type " + id + " = " + mapType(t) + ";\n"; }

EnumDecl
  = _ "enum" __ id:Identifier _ "{" _ members:EnumMemberList? _ "}" _ {
      const mems = members || [];
      const list = mems.map(m=>m.name).join(", ");
      return "enum " + id + " = { " + list + " };\n";
    }

EnumMemberList = head:EnumMember tail:(_ "," _ EnumMember)* _ ","? { return [head].concat(tail.map(t=>t[3])); }
EnumMember = name:Identifier { return {name}; }

/* ---------------- Consts & top-level vars ---------------- */
ConstDecl
  = _ "const" __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" _ { return "constraint " + id + " = " + expr + ";\n"; }
  / _ "const" __ id:Identifier _ "=" _ expr:Expression _ ";" _ { return "constraint " + id + " = " + expr + ";\n"; }

TopLevelVarDecl
  = _ ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" _ { return mapType(t) + ": " + id + " = " + expr + ";\n"; }
  / _ ("var"/"let") __ id:Identifier _ "=" _ expr:Expression _ ";" _ { return "any: " + id + " = " + expr + ";\n"; }

/* ---------------- Statements ---------------- */
Statement
  = ConstStmt
  / VarDecl
  / AssignmentStmt
  / ReturnStmt
  / IfStmt
  / ExprStmt
  / Block

ConstStmt
  = _ "const" __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" _ { return mapType(t) + ": " + id + " = " + expr + ";\n"; }

VarDecl
  = _ ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" _ { return mapType(t) + ": " + id + " = " + expr + ";\n"; }
  / _ ("var"/"let") __ id:Identifier _ "=" _ expr:Expression _ ";" _ { return "any: " + id + " = " + expr + ";\n"; }

AssignmentStmt
  = _ lhs:Assignable _ "=" _ rhs:Expression _ ";" _ { return "constraint " + lhs + " = " + rhs + ";\n"; }

ReturnStmt
  = _ "return" __ expr:Expression _ ";" _ { return expr + ";\n"; }

/* ---------------- If / Else ---------------- */
IfStmt
  = _ "if" _ "(" _ cond:Expression _ ")" _ then:Block _ elsePart:ElseClause? {
      return "if " + cond + " then\n" + then + (elsePart ? ("else\n" + elsePart) : "") + "\nendif;\n";
    }

ElseClause = _ "else" _ stmt:(IfStmt / Block) { return stmt; }

/* ---------------- Functions ---------------- */
FunctionDecl
  = _ "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ body:Block _ {
      const ps = params ? params.join(", ") : "";
      return "function " + mapType(ret) + ": " + id + "(" + ps + ") = " + body + ";\n";
    }

FunctionDeclOnly
  = _ "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ ";" _ {
      const ps = params ? params.join(", ") : "";
      return "% function prototype: " + mapType(ret) + " " + id + "(" + ps + ");\n";
    }

ParamList = head:Param tail:(_ "," _ Param)* { return [head].concat(tail.map(t=>t[3])); }
Param = id:Identifier _ ":" _ t:Type { return mapType(t) + ": " + id; }

/* ---------------- Blocks ---------------- */
Block
  = "{" _ stmts:Statement* _ "}" {
      if(stmts.length === 0) return "true";
      if(stmts.length === 1) return stmts[0];
      let expr = stmts[stmts.length - 1];
      for(let i = stmts.length - 2; i >= 0; i--){
        expr = "let {\n" + stmts[i] + "} in " + expr;
      }
      return expr;
    }

/* ---------------- Expressions ---------------- */
Expression = LogicalOr
LogicalOr = left:LogicalAnd tail:(_ "||" _ LogicalAnd)* { return tail.reduce((acc,t)=>acc + " \\/ " + t[3], left); }
LogicalAnd = left:Comparison tail:(_ "&&" _ Comparison)* { return tail.reduce((acc,t)=>acc + " /\\ " + t[3], left); }
Comparison = left:AddSub tail:(_ CompOp _ AddSub)* { return tail.reduce((acc,t)=>acc + " " + t[1] + " " + t[3], left); }
CompOp = "==" / "!=" / "<=" / ">=" / "<" / ">"

AddSub = left:MulDiv tail:(_ ("+" / "-") _ MulDiv)* { return tail.reduce((acc,t)=>acc + " " + t[1] + " " + t[3], left); }
MulDiv = left:Unary tail:(_ ("*" / "/") _ Unary)* { return tail.reduce((acc,t)=>acc + " " + t[1] + " " + t[3], left); }

Unary
  = "-" _ v:Unary { return "-" + v; }
  / "!" _ v:Unary { return "not " + v; }
  / Postfix

Postfix
  = base:Primary tail:PostfixPart* { return tail.reduce((acc, part) => part(acc), base); }

PostfixPart
  = "(" _ args:ArgList? _ ")" { return function(callee){ return translateBuiltin(callee,args||[]); } }
  / "[" _ idx:Expression _ "]" { return function(a){ return a + "[" + idx + "]"; }; }
  / "." name:Identifier { return function(o){ return o + "." + name; }; }

ArgList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* ---------------- Primary ---------------- */
Primary
  = Number
  / Boolean
  / ArrayLiteral
  / ObjectLiteral
  / Identifier
  / "(" _ e:Expression _ ")" { return "(" + e + ")"; }

/* ---------------- Object literals ---------------- */
ObjectLiteral
  = "{" _ fields:FieldList? _ "}" { const fs = fields ? fields.join(", ") : ""; return "(" + fs + ")"; }
FieldList = head:Field tail:(_ "," _ Field)* { return [head].concat(tail.map(t=>t[3])); }
Field = key:Identifier _ ":" _ value:Expression { return key + ": " + value; }

/* ---------------- Arrays ---------------- */
ArrayLiteral = "[" _ elems:ExprList? _ "]" { const arr = elems ? elems : []; return "[" + arr.join(", ") + "]"; }
ExprList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* ---------------- Assignable ---------------- */
Assignable = Postfix

/* ---------------- Tokens ---------------- */
StringLiteral = s:$("\"" ([^\"]*) "\"") { return s; }
Number = n:$([0-9]+ ("." [0-9]+)?) { return formatNumber(text()); }
Boolean = b:("true" / "false") { return b; }
Identifier = id:$([a-zA-Z_$][a-zA-Z0-9_$]*) { return id; }

/* Expression statement */
ExprStmt = _ expr:Expression _ ";" _ { return expr + ";\n"; }

/* ---------------- Types ---------------- */
Type = base:BaseType arr:("[]")* { return base + arr.join(""); }
BaseType = "number" / "boolean" / "string" / Identifier

/* ---------------- Whitespace & comments ---------------- */
_ = ws:([ \t\r\n]+ / Comment)* { return ws.map(c=>c).join(""); }
__ = [ \t\r\n]+

Comment
  = SingleLineComment / MultiLineComment
SingleLineComment = c:$("//" [^\r\n]*) { return c + "\n"; }
MultiLineComment = c:$("/*" (!"*/" .)* "*/") { return c + "\n"; }
