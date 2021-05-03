module main;

import std.stdio;
import dice;


void main(string[] args)
{
	parse(args[1]).writeln;
	
	resolve(args[1]).writeln;
}