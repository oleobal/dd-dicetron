/// functions built-in the interpreter, accessible to programs
module dice.interpreter.builtins;

import core.exception:RangeError;
import std.format;
import std.algorithm;
import std.array;
import std.conv;
import std.uni:toLower;

import pegged.peg;

import dice.roll;

import dice.interpreter.context;
import dice.interpreter.types;
import dice.interpreter.eval;
import dice.interpreter.repr;

ExprResult callFunction(string name, ParseTree[] args, Context context, string callingStyle="FunCall")
{
	name=name.toLower;
	if (name == "function")
	{
		assert(args.length == 2);
		StringList argsNames = cast(StringList) args[0].eval(context);
		return new Function(
			argsNames.value.get!(ExprResult[]).map!(it=>it.value.get!string).array, 
			args[1],
			args[1].matches.join
		);
	}
	else
		return callFunction(name, args.map!(a=>a.eval(context)).array, context, callingStyle);
}

ExprResult callFunction(string name, ExprResult[] args, Context context, string callingStyle="FunCall")
{
	ExprResult res;
	switch (name)
	{
		case "best":
			res = fBest!"a.reduced.value.get!long > b.reduced.value.get!long"(context, args);
			break;
		case "worst":
			res = fBest!"a.reduced.value.get!long < b.reduced.value.get!long"(context, args);
			break;
		
		case "explode":
			res = fExplode(context, args);
			break;
		
		
		case "map":
			res = fMap(context, args);
			break;
		case "filter":
			res = fFilter(context, args);
			break;
		case "any":
			res = fAny(context, args);
			break;
		case "all":
			res = fAll(context, args);
			break;
		
		
		case "max":
			res = fMax!"a.reduced.value.get!long > b.reduced.value.get!long"(context, args);
			break;
		case "min":
			res = fMax!"a.reduced.value.get!long < b.reduced.value.get!long"(context, args);
			break;
		
		case "get":
			res = fGet(context, args);
			break;
		
		case "sort":
			res = fSort!"a.reduced.value.get!long < b.reduced.value.get!long"(context, args);
			break;
		case "rsort":
			res = fSort!"a.reduced.value.get!long > b.reduced.value.get!long"(context, args);
			break;
		
		case "case": // kinda meta
			res = fCase(context, args);
			break;
		case "def":
			res = fDef(context, args);
			break;
		
		
		default:
			throw new EvalException("Unknown function: "~name);
	}
	
	if (name != "def")
		res.reprTree = Repr(args.map!(it=>it.reprTree).array, name, res.to!string, ReprOpt.dotCall);
	return res;
}




ExprResult fBest(alias predicate)(Context context, ExprResult[] args)
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
			return new BoolList(args[0].value.get!(ExprResult[]).sort!(predicate)[0..nbToTake].array);
		else if (args[0].isA!NumRoll)
			return new NumList(
				args[0].value.get!(ExprResult[]).sort!(predicate)[0..nbToTake].array,
				(cast(NumRoll) args[0]).maxValue
			);
		else
			return new NumList(args[0].value.get!(ExprResult[]).sort!(predicate)[0..nbToTake].array);
	}
	else
		return args[0];
}

ExprResult fExplode(Context context, ExprResult[] args)
{
	if (args.length != 1 || !(args[0].isA!Num && args[0].isA!List))
		throw new EvalException("explode takes a numeric list");
	
	
	if (args[0].isA!Bool)
	{
		auto roll = cast(BoolList) args[0];
		ExprResult[] result;
		auto newRolls=roll.value.get!(ExprResult[]);
		for (int safety=0; safety<100;safety++)
		{
			result~=newRolls;
			auto c = newRolls.count!(a=>a.value.get!bool);
			if (c==0)
				break;
			newRolls = flipCoins(c).map!(a=>cast(ExprResult) new Bool(a)).array;
		}
		return new BoolList(result);
	}
	else
	{
		auto roll = cast(NumRoll) args[0];
		if (!roll.maxValue)
			throw new EvalException("explode requires maxValue to be set");
		ExprResult[] result;
		auto newRolls=roll.value.get!(ExprResult[]);
		for (int safety=0; safety<100;safety++)
		{
			result~=newRolls;
			auto c = newRolls.count!(a=>a.value.get!long == roll.maxValue);
			if (c==0)
				break;
			newRolls = rollDice(c, roll.maxValue).map!(a=>cast(ExprResult) new Num(a)).array;
		}
		return new NumList(result, roll.maxValue);
	}
}



Function checkListFilteringArgs(string f, ExprResult[] args)
{
	if (args.length!=2)
		throw new EvalException(f~" takes exactly two arguments");
	if (!args[0].isA!List || args[0].isA!Function)
		throw new EvalException(f~" takes a list and a lambda (that returns a bool)");
	Function lambda = cast(Function) args[1];
	if (lambda.args.length != 1)
		throw new EvalException("The lambda "~f~" takes must take exactly one argument (list item)");
	return lambda;
}


ExprResult fMap(Context context, ExprResult[] args)
{
	auto lambda = checkListFilteringArgs("map", args);
	
	ExprResult[] results;
	auto lambdaContext = new Context(context);
	foreach(a;args[0].value.get!(ExprResult[]))
	{
		lambdaContext[lambda.args[0]] = a;
		results ~= eval(lambda.code, lambdaContext);
	}
	
	return autoBuildList(results);
}

