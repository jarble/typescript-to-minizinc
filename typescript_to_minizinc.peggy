// Use this code to make it work offline:
//     https://gist.github.com/kosamari/7c5d1e8449b2fbc97d372675f16b566e

{var initial_value={}; var class_members = ""; var class_name = ""; var type_in_arr = undefined; var anonymous_structs = []; var class_names = []; var class_methods = ""; var extended_methods = {}; var class_fields = ""; var extended_fields = {}; var to_append = []; var temp_vars  = []; var redundant_vars = {}; var declared_redundant_vars = {}; var last_parsed = ""; var returned = undefined; var return_types = {}; var expression_types = {}; var type_parameters = {}; var function_number = 0;
expression_types["true"] = "bool";
expression_types["false"] = "bool";
let break_if_returned = "if(is_returned == 1) break;"

function replaceAll(str1,str2,str){
    if(str1.indexOf("<") === -1) return str2;
    let sub1 = str1.substring(str1.indexOf("<")+1,str1.indexOf(">"));
    //alert(JSON.stringify([list1,list3]));
    let list1 = sub1.split(",");
    let list3 = str.split(",");
    var mapObj = {};
    for(let i = 0; i < list1.length; i++){
        mapObj[list1[i]] = list3[i];
    }
    var re = new RegExp("\\b(?:"+Object.keys(mapObj).join("|")+")\\b","g");

    return str2.replace(re, function(matched){
        return mapObj[matched];
    });
}
function unify_expression_types(a,b){
if(expression_types[a] == undefined) expression_types[a] = expression_types[b];
if(expression_types[b] == undefined) expression_types[b] = expression_types[a];
}
//alert(replaceAll("add<A>","A","float"));

}

expressions = _ a:statements _ {
	
	return a;
}

statements = head:statement tail:(_ statement)* {
      return tail.reduce(function(result, element) {
        return result + element[1];
      }, head);
    }

interface_statements = head:function_parameter ";" tail:(_ function_parameter _ ";")* {
      return tail.reduce(function(result, element) {
        return result + element[1] + ";";
      }, head);
    }
    
class_statements = head:class_statement tail:( _ class_statement)* {
      return tail.reduce(function(result, element) {
        return function(name){return result(name) + element[1](name)};
      }, head);
    }

instance_method = name:var_name _ "(" _ b:function_parameters _ ")" _ t2:(":" _ type _ / "") "{" _ c:statements _ "}" {
		let t1 = "@TypeOf("+initial_value[returned]()+")";
		if(t2.length > 0){
			t1 = t2[2];
		}
		return function(name1){return "fn "+name+"(self:"+name1+",arguments:anytype) "+t1+"{"+b+c+"}";}
	}

static_method = "static" __ name:var_name _ "(" _ b:function_parameters _ ")" _ (":" _ t2:type _ / "") "{" _ c:statements _ "}" {
		let t1 = "@TypeOf("+initial_value[returned]()+")";
		if(t2.length > 0){
			t1 = t2[2];
		}
		return function(name1){return "fn "+name+"(arguments:anytype) "+return_type+"{"+b+c+"}";}
	}

constructor = "constructor" _ "(" _ params:function_parameters _ ")" _ "{" _ body:statements _ "}" {
	return function(name1){return "pub fn init(arguments:anytype)"+name1+"{"+params+" var self = "+name1+"{"+class_members+"};"+body+"return self;}";};
}

class_statement = constructor / instance_method  / static_method / a:class_member _ ";" {return function(name1){return a(name1) + ","}}

class_member = a:var_name _ ":" _ b:type {
	if(class_members !== "") class_members += ","; class_members += "."+a+"=undefined";
	return function(name1){return a+":"+b;};
}

access_modifier= "public" / "private"

class_=
	"type" __ a:var_name _ "=" _ b:type ";" {return "\ntype "+a+" = "+b+";\n";}
	/ "enum" __ a:var_name __ "{" __ m:enum_members __ "}" {return "enum "+a+" = {"+m+"}";}
	/ "class" __ name:var_name  super_class:( _ "extends" _ var_name / "") _ "{" _ a4:class_statements _ "}" {
		class_name = name;
		let to_return = "";
		let class_body = a4(name);
		to_return = "type "+name+" = record("+class_body+");"
		return to_return;
	}

