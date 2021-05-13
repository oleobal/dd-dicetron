module dice.interpreter.repr;

import std.array;
import std.algorithm;
import std.format;

string indent(string s)
{
	return " "~s.replace("\n", "\n ");
}

string prettyList(string[] inputs, string separator=",", ulong limit=50)
{
	string res;
	foreach(i;inputs)
	{
		if (i.length<limit)
			res~=i~",";
		else
			res~="\n"~i~",\n";
	}
	if(res[$-1] == ',') res=res[0..$-1];
	import std;
	return res;
}


enum TOO_LONG=50;

enum ReprOpt {
	roll,
	list,
	arithmetic,
	dotCall
}


struct Repr
{
	bool isLeaf;
	
	bool isRoll;
	bool isList;
	bool isArithmetic;
	bool isDotCall;
	
	string[] leaves;
	Repr[] input;
	string output;
	
	void setOptions(ReprOpt[] options)
	{
		foreach(o;options)
		{
			if      (o==ReprOpt.roll)
				isRoll=true;
			else if (o==ReprOpt.list)
				isList=true;
			else if (o==ReprOpt.arithmetic)
			{
				isArithmetic=true;
				assert(leaves.length == 1 && input.length < 3);
			}
			else if (o==ReprOpt.dotCall)
			{
				assert(input.length>0);
				isDotCall=true;
			}
			else
				throw new Exception("Unknown ReprOpt: %s".format(o));
		}
		if (options.length == 0)
			assert(leaves.length>0);
	}
	
	this(string s)
	{
		isLeaf=true;
		leaves=[s];
		output=s;
	}
	this(Repr i, string l, ReprOpt[] options...)
	{
		this([i], l, l~i.toString);
	}
	this(Repr[] i, string l, ReprOpt[] options...)
	{this(i, l, options);}
	this(Repr[] i, string l, ReprOpt[] options)
	{
		assert(i.length == 2);
		this(i, [l], i[0].toString~l~i[1].toString, options);
	}
	
	this(Repr[] input, string leaf, string output, ReprOpt[] options...)
	{
		this(input, [leaf], output, options);
	}
	
	this(Repr[] input, string[] leaves, string output, ReprOpt[] options...)
	{this(input, leaves, output, options);}
	
	/// for chained stuff like "1 <= 2 <= 3"
	this(Repr[] input, string[] leaves, string output, ReprOpt[] options)
	{
		if (isRoll)
			assert(input.length == 2);
		
		this.input=input;
		this.leaves=leaves;
		this.output=output;
		setOptions(options);
	}
	
	bool hasRoll() const
	{
		if (isLeaf)
			return isRoll;
		return isRoll || input.any!(it=>it.hasRoll);
	}
	
	string toString() const
	{
		if (isLeaf)
			return leaves[0];
		
		// chained arithmetic (eg 1 > 2 > 3)
		if (leaves.length>1)
		{
			string result = "";
			throw new Exception("To be implemented");
		}
		
		
		if (isRoll && !input.any!(it=>it.hasRoll))
			return output;
		
		
		if (isArithmetic)
		{
			if (input.length == 1)
			{
				auto a = input[0].toString;
				if (a.length < TOO_LONG)
					return leaves[0]~a;
			}
			else
			{
				auto a = input[0].toString;
				auto b = input[1].toString;
				if (a.length < TOO_LONG && b.length < TOO_LONG)
					return a~leaves[0]~b;
			}
		}
		
		if (isList)
		{
			string[] inputs = input.map!(it=>it.toString).array;
			string res = prettyList(inputs);
			if (res.canFind("\n"))
				return "[\n"~res.indent~"\n]";
			return "["~res~"]";
		}
		
		
		// general case (function syntax)
		
		assert(leaves.length == 1);
		
		string[] inputs = input.map!(it=>it.toString).array;
		
		if (isDotCall)
		{
			string res = inputs[0];
			string otherArgs;
			if (inputs.length>1)
				otherArgs=prettyList(inputs[1..$]);
			if ((res~"."~leaves[0]).length < TOO_LONG)
				res~="."~leaves[0];
			else
				res~="\n"~("."~leaves[0]).indent;
			if (otherArgs)
			{
				if (otherArgs.canFind("\n"))
					res~="(\n"~otherArgs.indent~"\n) -> "~output;
				else
					res~="("~otherArgs~")";
				
			}
			return res;
		}
		
		auto args = inputs.prettyList;
		if (args.canFind("\n"))
			return leaves[0]~"(\n"~args.indent~"\n)"~" -> "~output;
		else
			return leaves[0]~"("~args~")";
	}
}
