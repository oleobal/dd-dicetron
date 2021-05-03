module main;

import std.stdio;
import std.algorithm.searching;
import std.conv;
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
	
	auto result = resolve(tree);
	if (machineReadable)
		writeln(result.repr~"\n"~result.result.to!string~"\n");
	else
		writeln(result.repr~": "~result.result.to!string);
}