statement =
	a1:statement_ {return a1;}
	/ a1:statement_with_semicolon _ (";" / "") {
		return a1
	}

statement_
    =
    class_
    / "if" _ "(" _ a3:e _ ")" _ a5:bracket_statements _ a6:elif {expression_types[a3] = "bool"; return ["if ",a3," then ",a5," ",a6].join("");}
	/ "if" _ "(" _ a3:e _ ")" _ a5:bracket_statements {expression_types[a3] = "bool"; return ["if ",a3," then ",a5].join("");}
    / "function" __ name:var_name _ "(" _ b:function_parameters _ ")" _ t1:(":" _ type _ / "") "{" _ c:statements _ "}" {
		let return_type = "@TypeOf("+initial_value[returned]()+")";
		if(t1.length > 0){
			return_type = t1[2]; 
		}
		return "function " + return_type+": "+name+"("+b+") = "+c+";"
	}

identifiers = head:var_name tail:(_ (',') _ var_name)* {
      return tail.reduce(function(result, element) {
        return result + element[1] + element[3];
      }, head);
    }

statement_with_semicolon
   = 
   "return" __ a2:e  {
		returned = a2;
		//alert(returned);
		return a2;
	}
		
   / "return"  {return "return";}
   / ("const" / "var" / "let") __ name:var_name _ "=" _ val:e
	
	{ initial_value[name]=function(){return val;}; return "any:" + name + " = "+val; }
   / ("let" / "var" / "const") __ name:var_name _ ":" _ t1:type _ "=" _ val:e {
		initial_value[name]=function(){return val;}; return t1+":" + name + " = "+val;
   }
   / name:assignable _ a2:"=" _ val:e {
   		initial_value[name]=function(){return val;};
   		if(temp_vars.indexOf(val) !== -1){declared_redundant_vars[val] = name; return "";}
		else{
			return name+a2+val;
		}
   }
   / a1:assignable _ a2:("++" / "--") {return a1+a2;}
   / a1:assignable _ a2:("+=" / "%=" / "-=" / "*=" / "/=") _ a3:e {return a1+a2+a3;}
   / var_name


type =  t1:type_ "[" "]" {return t1+"[]";} / "Array" "<" t1:type_ ">" {return type+"[]";} / type_
type_ = name:var_name {return name;}
types = head:type tail:(_ (',') _ type)* {
      return tail.reduce(function(result, element) {
        return result + element[1] + element[3];
      }, head);
    } / "" {return "";}

e
    =
     a1:e6 _ "?" _ a3:e6 _ ":" _ a5:e {expression_types[a3] = "bool"; return "("+a1+"?"+a3+":"+a5+")";}
    /e6


e6
  = head:e5 tail:(_ ("||") _ e5)* {
      let to_return = tail.reduce(function(result, element) {
        let to_return = result + " || " + element[3]; expression_types[to_return] = "bool"; expression_types[result] = "bool"; expression_types[element[3]] = "bool"; return to_return;
      }, head);
      return to_return;
    }

e5
  = head:e4 tail:(_ ("&&") _ e4)* {
      let to_return = tail.reduce(function(result, element) {
        let to_return = result + " && " + element[3]; expression_types[to_return] = "bool"; expression_types[result] = "bool"; expression_types[element[3]] = "bool"; return to_return;
      }, head);
      return to_return;
    }

e4_op= '!==' {return "!=";} / "===" {return "==";}

e4
  = head:e3 tail:(_ ('<='/'<'/'>='/'>'/e4_op) _ e3)* {
      let to_return = tail.reduce(function(result, element) {
        let to_return = result + element[1] + element[3]; expression_types[to_return] = "bool"; if([1] === "==" || element[1] === "==="){unify_expression_types(result,element[3]);} else{expression_types[result] = "float";} expression_types[element[3]] = "float"; return to_return;
      }, head);
      if(tail.length > 0) {initial_value[to_return] = function(){return initial_value[head]();};}
      return to_return;
    }

e3
  = head:e2 tail:(_ ('>>'/'<<') _ e2)* {
      let to_return = tail.reduce(function(result, element) {
        return result + element[1] + element[3];
      }, head);
      if(tail.length > 0) {initial_value[to_return] = function(){return initial_value[head]();};}
      return to_return;
    }

