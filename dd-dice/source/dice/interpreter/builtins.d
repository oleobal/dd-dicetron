/// functions built-in the interpreter, accessible to programs
module dice.interpreter.builtins;

import core.exception:RangeError;
import std.format;
import std.algorithm;
import std.array;
import std.conv;

import dice.roll;

import dice.interpreter.context;
import dice.interpreter.types;
import dice.interpreter.eval;

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
		
		
		default:
			throw new EvalException("Unknown function: "~name);
	}
	
	res.repr = repr;
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




ExprResult fMap(Context context, ExprResult[] args)
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
	
	return autoBuildList(results);
}

ExprResult fFilter(Context context, ExprResult[] args)
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
	
	if (args[0].isA!NumList)
		return autoBuildList(results, (cast(NumList) args[0]).maxValue);
	return autoBuildList(results);
}





ExprResult fMax(alias predicate)(Context context, ExprResult[] args)
{
	if (args.length<2)
		throw new EvalException("min & max need at least two args");
	if (!args.all!(it=>it.isA!Num))
		throw new EvalException("min & max only handle numeric types");
	
	return args.sort!(predicate)[0];
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

