module dice.interpreter;

import std.string;
import std.variant;
import std.conv;
import std.random;
import std.range;
import std.array;
import std.algorithm;

import dice.parser;
import dice.roll;

/// is T or a subclass of T
bool isA(T)(const Object o)
{
	return (cast(T) o) ?true:false;
}

/// is T, but not a subclass
bool isExactlyA(T)(const Object o)
{
	return (typeid(o) == typeid(T));
}



abstract class ExprResult {
	Algebraic!(long, bool, string, ExprResult[]) value;
	
	/// string representation to give insight into the interpreter
	string repr;
	
	abstract ExprResult reduced();
	
	override string toString() const // adding const causes problems I don't understand
	{
		
		if (value.type == typeid(ExprResult[]))
			return value.get!(ExprResult[]).map!(it=>it.to!string).join(",");
		else if ( value.type == typeid(long))
			return value.get!long.to!string;
		else if ( value.type == typeid(bool))
			return value.get!bool.to!string;
		else if ( value.type == typeid(string))
			return value.get!string;
		else
			return value.to!string;
			// doesn't work well with const
			// because VariantN.coerce doesn't work on const objects
		
		
	}
	
	override bool opEquals(const Object o) const
	{
		if (typeid(o) == typeid(this))
		{
			auto oa = cast(ExprResult) o;
			return this.value == oa.value;
		}
		else
			return false;
	}
}

interface List {
}

class Num : ExprResult
{
	this() {}
	this (long a) { value = a ; repr = a.to!string; }
	this (long a, string b) { value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new Num(value.get!long, repr);}
}
class NumList : Num, List
{
	this() {}
	this (long[] a, string b) { value = a.map!(it=>cast(ExprResult) new Num(it)).array; repr = b; }
	this (ExprResult[] a) { this(a, "["~a.map!(it=>it.to!string).join("+")~"]"); }
	this (ExprResult[] a, string b) { assert(a.all!(it=>it.isA!Num)) ; value = a; repr = b; }
	override ExprResult reduced() {
		return cast(ExprResult) new Num(value.get!(ExprResult[]).map!(it=>it.value.get!long).sum, repr);
	}
}
class Bool : Num
{
	this() {}
	this (bool a) { value = a; repr = a?"T":"F";}
	this (bool a, string b) { value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new Bool(value.get!bool, repr);}
}
class BoolList : Bool, List
{
	this() {}
	this (bool[] a, string b) { value = a.map!(it=>cast(ExprResult) new Bool(it)).array; repr = b; }
	this (ExprResult[] a) { this(a, "["~a.map!(it=>it.to!string).join("+")~"]"); }
	this (ExprResult[] a, string b) { assert(a.all!(it=>it.isA!Bool)) ; value = a; repr = b; }
	
	
	override ExprResult reduced() {
		auto l = value.get!(ExprResult[]);
		if (l.length == 1)
			return cast(ExprResult) new Bool(l[0].value.get!bool, repr);
		
		return cast(ExprResult) new Num(l.map!(it=>it.value.get!bool).sum, repr);
	}
}
class String : ExprResult
{
	this() {}
	this (string a) { value = a; repr = a; }
	this (string a, string b) { value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new String(value.get!string, repr);}
}
class StringList : String, List
{
	this() {}
	this (string[] a, string b) { value = a.map!(it=>cast(ExprResult) new String(it)).array; repr = b; }
	this (ExprResult[] a) { this(a, a.to!string); }
	this (ExprResult[] a, string b) { assert(a.all!(it=>it.isA!String)) ; value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new StringList(value.get!(ExprResult[]), repr);}
}
class MixedList : String, List
{
	this() {}
	this (ExprResult[] a) { value = a; repr = a.to!string; }
	this (ExprResult[] a, string b) { value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new MixedList(value.get!(ExprResult[]), repr);}
}
class Function : ExprResult
{
	string[] args;
	ParseTree code;
	
	this() {}
	this(string[] args, ParseTree code, string repr)
	{
		this.args=args;
		this.code=code;
		this.repr=repr;
	}
	