e2
  = head:e1 tail:(_ ('+'/'-') _ e1)* {
        let to_return = tail.reduce(function(result, element) {
        let to_return = result + element[1] + element[3];
        expression_types[to_return] = "float";
        expression_types[result] = "float";
        expression_types[element[3]] = "float";
        return to_return;
      }, head);
      if(tail.length > 0) {initial_value[to_return] = function(){return initial_value[head]();};}
      return to_return;
    }
    
e1= head:not_expr tail:(_ ('*' / '/' / '%') _ not_expr)* {
      let to_return = tail.reduce(function(result, element) {
        let to_return = result + element[1] + element[3];
        expression_types[to_return] = "float";
        expression_types[result] = "float";
        expression_types[element[3]] = "float";
        return to_return;
      }, head);
      if(tail.length > 0) {initial_value[to_return] = function(){return initial_value[head]();};}
      return to_return;
    }
    / '-' _ a2:e1
        {let to_return = "-"+a2; initial_value[to_return] = function(){return initial_value[a2]();}; return to_return;}

assignable = head:dot_expr tail:(_ access_array_)* {
      let to_return = tail.reduce(function(result, element) {
        let to_return = result + element[1];
        if((expression_types[result] !== undefined) && expression_types[result].endsWith("[]")){
			expression_types[to_return] = expression_types[result].substring(0,expression_types[result].length-2);
		}
        return to_return;
      }, head);
    }

access_array = head:function_call tail:(_ access_array_)* {
      let to_return = tail.reduce(function(result, element) {
        let to_return = result + element[1];
        if((expression_types[result] !== undefined) && expression_types[result].endsWith("[]")){
			expression_types[to_return] = expression_types[result].substring(0,expression_types[result].length-2);
		}
        return to_return;
      }, head);
      return to_return;
    }

access_array_ = "[" _ a:e _ "]" {expression_types[a] = "float"; let to_return = "["+a+"]"; initial_value[to_return] = function(){return "[" + initial_value[a]() + "]";}; return to_return;}

function_call
  = head:callable tail:(_ function_call_ / "") {
	  var split_head = head.split(".");
      if(split_head.length === 2 && split_head[0] === "compiled_Math" && (["compiled_round","compiled_sin","compiled_asin","compiled_acos","compiled_atan","compiled_asinh","compiled_acosh","compiled_atanh","compiled_min","compiled_max","compiled_cos","compiled_tan","compiled_sinh","compiled_cosh","compiled_tanh","compiled_abs","compiled_floor","compiled_ceil","compiled_exp","compiled_pow","compiled_log","compiled_log2","compiled_sqrt","compiled_trunc","compiled_sign"].indexOf(split_head[1]) !== -1)){
	      let to_return = split_head[1].substring("compiled_".length,split_head[1].length) + tail[1];
	      expression_types[to_return] = "float";
	      return to_return;
      }
      else if(head === "compiled_Number"){
		  let to_return = "float" + tail[1];
	      expression_types[to_return] = "float";
	      return to_return;
      }
      else if(head === "compiled_typeof"){
		  return "@TypeOf"+tail[1];
      }
      else if(head === "compiled_Boolean"){
		  let to_return = "float" + tail[1];
	      expression_types[to_return] = "bool";
	      return to_return;
      }
      else if(tail.length > 0){
		return head+tail[1];
	  }
	  else{
	    return head;
	  }
    }

function_call_ = "(" _ a2:exprs _ ")" {return "("+a2+")";}

not_expr= a1:"!" _ a2:access_array {let to_return = "!"+a2; expression_types[a2] = "bool"; expression_types[to_return] = "bool"; return to_return;} / access_array

object_member = a1:var_name _ ":" _ e1:e {return a1+":"+e1;}

object_members = head:object_member tail:(_ (',') _ object_member)* {
      return tail.reduce(function(result, element) {
        return result+","+element[3];
      }, head);
    } / "" {return "";}
    
enum_member = a1:var_name e1:(_ "=" _ e1:e / "") {
	if(e1.length > 0)
	return +a1+"="+e1[3];
	else return a1;
}

enum_members = head:enum_member tail:(_ (',') _ enum_member)* ","* {
      return tail.reduce(function(result, element) {
        return result+","+element[3];
      }, head);
    } / "" {return "";}

