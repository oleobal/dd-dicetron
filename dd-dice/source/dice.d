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
	Algebraic!(long, bool, string) result;
	string repr;
	this (long   a, string b) { result = a; repr = b; }
	this (bool   a, string b) { result = a; repr = b; }
	this (string a, string b) { result = a; repr = b; }
}
auto resolve(string expr)
{
	return expr.parse.resolve;
}


ExprResult resolve(ParseTree tree)
{
	/+ https://github.com/PhilippeSigaud/Pegged/wiki/Generating-Code
	 + probably a more clever way to do it but I'm too stupid right now
	 +/
	
	switch (tree.name.chompPrefix("DiceExpr."))
	{
		case "Comp":
			auto previousOperand = tree.children[0].resolve;
			auto result = ExprResult(true, previousOperand.repr);
			foreach(c;tree.children[1..$])
			{
				// Python-style chained comparisons https://docs.python.org/3.8/reference/expressions.html#comparisons
				auto secondOperand = c.children[0].resolve;
				
				if (previousOperand.result.type != secondOperand.result.type)
					throw new Exception(
						"Can't compare values of type "
						~previousOperand.result.type.to!string
						~" and "~secondOperand.result.type.to!string
					);
				bool thisOpResult;
				if (c.name == "DiceExpr.Eq")
					thisOpResult = previousOperand.result == secondOperand.result;
				else if (c.name == "DiceExpr.NEq")
					thisOpResult = previousOperand.result != secondOperand.result;
					
				else
				{
					if (previousOperand.result.type != typeid(long))
						throw new Exception(
							"Can't do other comparisons than equality on "~previousOperand.result.type.to!string
						);
					switch (c.name.chompPrefix("DiceExpr."))
					{
						case "Inf":
							thisOpResult = previousOperand.result < secondOperand.result;
							break;
						case "InfEq":
							thisOpResult = previousOperand.result <= secondOperand.result;
							break;
						case "Sup":
							thisOpResult = previousOperand.result > secondOperand.result;
							break;
						case "SupEq":
							thisOpResult = previousOperand.result >= secondOperand.result;
							break;
						default:
							throw new Exception("Unhandled comparison: "~c.name);
					}
					
				}
				result.result = result.result.get!bool && thisOpResult;
				result.repr = result.repr ~ c.matches[0] ~secondOperand.repr;
				previousOperand = secondOperand;
			}
			return result;
		
		
		
		
		case "Term":
			auto base = tree.children[0].resolve;
			foreach(c;tree.children[1..$])
			{
				const auto cfactor = c.children[0].resolve;
				if (c.name == "DiceExpr.Add")
				{
					base.result=base.result+cfactor.result;
					base.repr=base.repr~"+"~cfactor.repr;
				}
				else if (c.name == "DiceExpr.Sub")
				{
					base.result=base.result-cfactor.result;
					base.repr=base.repr~"-"~cfactor.repr;
				}
				else
					throw new Exception("Unhandled factor: "~c.name);
				
			}
			return base;
		
		case "Factor":
			auto base = tree.children[0].resolve;
			foreach(c;tree.children[1..$])
			{
				const auto cfactor = c.children[0].resolve;
				if (c.name == "DiceExpr.Mul")
				{
					base.result=base.result*cfactor.result;
					base.repr=base.repr~"*"~cfactor.repr;
				}
				else if (c.name == "DiceExpr.Div")
				{
					base.result=base.result/cfactor.result;
					base.repr=base.repr~"/"~cfactor.repr;
				}
				else
					throw new Exception("Unhandled factor: "~c.name);
				
			}
			return base;
		
		
		case "MulDie":
		case "Die":
			auto noOfDice = 1L, sizeOfDice = 1L;
			if (tree.name == "DiceExpr.MulDie")
			{
				noOfDice = tree.children[0].resolve.result.coerce!long;
				sizeOfDice = tree.children[1].children[0].resolve.result.coerce!long;
			}
			else
				sizeOfDice = tree.children[0].resolve.result.coerce!long;
			// safeties at about 0.01% of long.max
			// (this check is per dice roll, and long.max is for the entire result, so..)
			if (noOfDice  > 9_999_999 || noOfDice<0)
				return ExprResult(0, "[too many dice]");
			if (sizeOfDice>99_999_999 ||sizeOfDice<0)
				return ExprResult(0, "[dice too large]");
			
			auto dice = rollDice(noOfDice, sizeOfDice);
			return ExprResult(dice.sum, dice.to!string);
		
		case "Neg":
			auto base = resolve(tree.children[0]);
			base.result = -base.result.coerce!long;
			base.repr = "-"~base.repr;
			return base;
		
		case "Parens":
		case "BParens":
			auto base = resolve(tree.children[0]);
			base.repr = "("~base.repr~")";
			return base;
			
		case "Number":
			assert (tree.matches.length==1);
			return ExprResult(tree.matches[0].to!long, tree.matches[0]);
		
		case "DiceExpr":
		case "Expr":
		case "Pos":
		case "Primary":
			return tree.children[0].resolve;
		
		default:
			throw new Exception("Unknown case: "~tree.name);
	}
	
}