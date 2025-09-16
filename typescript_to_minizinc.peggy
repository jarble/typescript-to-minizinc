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
    "Math.E": "(exp(1.0))",
    "Math.LN2": "(log(2.0))",
    "Math.LN10": "(log(10.0))",
    "Math.LOG2E": "(1.0 / log(2.0))",
    "Math.LOG10E": "(1.0 / log(10.0))",
    "Math.SQRT2": "(sqrt(2.0))",
    "Math.SQRT1_2": "(1.0 / sqrt(2.0))"
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
  = items:TopLevelItem* _ { return items.join(""); }

/* ---------------- Top-level items ---------------- */
TopLevelItem
  = item:(TypeAliasDecl / EnumDecl / ClassDecl / FunctionDecl / FunctionDeclOnly / TopLevelVarDecl / TopLevelAssignmentStmt / TopLevelIfStmt / ExprStmt) { return item; }

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

/* ---------------- Classes (fields only) ---------------- */
ClassDecl
  = _ "class" __ id:Identifier _ "{" _ members:VarDeclMember* _ "}" _ {
      const fields = members
        .map(m => mapType(m.type) + ": " + m.name)
        .join(", ");
      return "record " + id + " = { " + fields + " };\n";
    }

VarDeclMember
  = _ (("var"/"let"/"const") __)? id:Identifier _ ":" _ t:Type _ ";" _ { return { name: id, type: t }; }

/* ---------------- Top-level vars/assignments ---------------- */
TopLevelVarDecl
  = _ ("var"/"let"/"const") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" _ { return mapType(t) + ": " + id + " = " + expr + ";\n"; }
  / _ ("var"/"let"/"const") __ id:Identifier _ "=" _ expr:Expression _ ";" _ { return "any: " + id + " = " + expr + ";\n"; }

TopLevelAssignmentStmt
  = _ lhs:Assignable _ "=" _ rhs:Expression _ ";" _ { return "constraint " + lhs + " = " + rhs + ";\n"; }

/* ---------------- Top-level if / else if / else ---------------- */
TopLevelIfStmt
  = _ "if" _ "(" _ cond:Expression _ ")" _ then:InnerBlock _ elseifClauses:TopLevelElseIfClause* _ elsePart:TopLevelElseClause? {
      let code = "constraint if " + cond + " then\n" + then;
      for (let e of elseifClauses) code += "\nelse if " + e.cond + " then\n" + e.block;
      if (elsePart) code += "\nelse\n" + elsePart;
      code += "\nendif;\n";
      return code;
    }

TopLevelElseIfClause
  = _ "else" _ "if" _ "(" _ cond:Expression _ ")" _ block:InnerBlock { return {cond, block}; }

TopLevelElseClause
  = _ "else" _ block:InnerBlock { return block; }

/* ---------------- Inner statements and blocks ---------------- */
Statement
  = InnerVarDecl
  / InnerAssignment
  / ReturnStmt
  / IfStmt
  / ExprStmt

InnerVarDecl
  = _ ("var"/"let"/"const") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" _ { return mapType(t) + ": " + id + " = " + expr; }
  / _ ("var"/"let"/"const") __ id:Identifier _ "=" _ expr:Expression _ ";" _ { return "any: " + id + " = " + expr; }

InnerAssignment
  = _ lhs:Assignable _ "=" _ rhs:Expression _ ";" _ { return lhs + " = " + rhs; }

ReturnStmt
  = _ "return" __ expr:Expression _ ";" _ { return expr; }

ExprStmt
  = _ expr:Expression _ ";" _ { return expr; }

IfStmt
  = _ "if" _ "(" _ cond:Expression _ ")" _ then:InnerBlock _ elsePart:ElseClause? {
      return "if " + cond + " then\n" + then + (elsePart ? ("else\n" + elsePart) : "") + "\nendif";
    }

ElseClause
  = _ "else" _ stmt:(IfStmt / InnerBlock) { return stmt; }

InnerBlock
  = "{" _ stmts:Statement* _ "}" { return stmts.join("\n"); }

/* ---------------- Functions ---------------- */
FunctionDecl
  = _ "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ body:InnerBlock _ {
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

/* ---------------- Expressions ---------------- */
Expression = Ternary

Ternary
  = cond:LogicalOr _ "?" _ thenExpr:Expression _ ":" _ elseExpr:Expression {
      return "(if " + cond + " then " + thenExpr + " else " + elseExpr + " endif)";
    }
  / LogicalOr

LogicalOr = left:LogicalAnd tail:(_ "||" _ LogicalAnd)* { return tail.reduce((acc,t)=>acc + " \\/ " + t[3], left); }
LogicalAnd = left:Comparison tail:(_ "&&" _ Comparison)* { return tail.reduce((acc,t)=>acc + " /\\ " + t[3], left); }
Comparison = left:AddSub tail:(_ CompOp _ AddSub)* { return tail.reduce((acc,t)=>acc + " " + t[1] + " " + t[3], left); }
CompOp = "==" / "!=" / "<=" / ">=" / "<" / ">"

AddSub = left:MulDiv tail:(_ ("+" / "-") _ MulDiv)* { return tail.reduce((acc,t)=>acc + " " + t[1] + " " + t[3], left); }
MulDiv = left:Exponent tail:(_ ("*" / "/" / "%") _ Exponent)* { return tail.reduce((acc,t)=>t[1]==="%"?acc+" mod "+t[3]:acc+" "+t[1]+" "+t[3], left); }
Exponent = left:Unary tail:(_ "**" _ Unary)* { return tail.reduce((acc,t)=> "pow(" + acc + ", " + t[3] + ")", left); }

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
  / StringLiteral
  / ArrayLiteral
  / ObjectLiteral
  / NewExpr
  / Identifier
  / "(" _ e:Expression _ ")" { return "(" + e + ")"; }

/* ---------------- New expression ---------------- */
NewExpr
  = "new" __ id:Identifier _ "(" _ args:ArgList? _ ")" { return "new " + id + "(" + (args ? args.join(", ") : "") + ")"; }

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
