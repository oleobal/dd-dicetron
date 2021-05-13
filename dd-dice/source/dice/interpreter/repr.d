module dice.interpreter.repr;

import std.array;
import std.algorithm;

string indent(string s)
{
	return " "~s.replace("\n", "\n ");
}

struct Repr
{
	bool isLeaf;
	bool isRoll=false;
	string[] leaves;
	Repr[] input;
	string output;
	
	this(string s)
	{
		isLeaf=true;
		leaves=[s];
		output=s;
	}
	this(Repr i, string l)
	{
		if (i.isLeaf)
			this([i], l, l~i.toString);
		else
			this([i], l);
	}
	this(Repr[] i, string l)
	{ this(i, l, ""); }
	
	this(Repr[] i, string l, string o)
	{ this(i,l,o,false); }
	this(Repr[] input, string leaf, string output, bool isRoll)
	{
		isLeaf=false;
		this(input, [leaf], output, isRoll);
	}
	
	/// for chained stuff like "1 <= 2 <= 3"
	this(Repr[] input, string[] leaves, string output, bool isRoll)
	{
		if (isRoll)
			assert(input.length == 2);
		
		this.input=input;
		this.leaves=leaves;
		this.output=output;
		this.isRoll=isRoll;
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
		
		
		// unitary
		if (!output && input.length == 1)
			return leaves[0]~input[0].toString;
		
		if (isRoll)
			// ever exactly two inputs
			if (!input.any!(it=>it.hasRoll))
				return output;
		
		
		
		// regular f(x) case
		string[] inputs;
		
		if (!hasRoll)
			return output;
		
		foreach(i;input)
		{
			if (i.hasRoll)
				inputs~=i.toString;
			else
				inputs~=i.output;
		}
		
		
		return leaves[0]~"(\n"~inputs.join(",\n").indent~"\n)"~" -> "~output;
	}
}
