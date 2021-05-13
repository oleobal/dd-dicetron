/// Has the eval(..) function
module dice.interpreter.eval;

import std.string;
import std.conv;
import std.random;
import std.range;
import std.algorithm;

import dice.parser;
import dice.roll;

import dice.interpreter.repr;
import dice.interpreter.types;
import dice.interpreter.context;
import dice.interpreter.builtins;


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
						~prevOperand.debuginfo
						~" and "~secondOperand.debuginfo
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
							"Can't do other comparisons than equality on "~prevOperand.debuginfo
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
				result.repr = result.repr ~ c.matches[0] ~ secondOperand.repr;
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
			auto name = tree.children[0].matches[0];
			if (name in context && context[name].isA!Function)
			{
				auto f = cast(Function) context[name];
				auto args = tree.children[1..$];
				auto fContext = new Context(context);
				if (args.length != f.args.length)
					throw new EvalException("Trying to call %s(%s) with the wrong number (%s) of args".format(name, f.args.join(","), args.length));
				ExprResult[] evalArgs;
				for (ulong i=0;i<f.args.length;i++)
				{
					evalArgs ~= eval(args[i]);
					fContext[f.args[i]] = evalArgs[$-1];
				}
				auto res = eval(f.code, fContext);
				res.reprTree = Repr(evalArgs.map!(it=>it.reprTree).array, name, res.to!string);
				return res;
			}
			// fall back to builtins
			return callFunction(
				name,
				tree.children[1..$].map!(a=>a.eval(context)).array,
				context,
				tree.name.chompPrefix("DiceExpr.")
			);
		
		
		case "LambdaDef":
			auto args = ["it"];
			if (tree.children.length > 1)
				args = tree.children[0..$-1].map!(a=>a.matches[0]).array;
			auto repr = args.join(",")~" => "~tree.children[$-1].matches.join();
			return cast(ExprResult) new Function(args, tree.children[$-1], repr);
		
		
		case "MulDie":
		case "Die":
		case "CustomDie":
		case "Coin":
			auto noOfDice = 1L;
			auto die=tree;
			Repr[] reprInput;
			if (tree.name == "DiceExpr.MulDie")
			{
				die = tree.children[1];
				auto noOfDiceExpr = tree.children[0].eval(context);
				reprInput ~= noOfDiceExpr.reprTree;
				noOfDice = noOfDiceExpr.reduced.value.coerce!long;
			}
			else
				reprInput~= Repr("1");
			
			if (die.name == "DiceExpr.Die")
			{
				auto sizeOfDice = die.children[0].eval(context).value.coerce!long;
				reprInput ~= Repr(sizeOfDice.to!string);
				// safeties at about 0.01% of long.max
				// (this check is per dice roll, and long.max is for the entire result, so..)
				if (noOfDice  > 9_999_999 || noOfDice<0)
					return cast(ExprResult) new Num(0L, "[too many dice]");
				if (sizeOfDice>99_999_999 ||sizeOfDice<0)
					return cast(ExprResult) new Num(0L, "[dice too large]");
				if (noOfDice == 0)
					return cast(ExprResult) new Num(0, "[0]");
				
				auto dice = rollDice(noOfDice, sizeOfDice);
				return cast(ExprResult) new NumRoll(dice, sizeOfDice, reprInput);
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
				auto customDiceList = die.children[0].eval(context);
				auto choices = customDiceList.value.get!(ExprResult[]);
				reprInput ~= customDiceList.reprTree;
				ExprResult[] dice = generate!(() => choices.choice).takeExactly(noOfDice).array;
				if (dice.all!(it=>it.isA!Bool))
					return cast(ExprResult) new BoolList(dice, dice.to!string);
				if (dice.all!(it=>it.isA!Num))
					return cast(ExprResult) new NumRoll(dice, 0, reprInput);
				if (dice.all!(it=>it.isA!String))
					return cast(ExprResult) new StringList(dice, dice.to!string);
				return cast(ExprResult) new MixedList(dice, dice.to!string);
			}
			else
				throw new Exception("Unknown dice type: "~die.name);
			
		
		case "Neg":
			auto base = tree.children[0].eval(context).reduced;
			base.value = -base.value.get!long;
			base.reprTree = Repr(base.reprTree, "-");
			return base;
		
		case "Not":
			auto base = tree.children[0].eval(context).reduced;
			base.value = !base.value.get!bool;
			base.reprTree = Repr(base.reprTree, "!");
			return base;
		
		case "Parens":
			auto base = eval(tree.children[0], context);
			base.reprTree = base.reprTree; // FIXME?
			return base;
		
		case "List":
			if (tree.matches.length == 5 && tree.matches[2] == "..")
			{
				auto start = tree.children[0].eval(context).reduced.value.get!long;
				auto end = tree.children[1].eval(context).reduced.value.get!long;
				ExprResult[] c;
				if (start<end)
					for (auto i=start;i<=end;i++)
						c~= new Num(i, i.to!string);
				else if (start>end)
					for (auto i=start;i>=end;i--)
						c~=new Num(i, i.to!string);
				else
					c~= new Num(start, start.to!string);
				return autoBuildList(c);
			}
			ExprResult[] c = tree.children.map!(it=>it.eval(context)).array;
			return autoBuildList(c);
		
		case "Number":
			assert (tree.matches.length==1);
			return cast(ExprResult) new Num(tree.matches[0].to!long, tree.matches[0]);
		
		case "UnqStr":
		case "String":
			return cast(ExprResult) new String(tree.matches[0], '"'~tree.matches[0]~'"');
		
		case "Ident":
			if (tree.matches[0] in context)
				return context[tree.matches[0]];
			return new String(tree.matches[0]); // unquoted strings
		
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
