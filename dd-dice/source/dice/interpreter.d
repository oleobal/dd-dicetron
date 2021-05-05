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


enum ExprDataType { NUM, STR } // bool is num

struct ExprResult {
	Algebraic!(long, long[], bool, bool[], string, string[]) value;
	
	// terrible for sure but what can you do, I can't interact with the D type system at runtime
	ExprDataType type;
	bool isArray = false;
	bool isBool = false;
	
	string repr;
	
	
	this (long   a, string b)   { value = a; repr = b; type=ExprDataType.NUM;}
	this (long[] a, string b)   { value = a; repr = b; type=ExprDataType.NUM; isArray=true;}
	this (bool   a, string b)   { value = a; repr = b; type=ExprDataType.NUM; isBool=true;}
	this (bool[] a, string b)   { value = a; repr = b; type=ExprDataType.NUM; isArray=true; isBool=true;}
	this (string   a, string b) { value = a; repr = b; type=ExprDataType.STR;}
	this (string[] a, string b) { value = a; repr = b; type=ExprDataType.STR; isArray=true;}
	
	
	ExprResult reduced()
	{
		if (value.type == typeid(long[]))
			return ExprResult(value.get!(long[]).sum, repr);
		if (value.type == typeid(bool[]))
		{
			if (value.get!(bool[]).length == 1)
				return ExprResult(value.get!(bool[])[0], repr);
			return ExprResult(value.get!(bool[]).sum, repr);
		}
		
		if (value.type == typeid(long))
			return ExprResult(value.get!long, repr);
		if (value.type == typeid(bool))
			return ExprResult(value.get!bool, repr);
		
		if (value.type == typeid(string))
			return ExprResult(value.get!string, repr);
		if (value.type == typeid(string[]))
			return ExprResult(value.get!(string[]), repr);
		
		throw new Exception("Unhandled type: "~value.type.to!string);
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


ExprResult eval(ParseTree tree)
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
			auto prevOperand = tree.children[0].eval.reduced;
			auto result = ExprResult(true, prevOperand.repr);
			foreach(c;tree.children[1..$])
			{
				// Python-style chained comparisons https://docs.python.org/3.8/reference/expressions.html#comparisons
				auto secondOperand = c.children[0].eval.reduced;
				
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
				return tree.children[0].eval;
			auto base = tree.children[0].eval.reduced;
			mixin(TypeArithmeticRestriction!"base");
			foreach(c;tree.children[1..$])
			{
				immutable auto cfactor = c.children[0].eval.reduced;
				mixin(TypeArithmeticRestriction!"cfactor");
				if (c.name == "DiceExpr.Add")
				{
					base.value=base.value+cfactor.value;
					base.repr=base.repr~"+"~cfactor.repr;
				}
				else if (c.name == "DiceExpr.Sub")
				{
					base.value=base.value-cfactor.value;
					base.repr=base.repr~"-"~cfactor.repr;
				}
				else
					throw new EvalException("Unhandled factor: "~c.name);
				
			}
			return base;
		
		case "Factor":
			if (tree.children.length == 1)
				return tree.children[0].eval;
			auto base = tree.children[0].eval.reduced;
			mixin(TypeArithmeticRestriction!"base");
			foreach(c;tree.children[1..$])
			{
				immutable auto cfactor = c.children[0].eval.reduced;
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
		// can get that working for UFCS (it would be better..)
		case "DotCall":
			auto funcName = tree.children[1];
			auto firstArg = tree.children[0];
			tree.children[0] = funcName;
			tree.children[1] = firstArg;
			goto case;
		case "FunCall":
			return callFunction(
				tree.children[0].matches[0],
				tree.children[1..$].map!(a=>a.eval).array,
				tree.name.chompPrefix("DiceExpr.")
			);
		
		
		
		case "MulDie":
		case "Die":
		case "PictDie":
			auto noOfDice = 1L;
			auto die=tree;
			if (tree.name == "DiceExpr.MulDie")
			{
				die = tree.children[1];
				noOfDice = tree.children[0].eval.value.coerce!long;
			}
			
			if (die.name == "DiceExpr.Die")
			{
				auto sizeOfDice = die.children[0].eval.value.coerce!long;
				// safeties at about 0.01% of long.max
				// (this check is per dice roll, and long.max is for the entire result, so..)
				if (noOfDice  > 9_999_999 || noOfDice<0)
					return ExprResult(0L, "[too many dice]");
				if (sizeOfDice>99_999_999 ||sizeOfDice<0)
					return ExprResult(0L, "[dice too large]");
				if (noOfDice == 0)
					return ExprResult(0, "[0]");
				
				
				if (sizeOfDice <= 2)
				{
					auto dice = flipCoins(noOfDice, sizeOfDice);
					return ExprResult(dice, "["~dice.map!(x=>x.to!byte.to!string).join("+")~"]");
				}
				
				auto dice = rollDice(noOfDice, sizeOfDice);
				return ExprResult(dice, "["~dice.map!(x=>x.to!string).join("+")~"]");
			}
			else if (die.name == "DiceExpr.PictDie")
			{
				auto choices = die.children.map!(x=>x.eval.reduced.value.get!string);
				string[] dice = generate!(() => choices.choice).takeExactly(noOfDice).array;
				return ExprResult(dice, "["~dice.join(",")~"]");
			}
			else
				throw new Exception("Unknown dice type: "~die.name);
			
		
		case "Neg":
			auto base = tree.children[0].eval.reduced;
			base.value = -base.value.get!long;
			base.repr = "-"~base.repr;
			return base;
		
		case "Not":
			auto base = tree.children[0].eval.reduced;
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
			return ExprResult(tree.matches[0].to!long, tree.matches[0]);
		
		case "UnqStr":
		case "String":
			return ExprResult(tree.matches[0], '"'~tree.matches[0]~'"');
		
		case "DiceExpr":
			return tree.children[0].eval.reduced;
		case "Expr":
		case "Pos":
		case "Primary":
			return tree.children[0].eval;
		
		default:
			throw new EvalException("Unknown case: "~tree.name);
	}
	
}

ExprResult callFunction(string name, ExprResult[] args, string callingStyle="FunCall")
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
	
	auto best(alias predicate)(ExprResult[] args)
	{
		auto nbToTake=1L;
		if (args.length>2)
			throw new Exception("too many arguments");
		if (args.length==2)
			nbToTake=args[1].value.get!long;
		if (nbToTake<=0)
			nbToTake=max(0, args[0].value.length);
		if (args[0].type != ExprDataType.NUM)
			throw new Exception("only numeric types handled");
		if (args[0].isArray)
		{
			if (args[0].isBool)
				return ExprResult(args[0].value.get!(bool[]).sort!(predicate)[0..nbToTake].array, "");
			else
				return ExprResult(args[0].value.get!(long[]).sort!(predicate)[0..nbToTake].array, "");
		}
		else
			return args[0];
	}
	
	
	ExprResult res;
	switch (name)
	{
		case "best":
			res = best!"a > b"(args);
			break;
		case "worst":
			res = best!"a < b"(args);
			break;
		default:
			throw new Exception("Unknown function: "~name);
	}
	
	res.repr = repr;
	return res;
}