	ExprResult call(Context c)
	{
		return eval(code, c);
	}
	
	override ExprResult reduced()
	{
		return cast(ExprResult) new Function(args, code, repr);
	}
	override bool opEquals(const Object o) const
	{
		if (typeid(o) == typeid(this))
		{
			auto oa = cast(Function) o;
			return this.args == oa.args && this.code == oa.code;
		}
		else
			return false;
	}
	override string toString() const
	{
		return repr;
	}
	override size_t toHash() const
	{
		// Counting on the repr being about equal to code.input[code.begin..code.end]
		return typeid(repr).getHash(&repr);
	}
}




string spaces(uint indent)
{
	import std.range:repeat;
	return ' '.repeat(indent*2).to!string;
}

class Context
{
	Context outer;
	
	ExprResult[string] contents;
	
	ExprResult opIndex(string i)
	{
		if (i in contents)
			return contents[i];
		else
		{
			if (outer)
				return outer[i];
			else
				throw new Exception("Undefined: "~i.to!string);
		}
	}
	
	ExprResult opIndexAssign(ExprResult val, string key)
	{
		return contents[key] = val;
	}
	
	/++
	 + will go up to the outer context to change the key at the source
	 +/
	ExprResult overwrite(string key, ExprResult val)
	{
		if (key in contents)
			return contents[key] = val;
		else
		{
			if (outer)
				return outer.overwrite(key, val);
			else
				throw new Exception("Undefined: "~key.to!string);
		}
	}
	
	this() {}
	
	this(Context outer)
	{
		this.outer = outer;
	}
	
	
	override string toString() const
	{
		return toString(0);
	}
	
	string toString(uint indent) const
	{
		string result = spaces(indent)~"Context(";
		foreach(k,v;contents)
			result~="\n"~spaces(indent+1) ~ k ~ " : " ~ v.to!string;
		if (outer)
			result~="\n"~outer.toString(indent+1);
		if (result != spaces(indent)~"Context(")
			result~="\n";
		result~=")";
		return result;
	}
}









class EvalException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

auto eval(string expr)
{
	return expr.parse.eval;
}


