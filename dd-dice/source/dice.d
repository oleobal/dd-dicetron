module dice;

import std.string;
import std.variant;
import std.conv;
import std.random;
import std.range;
import std.array;
import std.algorithm.iteration;

import pegged.grammar;



mixin(grammar(`
DiceExpr:
	Expr     < Comp / Term
	
	Comp     < Term (Eq / NEq / Inf / InfEq / Sup / SupEq)+
	
	Eq       < "==" Term
	NEq      < "!=" Term
	Inf      < "<"  Term
	InfEq    < "<=" Term
	Sup      < ">"  Term
	SupEq    < ">=" Term
	
	
	Term     < Factor (Add / Sub)*
	Add      < "+" Factor
	Sub      < "-" Factor
	Factor   < Primary (Mul / Div)*
	Mul      < "*" Primary
	Div      < "/" Primary
	Primary  < MulDie / Parens / Not / Neg / Pos / Die / Number 
	Parens   < "(" Expr ")"
	Not      < "!" Primary
	Neg      < "-" Primary
	Pos      < "+" Primary
	MulDie   < Primary Die
	Die      < "d" Number
	Number   < ~([0-9]+)
`));


auto parse(string expr)
{
	return DiceExpr(expr);
}


long[] rollDice(long number, long die)
{
	return generate!(() => uniform!"[]"(1, die)).takeExactly(number).array;
}
bool[] flipCoins(long number)
{
	return generate!(() => [true, false].choice).takeExactly(number).array;
}

struct ExprResult {
	Algebraic!(long, long[], bool, bool[]) value;
	string repr;
	this (long   a, string b) { value = a; repr = b; }
	this (long[] a, string b) { value = a; repr = b; }
	this (bool   a, string b) { value = a; repr = b; }
	this (bool[] a, string b) { value = a; repr = b; }
	
	ExprResult reduced() const
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
		const string TypeArithmeticRestriction =
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
				const auto cfactor = c.children[0].eval.reduced;
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
				const auto cfactor = c.children[0].eval.reduced;
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
		
		
		case "MulDie":
		case "Die":
			auto noOfDice = 1L, sizeOfDice = 1L;
			if (tree.name == "DiceExpr.MulDie")
			{
				noOfDice = tree.children[0].eval.value.coerce!long;
				sizeOfDice = tree.children[1].children[0].eval.value.coerce!long;
			}
			else
				sizeOfDice = tree.children[0].eval.value.coerce!long;
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
				bool[] dice;
				if (sizeOfDice == 0)
					dice = false.repeat.takeExactly(noOfDice).array;
				if (sizeOfDice == 1)
					dice = true.repeat.takeExactly(noOfDice).array;
				else if (sizeOfDice == 2)
					dice = flipCoins(noOfDice);
				return ExprResult(dice, "["~dice.map!(x=>x.to!byte.to!string).join("+")~"]");
			}
			
			auto dice = rollDice(noOfDice, sizeOfDice);
			return ExprResult(dice, "["~dice.map!(x=>x.to!string).join("+")~"]");
		
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