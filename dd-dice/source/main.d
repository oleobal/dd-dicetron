module main;

import std.stdio;
import std.algorithm.searching;
import std.array;

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

Custom dice:                      [1,5,7]
  with words:                     2[pizza, burger, salad]
  quote non-alphanumeric faces:   ["🍕", "🍔", "🥗", "Not hungry"]

Coin flips:                       coin     4 coins
`[1..$-1];

int main(string[] args)
{
	auto verbose=false;
	auto machineReadable=false;
	auto expr="";
	foreach(a;args[1..$])
	{
		if (a =="-d" || a == "--debug")
			verbose=true;
		else if (a == "--machine")
			machineReadable=true;
		else if (a =="-h" || a == "--help")
		{
			writeln(helpMsg);
			return 0;
		}
		else
			expr=a;
	}
	auto tree = parse(expr);
	if (verbose)
		writeln(tree);
	if (!tree.successful)
	{
		if (machineReadable)
		{
			writeln("\n\n"~tree.failMsg);
			return 0;
		}
		writeln("Parsing error: "~tree.failMsg);
		return 1;
	}
	
	
	
	try
	{
		auto result = eval(tree);
		string prettyResult;
		if (result.value.type == typeid(bool))
			prettyResult=result.value.get!bool?"Success":"Failure";
		else if (result.value.type == typeid(string[]))
			prettyResult=result.value.get!(string[]).join(", ");
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
	return 0;
}