module dice.modules;

import std.json;
import std.conv;
import std.algorithm;
import std.array;

import dice.parser;
import dice.interpreter.types;
import dice.interpreter.context;

Context loadModule(string jsonModule)
{
	JSONValue mod = parseJSON(jsonModule);
	auto c = new Context();
	
	foreach(f;mod["functions"].array)
	{
		auto args = f["args"].array.map!(it=>it.str).array;
		auto code = f["code"].str;
		auto parsedCode = parse(code);
		auto r = cast(ExprResult) new Function(args, parsedCode, code);
		c[f["name"].str] = r;
	}
	
	return c;
}
