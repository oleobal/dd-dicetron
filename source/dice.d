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
    BTerm    < BFactor (Eq / NEq / Inf / InfEq / Sup / SupEq)*
    Eq       < "==" BFactor
    NEq      < "!=" BFactor
    Inf      < "<" BFactor
    InfEq    < "<=" BFactor
    Sup      < ">" BFactor
    SupEq    < ">=" BFactor
    BFactor  < Not / Parens / Term
    BParens  < "(" BFactor ")"
    Not      < "!" BFactor
    
    Term     < Factor (Add / Sub)*
    Add      < "+" Factor
    Sub      < "-" Factor
    Factor   < Primary (Mul / Div)*
    Mul      < "*" Primary
    Div      < "/" Primary
    Primary  < MulDie / Parens / Neg / Pos / Die / Number 
    Parens   < "(" Term ")"
    Neg      < "-" Primary
    Pos      < "+" Primary
    MulDie   < Primary Die
    Die      < "d" Number
    Number   < ~([0-9]+)
`));


// I separate them because I don't see a use case for casting between those types so no need to bundle everything together

auto parse(string expr)
{
	return DiceExpr(expr);
}


int[] rollDice(int number, int die)
{
	return generate!(() => uniform!"[]"(1, die)).takeExactly(number).array;
}

/+
 + bools for difficulty rolls (eg d20+5 > 17)
 + strings for name dice and also errors >_>
 +/
struct ExprResult {
	Algebraic!(int, bool, string) result;
	string repr;
	this (int    a, string b) { result = a; repr = b; }
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
		case "BTerm":
			auto base = tree.children[0].resolve;
			foreach(c;tree.children[1..$])
			{
				throw new Exception("To be implemented");
			}
			return base;
		
		case "BFactor":
			auto base = tree.children[0].resolve;
			foreach(c;tree.children[1..$])
			{
				throw new Exception("To be implemented");
			}
			return base;
		
		
		
		
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
			auto dice = rollDice(
				tree.children[0].resolve.result.coerce!int,
				tree.children[1].children[0].resolve.result.coerce!int
			);
			return ExprResult(dice.sum, dice.to!string);
		case "Die":
			auto dice = rollDice(1,tree.children[0].resolve.result.coerce!int);
			return ExprResult(dice[0], dice.to!string);
		
		case "Neg":
			auto base = resolve(tree.children[0]);
			base.result = -base.result.coerce!int;
			base.repr = "-"~base.repr;
			return base;
		
		case "Parens":
		case "BParens":
			auto base = resolve(tree.children[0]);
			base.repr = "("~base.repr~")";
			return base;
			
		case "Number":
			assert (tree.matches.length==1);
			return ExprResult(tree.matches[0].to!int, tree.matches[0]);
		
		case "DiceExpr":
		case "Pos":
		case "Primary":
			return tree.children[0].resolve;
		
		default:
			throw new Exception("Unknown case: "~tree.name);
	}
	
}