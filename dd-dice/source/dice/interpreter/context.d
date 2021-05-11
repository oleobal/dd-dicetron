/// Definition of the Context object for managing identifiers
module dice.interpreter.context;

import std.conv;

import dice.interpreter.types;

string spaces(uint indent)
{
	import std.range:repeat;
	return ' '.repeat(indent*2).to!string;
}

class Context
{
	Context outer;
	
	ExprResult[string] contents;
	
	ExprResult opIndex(string i)
	{
		if (i in contents)
			return contents[i];
		else
		{
			if (outer)
				return outer[i];
			else
				throw new Exception("Undefined: "~i.to!string);
		}
	}
	
	ExprResult opIndexAssign(ExprResult val, string key)
	{
		return contents[key] = val;
	}
	
	/++
	 + will go up to the outer context to change the key at the source
	 +/
	ExprResult overwrite(string key, ExprResult val)
	{
		if (key in contents)
			return contents[key] = val;
		else
		{
			if (outer)
				return outer.overwrite(key, val);
			else
				throw new Exception("Undefined: "~key.to!string);
		}
	}
	
	this() {}
	
	this(Context outer)
	{
		this.outer = outer;
	}
	
	
	override string toString() const
	{
		return toString(0);
	}
	
	string toString(uint indent) const
	{
		string result = spaces(indent)~"Context(";
		foreach(k,v;contents)
			result~="\n"~spaces(indent+1) ~ k ~ " : " ~ v.to!string;
		if (outer)
			result~="\n"~outer.toString(indent+1);
		if (result != spaces(indent)~"Context(")
			result~="\n";
		result~=")";
		return result;
	}
}


