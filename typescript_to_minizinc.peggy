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
  = pre:_ items:(TopLevelItem _)* post:_ { 
      return pre + items.map(i => i[0]).join("") + post; 
    }

/* ---------------- Top-level items ---------------- */
TopLevelItem
  = TypeAliasDecl
  / EnumDecl
  / ClassDecl
  / FunctionDecl
  / FunctionDeclOnly
  / TopLevelVarDecl
  / TopLevelAssignmentStmt
  / TopLevelIfStmt
  / ExprStmt

/* ---------------- Type aliases and enums ---------------- */
TypeAliasDecl
  = pre:_ "type" ws:__ id:Identifier _ "=" _ t:Type post:_ ";" { 
      return pre + "type" + ws + id + " = " + mapType(t) + ";" + post; 
    }

EnumDecl
  = pre:_ "enum" ws:__ id:Identifier _ "{" _ members:EnumMemberList? _ "}" post:_ { 
      const mems = members || [];
      const list = mems.map(m=>m.name).join(", ");
      return pre + "enum" + ws + id + " = { " + list + " };" + post;
    }

EnumMemberList = head:EnumMember tail:(_ "," _ EnumMember)* _ ","? { 
    return [head].concat(tail.map(t=>t[3])); 
}
EnumMember = name:Identifier { return {name}; }

/* ---------------- Classes (fields only) ---------------- */
ClassDecl
  = pre:_ "class" ws:__ id:Identifier _ "{" _ members:VarDeclMember* _ "}" post:_ {
      const fields = members.map(m => mapType(m.type) + ": " + m.name).join(", ");
      return pre + "record" + ws + id + " = { " + fields + " };" + post;
    }

VarDeclMember
  = _ (("var"/"let"/"const") __)? id:Identifier _ ":" _ t:Type _ ";" _ { 
      return { name: id, type: t }; 
    }

/* ---------------- Top-level vars/assignments ---------------- */
TopLevelVarDecl
  = pre:_ kw:("var"/"let"/"const") __ id:Identifier pre2:_ ":" _ t:Type _ "=" _ expr:Expression post:_ ";" {
      return pre + kw + " " + id + pre2 + ": " + mapType(t) + " = " + expr + ";" + post;
    }
  / pre:_ kw:("var"/"let"/"const") __ id:Identifier pre2:_ "=" _ expr:Expression post:_ ";" {
      return pre + kw + " " + id + pre2 + " = " + expr + ";" + post;
    }

TopLevelAssignmentStmt
  = pre:_ lhs:Assignable pre2:_ "=" _ rhs:Expression post:_ ";" {
      return pre + "constraint " + lhs + pre2 + " = " + rhs + ";" + post;
    }

/* ---------------- Top-level if / else if / else ---------------- */
TopLevelIfStmt
  = pre:_ "if" pre2:_ "(" _ cond:Expression _ ")" pre3:_ then:InnerBlock _ elseifClauses:TopLevelElseIfClause* _ elsePart:TopLevelElseClause? post:_ {
      let code = pre + "constraint if" + pre2 + "(" + cond + ")" + pre3 + then;
      for (let e of elseifClauses) code += "\nelse if (" + e.cond + ")" + e.block;
      if (elsePart) code += "\nelse" + elsePart;
      code += "\nendif;" + post;
      return code;
    }

TopLevelElseIfClause
  = _ "else" _ "if" pre:_ "(" _ cond:Expression _ ")" pre2:_ block:InnerBlock { return {cond, block}; }

TopLevelElseClause
  = _ "else" pre:_ block:InnerBlock { return block; }

/* ---------------- Inner statements and blocks ---------------- */
Statement
  = InnerVarDecl
  / InnerAssignment
  / ReturnStmt
  / IfStmt
  / ExprStmt

InnerVarDecl
  = pre:_ kw:("var"/"let"/"const") __ id:Identifier pre2:_ ":" _ t:Type _ "=" _ expr:Expression post:_ ";" { 
      return pre + kw + " " + id + pre2 + ": " + mapType(t) + " = " + expr + post; 
    }
  / pre:_ kw:("var"/"let"/"const") __ id:Identifier pre2:_ "=" _ expr:Expression post:_ ";" { 
      return pre + kw + " " + id + pre2 + " = " + expr + post; 
    }

InnerAssignment
  = pre:_ lhs:Assignable pre2:_ "=" _ rhs:Expression post:_ ";" { 
      return pre + lhs + pre2 + " = " + rhs + post; 
    }

ReturnStmt
  = pre:_ "return" __ expr:Expression post:_ ";" { return pre + "return " + expr + post; }

ExprStmt
  = pre:_ expr:Expression post:_ ";" { return pre + expr + post; }

IfStmt
  = pre:_ "if" pre2:_ "(" _ cond:Expression _ ")" pre3:_ then:InnerBlock _ elsePart:ElseClause? post:_ {
      let code = pre + "if" + pre2 + "(" + cond + ")" + pre3 + then;
      if (elsePart) code += "\nelse" + elsePart;
      code += "\nendif" + post;
      return code;
    }

ElseClause
  = _ "else" pre:_ stmt:(IfStmt / InnerBlock) { return stmt; }

InnerBlock
  = "{" pre:_ stmts:(Statement _)* post:_ "}" { 
      return pre + stmts.map(s=>s[0]).join("") + post; 
    }

/* ---------------- Functions ---------------- */
FunctionDecl
  = pre:_ "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ body:InnerBlock post:_ {
      const ps = params ? params.join(", ") : "";
      return pre + "function " + id + "(" + ps + ") = " + body + ";" + post;
    }

FunctionDeclOnly
  = pre:_ "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ ";" post:_ {
      const ps = params ? params.join(", ") : "";
      return pre + "% function prototype: " + mapType(ret) + " " + id + "(" + ps + ");" + post;
    }

ParamList = head:Param tail:(_ "," _ Param)* { return [head].concat(tail.map(t=>t[3])); }
Param = id:Identifier pre:_ ":" _ t:Type { return mapType(t) + ": " + id; }

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
MulDiv = left:Exponent tail:(_ ("*" / "/" / "%") _ Exponent)* { return tail.reduce((acc,t)=> t[1]==="%" ? acc + " mod " + t[3] : acc + " " + t[1] + " " + t[3], left); }
Exponent = left:Unary tail:(_ "**" _ Unary)* { return tail.reduce((acc,t)=> acc + " ^ " + t[3], left); }

Unary
  = "-" _ v:Unary { return "-" + v; }
  / "!" _ v:Unary { return "not " + v; }
  / NewExpr

NewExpr
  = "new" __ callee:Postfix _ "(" _ args:ArgList? _ ")" { return "new " + callee + "(" + (args||[]).join(", ") + ")"; }
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

/* ---------------- Types ---------------- */
Type = base:BaseType arr:("[]")* { return base + arr.join(""); }
BaseType = "number" / "boolean" / "string" / Identifier

/* ---------------- Whitespace & comments ---------------- */
_ = ws:([ \t\r\n]+ / Comment)* { return ws.map(c=>c).join(""); }
__ = ws:([ \t\r\n]+ / Comment)+ { return ws.map(c=>c).join(""); }

Comment
  = SingleLineComment / MultiLineComment
SingleLineComment = c:$("//" [^\r\n]*) { return c + "\n"; }
MultiLineComment = c:$("/*" (!"*/" .)* "*/") { return c + "\n"; }

