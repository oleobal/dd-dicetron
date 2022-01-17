module dice.interpreter.repr;

import std.array;
import std.algorithm;
import std.format;
import std.range;
import std.conv;
import std.string;

string indent(string s, size_t n=1, char indentator=' ')
{
	assert(n>=1);
	auto i = indentator~' '.repeat(n-1).to!string;
	return i~s.replace("\n", "\n"~i);
}

string prettyList(string[] inputs, bool explain=false, string separator=",")
{
	string res;
	for(ulong i=0;i<inputs.length;i++)
	{
		res~=inputs[i];
		if (i+1<inputs.length)
		{
			res~=separator;
			if (explain)
				res~="\n";
		}
	}
	return res;
}


enum ReprOpt {
	roll,
	coinToss,
	list,
	parens,
	arithmetic,
	comparison,
	ternary,
	dotCall
}


struct Repr
{
	bool isLeaf;
	
	bool isRoll;
	bool isCoinToss;
	bool isList;
	bool isParens;
	bool isArithmetic;
	bool isComparison;
	bool isTernary;
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
			else if (o==ReprOpt.coinToss)
			{
				isCoinToss=true;
				assert(leaves.length == 1 && input.length < 2);
			}
			else if (o==ReprOpt.list)
				isList=true;
			else if (o==ReprOpt.parens)
				isParens=true;
			else if (o==ReprOpt.arithmetic)
			{
				isArithmetic=true;
				assert(leaves.length == 1 && input.length < 3);
			}
			else if (o==ReprOpt.comparison)
			{
				isComparison=true;
				assert(leaves.length+1 == input.length);
			}
			else if (o==ReprOpt.dotCall)
			{
				assert(input.length>0);
				isDotCall=true;
			}
			else if (o==ReprOpt.ternary)
			{
				assert(input.length>0);
				isTernary=true;
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
		this([i], l, l~i.toString, options);
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
	
	string debugTree()
	{
		if (isLeaf)
			return "Leaf("~leaves[0]~")";
		return "Repr(\n"~
		(
			leaves.join(", ")~"\n"
			~input.map!(it=>it.debugTree).join(",\n")~"\n"
			~output
		).indent(2)
		~"\n)";
	}
	
	string toString(bool explain=false) const
	{
		if (isLeaf)
			return leaves[0];
		
		if (isTernary)
		{
			string res = input[0].toString(explain);
			
			if (explain)
				res~="\n";
			res~="?";
			if (explain)
				res=res.indent(1,'|');
			if (explain)
				res~="->"~output;
			return res;
		}
		
		// chained arithmetic (eg 1 > 2 > 3)
		// FIXME pretty sure arithmetic and comparison can be merged
		if (isComparison)
		{
			string res = [input[0].toString(explain)].prettyList(explain);
			if (explain) res~="\n";
			for (ulong i; i<input.length && i<leaves.length; i++)
			{
				if (explain)
					res~=leaves[i].indent~"\n";
				else
					res~=leaves[i];
				res~=[input[i+1].toString(explain)].prettyList(explain);
				if (explain) res~="\n";
			}
			if (explain)
				res~="->"~output;
			if (res.canFind("\n"))
				res=res.indent(1,'|');
			return res;
		}
		
		if (isRoll && !input.any!(it=>it.hasRoll) && !explain)
			return output;
		
		if (isCoinToss)
		{
			string res = [input[0].toString(explain)].prettyList(explain);
			if (res == "1")
				res="";
			if (explain && res!="")
				res~="\n";
			res~=leaves[0];
			if (explain)
				res~="->"~output;
			return res;
		}
		
		if (isArithmetic)
		{
			string res;
			if (input.length == 1)
			{
				auto a = [input[0].toString(explain)].prettyList(explain);
				res = leaves[0]~a;
			}
			else
			{
				auto a = [input[0].toString(explain)].prettyList(explain);
				if (isRoll && a == "1") // seems like a dangerous special case but whatever
					a = "";
				if (explain && a.length>1)
					a~="\n";
				auto b = [input[1].toString(explain)].prettyList(explain);
				if (a.canFind("\n"))
					res = a~leaves[0].indent~"\n"~b~"\n";
				else
					res = a~leaves[0]~b;
			}
			
			if (explain)
				res~="->"~output;
			if (res.canFind("\n"))
				res=res.indent(1,'|');
			
			return res;
		}
		
		if (isParens)
		{
			string[] inputs = input.map!(it=>it.toString(explain)).array;
			string res = prettyList(inputs, explain);
			if (res.canFind("\n"))
				res = "(\n"~res.strip.indent~"\n)";
			else
				res = "("~res~")";
			if (explain)
				res~="->"~output;
			return res;
		}
		
		if (isList)
		{
			string[] inputs = input.map!(it=>it.toString(explain)).array;
			string res = prettyList(inputs, explain);
			if (res.canFind("\n"))
				return "[\n"~res.strip.indent~"\n]";
			return "["~res~"]";
		}
		
		
		// general case (function syntax)
		
		assert(leaves.length == 1);
		
		string[] inputs = input.map!(it=>it.toString(explain)).array;
		
		if (isDotCall)
		{
			string res = inputs[0];
			if (explain)
				res~="\n";
			string otherArgs;
			if (inputs.length>1)
				otherArgs=prettyList(inputs[1..$], explain);
			res~="."~leaves[0];
			if (otherArgs)
			{
				if (otherArgs.canFind("\n"))
					res~="(\n"~otherArgs.strip.indent~"\n)";
				else
					res~="("~otherArgs~")";
				
			}
			if (explain)
				res~="->"~output;
			return res;
		}
		
		auto args = inputs.prettyList(explain);
		string res;
		if (args.canFind("\n"))
			res = leaves[0]~"(\n"~args.strip.indent~"\n)";
		else
			res = leaves[0]~"("~args~")";
		if (explain)
			res~="->"~output;
		return res;
	}
}