callable=
	"(" _ a2:e _ ")" {let to_return  ="("+a2+")"; expression_types[to_return] = expression_types[a2]; return to_return;}
	/ "new" __ a:dot_expr "(" b:exprs ")" {return a+".init("+b+")"}
    / "[" a2:array_exprs "]" {return "["+a2[1]+"]";}
	/ "{" _ a:object_members _ "}" {
	
	  return "("+a+")"
	
	
	}
	/ "function" _ "(" _ params:function_parameters _ ")" _ t1:type _ "{" _ body:statements _ "}" {
		return "struct{pub fn function(arguments:anytype) "+t1+"{"+params+body+"}}.function"
	}
	/ "class" _ super_class:("extends" __ var_name / "") _ "{" _ a4:class_statements _ "}" {
		if(super_class.length > 0){
			return "struct{usingnamespace "+super_class[3]+";"+a4(name)+"};";
		}
		return "const "+name+" = struct{"+a4(name)+"};";
	}
	/ dot_expr
    / STRING_LITERAL
    / a:NUMBER {expression_types[a] = "float"; return a;}

dot_expr = head:var_name tail:(_ ('.') _ var_name)* {
      let to_return = tail.reduce(function(result, element) {
        return result + element[1] + element[3];
      }, head);
      if(to_return === "compiled_Math.compiled_PI")
		return "radians(180)";
	  else if(to_return === "compiled_Math.compiled_SQRT2")
		return "sqrt(2.)";
	  else if(to_return === "compiled_Math.compiled_LN10")
		return "log(10.)";
      else if(to_return === "compiled_Math.compiled_LN2")
		return "log(2.)";
	  else if(to_return === "compiled_Math.compiled_SQRT2")
		return "sqrt(2.)";
	  else if(to_return === "compiled_Math.compiled_SQRT1_2")
		return "sqrt(.5)";
	  else return to_return;
    }


function_parameter = a1:var_name _ ":" _ t1:type {return [t1+":"+a1];} /
a1:var_name {return ["var "+a1];}

function_parameters = head:function_parameter tail:(_ (',') _ function_parameter)* {
      return (tail.reduce(function(result, element) {
        return result.concat(element[3]);
      }, head)).map(function(value,index){initial_value[value]=function(){return "arguments["+index+"]";};
		  //alert(initial_value[value]);
		  return value;}).join(",");
    } / "" {return "";}

exprs = head:e tail:(_ (',') _ e)* {
      return tail.reduce(function(result, element) {
        return result + element[1] + element[3];
      }, head);
    } / "";

array_exprs = head:e tail:(_ (',') _ e)* {
      return [head,tail.reduce(function(result, element) {
        type_in_arr = expression_types[element[3]];
        return result + element[1] + element[3];
      }, head)];
    } / "";

else_if= "else" __ "if" / "elseif";
elif = head:elif_ tail:(_ elif_)* {
      return tail.reduce(function(result, element) {
        return result + element[1] + element[3];
      }, head);
    } / "else" a2:bracket_statements {return "else {"+a2+"}";}

elif_ = a1:else_if _ "(" _ a3:e _ ")" _ a5:bracket_statements {return "else if("+a3+"){"+a5+"}";}

var_name= name:IDENTIFIER {
let to_return = "";
if(name == "this") to_return = "self"; else if(["true","false","undefined","void","break","continue","arguments"].includes(name)) to_return = name; else to_return = (name === "number"?"float":name==="boolean"?"bool":"compiled_"+name);
if(initial_value[to_return] === undefined){initial_value[to_return] = function(){return to_return;};}
return to_return;
}

bracket_statements= "{" _ a2:statements _ "}" {return a2;} / a1:statement_with_semicolon _ ";" {return a1;}

IDENTIFIER = [a-zA-Z_][a-zA-Z0-9_]* {return text();}
STRING_LITERAL = '"' @$([^"\\] / "\\" .)* '"'

NUMBER = a:Integer b:NUMBER_ {if(b == "") b = "0"; let to_return =  a+"."+b; initial_value[to_return] = function(){return to_return;}; return to_return;}
NUMBER_ = "." a:Integer {return a;} / ("." / "") {return "";}

Integer "integer"
  = _ [0-9]+ { return text(); }

_
  = [ \t\n\r]*
  
__
  = [ \t\n\r] [ \t\n\r]*
