module dice.modules;

import dyaml;

import std.conv;
import std.algorithm;
import std.array;

import dice.parser;
import dice.interpreter.types;
import dice.interpreter.context;

Context loadModule(string yamlModule)
{
	
	auto c = new Context();
	Node mod = Loader.fromString(yamlModule).load();
	
	foreach(Node f;mod["functions"])
	{
		auto name = f["name"].as!string;
		auto args = f["args"].sequence!string.array;
		auto code = f["code"].as!string;
		auto parsedCode = parse(code);
		auto r = cast(ExprResult) new Function(args, parsedCode, name);
		c[name] = r;
	}
	
	return c;
}