ExprResult eval(ParseTree tree, Context context=new Context())
{
	/+ https://github.com/PhilippeSigaud/Pegged/wiki/Generating-Code
	 + probably a more clever way to do it but I'm too stupid right now
	 +/
	template TypeArithmeticRestriction(string var) {
		immutable string TypeArithmeticRestriction =
		q{
		if (}~var~q{.value.type != typeid(long) && }~var~q{.value.type != typeid(bool) )
			throw new EvalException("Can't do arithmetic on "~}~var~q{.value.type.to!string);
		};
	}
	switch (tree.name.chompPrefix("DiceExpr."))
	{
		case "Comp":
			auto prevOperand = tree.children[0].eval(context).reduced;
			auto result = cast(ExprResult) new Bool(true, prevOperand.repr);
			foreach(c;tree.children[1..$])
			{
				// Python-style chained comparisons https://docs.python.org/3.8/reference/expressions.html#comparisons
				auto secondOperand = c.children[0].eval(context).reduced;
				
				if (prevOperand.value.type != secondOperand.value.type)
					throw new EvalException(
						"Can't compare values of type "
						~prevOperand.value.type.to!string
						~" and "~secondOperand.value.type.to!string
					);
				bool thisOpResult;
				if (c.name == "DiceExpr.Eq")
					thisOpResult = prevOperand.value == secondOperand.value;
				else if (c.name == "DiceExpr.NEq")
					thisOpResult = prevOperand.value != secondOperand.value;
					
				else
				{
					if (prevOperand.value.type != typeid(long))
						throw new EvalException(
							"Can't do other comparisons than equality on "~prevOperand.value.type.to!string
						);
					switch (c.name.chompPrefix("DiceExpr."))
					{
						case "Inf":
							thisOpResult = prevOperand.value < secondOperand.value;
							break;
						case "InfEq":
							thisOpResult = prevOperand.value <= secondOperand.value;
							break;
						case "Sup":
							thisOpResult = prevOperand.value > secondOperand.value;
							break;
						case "SupEq":
							thisOpResult = prevOperand.value >= secondOperand.value;
							break;
						default:
							throw new EvalException("Unhandled comparison: "~c.name);
					}
					
				}
				result.value = result.value.get!bool && thisOpResult;
				result.repr = result.repr ~ c.matches[0] ~secondOperand.repr;
				prevOperand = secondOperand;
			}
			return result;
		
		
		case "Term":
			if (tree.children.length == 1)
				return tree.children[0].eval(context);
			auto base = tree.children[0].eval(context).reduced;
			if (!(  (base.isA!Num && !base.isA!List) || base.isA!StringList))
				throw new Exception("Can't do arithmetic on "~base.repr);
			foreach(c;tree.children[1..$])
			{
				auto cfactor = c.children[0].eval(context).reduced;
				if (!(  (base.isA!Num && !base.isA!List) || base.isA!StringList))
					throw new Exception("Can't do arithmetic on "~cfactor.repr);
				
				if (c.name == "DiceExpr.Add")
				{
					// asserted earlier NUM aren't arrays and STR are
					if (base.isA!String || cfactor.isA!String)
					{
						if (!base.isA!String)
							base = new StringList([base.value.coerce!string], base.repr);
						if (!base.isA!String)
							cfactor = new StringList([cfactor.value.coerce!string], cfactor.repr);
						base.value=base.value~cfactor.value;
					}
					else if (base.isA!Num && cfactor.isA!Num)
						base.value=base.value+cfactor.value;
					else
						throw new Exception("Can't add terms "~base.repr~" and "~cfactor.repr);
					base.repr=base.repr~"+"~cfactor.repr;
				}
				else if (c.name == "DiceExpr.Sub")
				{
					if (!base.isA!Num || !cfactor.isA!Num)
						throw new Exception("Can't substract terms "~base.repr~" and "~cfactor.repr);
					base.value=base.value-cfactor.value;
					base.repr=base.repr~"-"~cfactor.repr;
				}
				else
					throw new EvalException("Unhandled factor: "~c.name);
				
			}
			return base;
		
		case "Factor":
			if (tree.children.length == 1)
				return tree.children[0].eval(context);
			auto base = tree.children[0].eval(context).reduced;
			mixin(TypeArithmeticRestriction!"base");
			foreach(c;tree.children[1..$])
			{
				auto cfactor = c.children[0].eval(context).reduced;
				mixin(TypeArithmeticRestriction!"cfactor");
				if (c.name == "DiceExpr.Mul")
				{
					base.value=base.value*cfactor.value;
					base.repr=base.repr~"*"~cfactor.repr;
				}
				else if (c.name == "DiceExpr.Div")
				{
					base.value=base.value/cfactor.value;
					base.repr=base.repr~"/"~cfactor.repr;
				}
				else
					throw new EvalException("Unhandled factor: "~c.name);
				
			}
			return base;
		
		// https://github.com/PhilippeSigaud/Pegged/wiki/Semantic-Actions
		// can't get that working for UFCS (it would be better..)
		case "DotCall":
			auto funcName = tree.children[1];
			auto firstArg = tree.children[0];
			tree.children[0] = funcName;
			tree.children[1] = firstArg;
			goto case;
		case "FunCall":
			return callFunction(
				tree.children[0].matches[0],
				tree.children[1..$].map!(a=>a.eval(context)).array,
				context,
				tree.name.chompPrefix("DiceExpr.")
			);
		
		
		case "LambdaDef":
			auto args = tree.children[0..$-1].map!(a=>a.matches[0]).array;
			auto repr = args.join(",")~" => "~tree.children[$-1].matches.join();
			return cast(ExprResult) new Function(args, tree.children[$-1], repr);
		
		
		case "MulDie":
		case "Die":
		case "CustomDie":
		case "PictDie":
		case "Coin":
			auto noOfDice = 1L;
			auto die=tree;
			if (tree.name == "DiceExpr.MulDie")
			{
				die = tree.children[1];
				noOfDice = tree.children[0].eval(context).reduced.value.coerce!long;
			}
			
			if (die.name == "DiceExpr.Die")
			{
				auto sizeOfDice = die.children[0].eval(context).value.coerce!long;
				// safeties at about 0.01% of long.max
				// (this check is per dice roll, and long.max is for the entire result, so..)
				if (noOfDice  > 9_999_999 || noOfDice<0)
					return cast(ExprResult) new Num(0L, "[too many dice]");
				if (sizeOfDice>99_999_999 ||sizeOfDice<0)
					return cast(ExprResult) new Num(0L, "[dice too large]");
				if (noOfDice == 0)
					return cast(ExprResult) new Num(0, "[0]");
				
				auto dice = rollDice(noOfDice, sizeOfDice);
				return cast(ExprResult) new NumList(dice, "["~dice.map!(x=>x.to!string).join("+")~"]");
			}
			else if (die.name == "DiceExpr.Coin")
			{
				bool[] coins;
				switch (die.matches[0])
				{
					case "coin":
						coins = flipCoins(noOfDice);
						break;
					case "true":
						coins = flipCoins(noOfDice, 1);
						break;
					case "false":
						coins = flipCoins(noOfDice, 0);
						break;
					default:
						throw new EvalException(`Can't flip coin `~die.matches[0]);
				}
				return cast(ExprResult) new BoolList(coins, "["~coins.map!(x=>x?"T":"F").join("+")~"]");
			}
			else if (die.name == "DiceExpr.CustomDie")
			{
				auto choices = die.children.map!(x=>x.eval(context).reduced.value.get!long);
				long[] dice = generate!(() => choices.choice).takeExactly(noOfDice).array;
				return cast(ExprResult) new NumList(dice, dice.to!string);
			}
			else if (die.name == "DiceExpr.PictDie")
			{
				auto choices = die.children.map!(x=>x.eval(context).reduced.value.get!string);
				string[] dice = generate!(() => choices.choice).takeExactly(noOfDice).array;
				return cast(ExprResult) new StringList(dice, "["~dice.join(",")~"]");
			}
			else
				throw new Exception("Unknown dice type: "~die.name);
			
		
		case "Neg":
			auto base = tree.children[0].eval(context).reduced;
			base.value = -base.value.get!long;
			base.repr = "-"~base.repr;
			return base;
		
		case "Not":
			auto base = tree.children[0].eval(context).reduced;
			base.value = !base.value.get!bool;
			base.repr = "!"~base.repr;
			return base;
		
		case "Parens":
		case "BParens":
			auto base = eval(tree.children[0]);
			base.repr = "("~base.repr~")";
			return base;
			
		case "Number":
			assert (tree.matches.length==1);
			return cast(ExprResult) new Num(tree.matches[0].to!long, tree.matches[0]);
		
		case "UnqStr":
		case "String":
			return cast(ExprResult) new String(tree.matches[0], '"'~tree.matches[0]~'"');
		
		case "Ident":
			return context[tree.matches[0]];
		
		case "DiceExpr":
			return tree.children[0].eval(context).reduced;
		case "FullExpr":
		case "Expr":
		case "Pos":
		case "Primary":
			return tree.children[0].eval(context);
		
		default:
			throw new EvalException("Unknown case: "~tree.name);
	}
	
}

