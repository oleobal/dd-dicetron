module main;

import std.stdio;
import std.algorithm.searching;
import std.array;
import std.file;
import std.json;

import dice;


auto helpMsg=`
Roll a twenty-sided die:          d20
  five ten-sided dice:            5d10

Arithmetic works:                 d20+5*3

So do comparisons:                d20+7>17
  chain them à la Python:         6<=2d20<=35

Results can be filtered:
  the best of the two rolls:      2d20.best
  the middle two of four:         4d20.best(3).worst(2)
  the ones above ten:             4d20.filter{it>10}

Custom dice:                      [1,5,7]
  with words:                     2[pizza, burger, salad]
  quote non-alphanumeric faces:   ["🍕", "🍔", "🥗", "Not hungry"]

Coin flips:                       coin + 4 coins
`[1..$-1];

int main(string[] args)
{
	auto verbose=false;
	auto jsonOutput=false;
	auto expr="";
	string[] jsonModules;
	
	for(ulong i=1; i<args.length;i++)
	{
		auto a = args[i];
		if (a =="-d" || a == "--debug")
			verbose=true;
		else if (a == "--json")
			jsonOutput=true;
		else if (a =="-h" || a == "--help")
		{
			writeln(helpMsg);
			return 0;
		}
		else if (a=="--module")
		{
			i++;
			assert(i<args.length);
			jsonModules ~= readText(args[i]);
		}
		else
			expr=a;
	}
	
	JSONValue machineResult = ["successful" : true];
	
	auto tree = parse(expr);
	
	if (verbose)
	{
		if (jsonOutput)
			machineResult["parseTree"] = tree.toString;
		else
			tree.writeln;
	}
	if (!tree.successful)
	{
		if (jsonOutput)
		{
			machineResult["successful"] = false;
			machineResult.object["error"] = tree.failMsg;
			machineResult.writeln;
			return 0;
		}
		else
		{
			writeln("Parsing error: "~tree.failMsg);
			return 1;
		}
	}
	
	
	try
	{
		auto context = new Context();
		if (jsonModules.length > 0)
			context = loadModule(jsonModules[0]);
		if (jsonModules.length > 1)
			foreach(m;jsonModules[1..$])
			{
				auto c = loadModule(m);
				c.outer = context;
				context = c;
			}
		
		if (verbose)
		{
			if (jsonOutput)
				machineResult["context"] = context.toString;
			else
				context.writeln;
		}
		
		auto result = eval(tree, context);
		string prettyResult;
		if (result.value.type == typeid(bool))
			prettyResult=result.value.get!bool?"Success":"Failure";
		else
			prettyResult=result.toString;
		machineResult.object["output"] = prettyResult;
		machineResult.object["repr"] = result.repr;
		
		if (jsonOutput)
			machineResult.writeln;
		else
		{
			if (canFind(result.repr, "\n"))
				writeln(result.repr~"\n"~prettyResult);
			else
				writeln(result.repr~": "~prettyResult);
		}
	}
	catch (EvalException e)
	{
		if (jsonOutput)
		{
			machineResult["error"] = e.msg;
			machineResult.writeln;
			return 0;
		}
		else
			throw e;
	}
	return 0;
}