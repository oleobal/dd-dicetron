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

/+
 + bools for difficulty rolls (eg d20+5 > 17)
 + strings for name dice and also errors >_>
 +/
struct ExprResult {
	Algebraic!(long, bool, string) value;
	string repr;
	this (long   a, string b) { value = a; repr = b; }
	this (bool   a, string b) { value = a; repr = b; }
	this (string a, string b) { value = a; repr = b; }
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
	
	switch (tree.name.chompPrefix("DiceExpr."))
	{
		case "Comp":
			auto previousOperand = tree.children[0].eval;
			auto result = ExprResult(true, previousOperand.repr);
			foreach(c;tree.children[1..$])
			{
				// Python-style chained comparisons https://docs.python.org/3.8/reference/expressions.html#comparisons
				auto secondOperand = c.children[0].eval;
				
				if (previousOperand.value.type != secondOperand.value.type)
					throw new EvalException(
						"Can't compare values of type "
						~previousOperand.value.type.to!string
						~" and "~secondOperand.value.type.to!string
					);
				bool thisOpResult;
				if (c.name == "DiceExpr.Eq")
					thisOpResult = previousOperand.value == secondOperand.value;
				else if (c.name == "DiceExpr.NEq")
					thisOpResult = previousOperand.value != secondOperand.value;
					
				else
				{
					if (previousOperand.value.type != typeid(long))
						throw new EvalException(
							"Can't do other comparisons than equality on "~previousOperand.value.type.to!string
						);
					switch (c.name.chompPrefix("DiceExpr."))
					{
						case "Inf":
							thisOpResult = previousOperand.value < secondOperand.value;
							break;
						case "InfEq":
							thisOpResult = previousOperand.value <= secondOperand.value;
							break;
						case "Sup":
							thisOpResult = previousOperand.value > secondOperand.value;
							break;
						case "SupEq":
							thisOpResult = previousOperand.value >= secondOperand.value;
							break;
						default:
							throw new EvalException("Unhandled comparison: "~c.name);
					}
					
				}
				result.value = result.value.get!bool && thisOpResult;
				result.repr = result.repr ~ c.matches[0] ~secondOperand.repr;
				previousOperand = secondOperand;
			}
			return result;
		
		
		
		
		case "Term":
			auto base = tree.children[0].eval;
			if (base.value.type != typeid(long))
				throw new EvalException("Can't do arithmetic on "~base.value.type.to!string);
			
			foreach(c;tree.children[1..$])
			{
				const auto cfactor = c.children[0].eval;
				if (cfactor.value.type != typeid(long))
					throw new EvalException("Can't do arithmetic on "~cfactor.value.type.to!string);
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
			auto base = tree.children[0].eval;
			if (base.value.type != typeid(long))
				throw new EvalException("Can't do arithmetic on "~base.value.type.to!string);
			foreach(c;tree.children[1..$])
			{
				const auto cfactor = c.children[0].eval;
				if (cfactor.value.type != typeid(long))
					throw new EvalException("Can't do arithmetic on "~cfactor.value.type.to!string);
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
			if (noOfDice == 0 || sizeOfDice == 0)
				return ExprResult(0L, "[0]");
			
			auto dice = rollDice(noOfDice, sizeOfDice);
			return ExprResult(dice.sum, "["~dice.map!(x=>x.to!string).join("+")~"]");
		
		case "Neg":
			auto base = eval(tree.children[0]);
			base.value = -base.value.get!long;
			base.repr = "-"~base.repr;
			return base;
		
		case "Not":
			auto base = eval(tree.children[0]);
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
		case "Expr":
		case "Pos":
		case "Primary":
			return tree.children[0].eval;
		
		default:
			throw new EvalException("Unknown case: "~tree.name);
	}
	
}