ExprResult callFunction(string name, ExprResult[] args, Context context, string callingStyle="FunCall")
{
	string repr;
	if (callingStyle == "DotCall" && args.length>0)
	{
		repr = args[0].repr~"."~name;
		if (args.length>1)
			repr~="("~args[1..$].map!(a=>a.repr).join(", ")~")";
	}
	else
		repr = name~"("~args.map!(a=>a.repr).join(", ")~")";
	
	ExprResult fBest(alias predicate)(ExprResult[] args)
	{
		auto nbToTake=1L;
		if (args.length>2)
			throw new EvalException("best & worst take one or two args");
		if (args.length==2)
			nbToTake=args[1].value.get!long;
		if (nbToTake<=0)
			nbToTake=max(0, args[0].value.length);
		if (!args[0].isA!Num)
			throw new EvalException("best & worst only handle numeric types");
		if (args[0].isA!List)
		{
			if (args[0].isA!Bool)
				return cast(ExprResult) new BoolList(args[0].value.get!(bool[]).sort!(predicate)[0..nbToTake].array, "");
			else
				return cast(ExprResult) new NumList(args[0].value.get!(long[]).sort!(predicate)[0..nbToTake].array, "");
		}
		else
			return args[0];
	}
	
	ExprResult fMax(alias predicate)(ExprResult[] args)
	{
		auto nbToTake=1L;
		if (args.length<2)
			throw new EvalException("min & max need at least two args");
		if (!args.all!(it=>it.isA!Num))
			throw new EvalException("min & max only handle numeric types");
		
		return args.sort!(predicate)[0];
	}
	
	
	ExprResult fMap(ExprResult[] args)
	{
		if (args.length!=2)
			throw new EvalException("map takes exactly two arguments");
		if (!args[0].isA!List || args[0].isA!Function)
			throw new EvalException("map takes a list and a lambda");
		auto lambda = cast(Function) args[1];
		if (lambda.args.length != 1)
			throw new EvalException("The lambda map takes must take exactly one argument (list item)");
		
		
		ExprResult[] results;
		auto lambdaContext = new Context(context);
		foreach(a;args[0].value.get!(ExprResult[]))
		{
			lambdaContext[lambda.args[0]] = a;
			results ~= eval(lambda.code, lambdaContext);
		}
		
		if (results.all!(it=>it.isA!Bool))
			return cast(ExprResult) new BoolList(results);
		if (results.all!(it=>it.isA!Num))
			return cast(ExprResult) new NumList(results);
		if (results.all!(it=>it.isA!String))
			return cast(ExprResult) new StringList(results);
		return cast(ExprResult) new MixedList(results);
	}
	
	ExprResult fFilter(ExprResult[] args)
	{
		if (args.length!=2)
			throw new EvalException("filter takes exactly two arguments");
		if (!args[0].isA!List || args[0].isA!Function)
			throw new EvalException("filter takes a list and a lambda (that returns a bool)");
		auto lambda = cast(Function) args[1];
		if (lambda.args.length != 1)
			throw new EvalException("The lambda filter takes must take exactly one argument (list item)");
		
		
		ExprResult[] results;
		auto lambdaContext = new Context(context);
		foreach(a;args[0].value.get!(ExprResult[]))
		{
			lambdaContext[lambda.args[0]] = a;
			ExprResult result = eval(lambda.code, lambdaContext);
			if (!result.isA!Bool)
				throw new EvalException("Lambda "~lambda.repr~" returned a "~typeid(result).to!string~" instead of a bool");
			if (result.value.get!bool)
				results~=a;
		}
		
		if (results.all!(it=>it.isA!Bool))
			return cast(ExprResult) new BoolList(results);
		if (results.all!(it=>it.isA!Num))
			return cast(ExprResult) new NumList(results);
		if (results.all!(it=>it.isA!String))
			return cast(ExprResult) new StringList(results);
		return cast(ExprResult) new MixedList(results);
	}
	
	
	ExprResult res;
	switch (name)
	{
		case "best":
			res = fBest!"a > b"(args);
			break;
		case "worst":
			res = fBest!"a < b"(args);
			break;
		case "max":
			res = fMax!"a.reduced.value.get!long > b.reduced.value.get!long"(args);
			break;
		case "min":
			res = fMax!"a.reduced.value.get!long < b.reduced.value.get!long"(args);
			break;
		case "map":
			res = fMap(args);
			break;
		case "filter":
			res = fFilter(args);
			break;
		default:
			throw new EvalException("Unknown function: "~name);
	}
	
	res.repr = repr;
	return res;
}

