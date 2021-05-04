module main;

import std.stdio;
import std.algorithm.searching;
import dice;


void main(string[] args)
{
	auto verbose=false;
	auto machineReadable=false;
	auto expr="";
	foreach(a;args[1..$])
	{
		if (a =="-d" || a == "--debug")
			verbose=true;
		if (a == "--machine")
			machineReadable=true;
		else
			expr=a;
	}
	auto tree = parse(expr);
	if (verbose)
		writeln(tree);
	
	
	try
	{
		auto result = eval(tree);
		string prettyResult;
		if (result.value.type == typeid(bool))
			prettyResult=result.value.get!bool?"Success":"Failure";
		else
			prettyResult=result.value.coerce!string;
		
		if (machineReadable)
			writeln(result.repr~"\n"~prettyResult~"\n");
		else
			writeln(result.repr~": "~prettyResult);
	}
	catch (EvalException e)
	{
		if (machineReadable)
			writeln("\n\n"~e.msg);
		else
			throw e;
	}
	
}