ExprResult fFilter(Context context, ExprResult[] args)
{
	auto lambda = checkListFilteringArgs("filter", args);
	
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
	
	if (args[0].isA!NumList)
		return autoBuildList(results, (cast(NumList) args[0]).maxValue);
	return autoBuildList(results);
}

ExprResult fAny(Context context, ExprResult[] args)
{
	auto lambda = checkListFilteringArgs("any", args);
	auto result = false;
	auto lambdaContext = new Context(context);
	foreach(a;args[0].value.get!(ExprResult[]))
	{
		lambdaContext[lambda.args[0]] = a;
		auto r = eval(lambda.code, lambdaContext);
		if (r.reduced.isA!Bool)
			result = result || r.value.get!bool;
		else
			throw new EvalException("Lambda "~lambda.repr~" returned a "~typeid(r).to!string~" instead of a bool");
	}
	
	return new Bool(result);
}

ExprResult fAll(Context context, ExprResult[] args)
{
	auto lambda = checkListFilteringArgs("any", args);
	auto result = true;
	auto lambdaContext = new Context(context);
	auto l = args[0].value.get!(ExprResult[]);
	if (l.length == 0)
		return new Bool(false);
	foreach(a;l)
	{
		lambdaContext[lambda.args[0]] = a;
		auto r = eval(lambda.code, lambdaContext);
		if (r.reduced.isA!Bool)
			result = result && r.value.get!bool;
		else
			throw new EvalException("Lambda "~lambda.repr~" returned a "~typeid(r).to!string~" instead of a bool");
	}
	
	return new Bool(result);
}



ExprResult fMax(alias predicate)(Context context, ExprResult[] args)
{
	if (args.length<2)
		throw new EvalException("min & max need at least two args");
	if (!args.all!(it=>it.isA!Num))
		throw new EvalException("min & max only handle numeric types");
	
	return args.sort!(predicate)[0];
}



ExprResult fIn(Context context, ExprResult[] args)
{
	throw new EvalException("in: not implemented");
}

ExprResult fGet(Context context, ExprResult[] args)
{
	if (args.length < 2 || args.length > 3)
		throw new EvalException("get takes a list and an index, or a start and end index");
	if (!args[0].isA!List)
		throw new EvalException("get takes a list and an index, or a start and end index");
		
	if (args.length == 2)
	{
		auto indexExpr = args[1].reduced;
		if (!indexExpr.isA!Num)
			throw new EvalException("get takes a list and an index, or a start and end index");
		auto index = indexExpr.value.get!long;
		try
		{
			if (index < 0)
				return args[0].value.get!(ExprResult[])[$+index];
			return args[0].value.get!(ExprResult[])[index];
		}
		catch (RangeError e)
			throw new EvalException(
				format("Can't get element at index %s from a list of length %s",index,args[0].value.get!(ExprResult[]).length)
				);
	}
	else
	{
		auto indexExprS = args[1].reduced;
		auto indexExprE = args[2].reduced;
		if (!indexExprS.isA!Num || !indexExprE.isA!Num)
			throw new EvalException("get takes a list and an index, or a start and end index");
		auto indexS = indexExprS.value.get!long;
		auto indexE = indexExprE.value.get!long;
		ExprResult[] slice;
		try
		{
			// there must be a more clever way
			if (indexS < 0)
			{
				if (indexE < 0)
					slice = args[0].value.get!(ExprResult[])[$+indexS..$+indexE];
				else
					throw new RangeError();
			}
			else if (indexE < 0)
				slice = args[0].value.get!(ExprResult[])[indexS..$+indexE];
			else
				slice = args[0].value.get!(ExprResult[])[indexS..indexE];
			return autoBuildList(slice);
		}
		catch (RangeError e)
			throw new EvalException(
				format("Can't get elements %s..%s from a list of length %s",indexS, indexE,args[0].value.get!(ExprResult[]).length)
				);
	}
}


ExprResult fSort(alias predicate)(Context context, ExprResult[] args)
{
	if (args.length != 1 || !(args[0].isA!Num && args[0].isA!List))
		throw new EvalException("sort takes a numeric list");
	if (args[0].isA!Bool)
		return new BoolList(args[0].value.get!(ExprResult[]).sort!(predicate).array);
	else if (args[0].isA!NumRoll)
		return new NumList(
			args[0].value.get!(ExprResult[]).sort!(predicate).array,
			(cast(NumRoll) args[0]).maxValue
		);
	else
		return new NumList(args[0].value.get!(ExprResult[]).sort!(predicate).array);
}


ExprResult fCase(Context context, ExprResult[] args)
{
	// 1d20.case([[1,2,3], 5 ] , 7)
	auto target = args[0].reduced;
	auto defaultResult = args[$-1];
	assert(args[1..$-1].all!(it=>it.isA!List));
	auto cases = args[1..$-1].map!(it=>it.value.get!(ExprResult[])).array; // [List of matching cases, Expr to return]
	assert(cases.all!(it=>it[0].isA!List));
	
	foreach(c;cases)
		if (c[0].value.get!(ExprResult[]).canFind(target))
			return c[1];
	return defaultResult;
}


ExprResult fDef(Context context, ExprResult[] args)
{
	assert(args.length == 2);
	assert(args[0].isExactlyA!String);
	
	return context[args[0].value.get!string] = args[1];
}