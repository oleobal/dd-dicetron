/// Defines all types the interpreter manages, descending from ExprResult
module dice.interpreter.types;

import std.traits;
import std.string;
import std.variant;
import std.algorithm;
import std.conv;
import std.array;

import pegged.peg;

import dice.interpreter.repr;
import dice.interpreter.context;
import dice.interpreter.eval;

/// is T or a subclass of T
bool isA(T)(const Object o)
{
	return (cast(T) o) ?true:false;
}

/// is T, but not a subclass
bool isExactlyA(T)(const Object o)
{
	return (typeid(o) == typeid(T));
}

string typename(T)(T v)
{
	return typeid(v).to!string.split(".")[$-1];
}

string debuginfo(T)(T v)
{
	return v.typename~"("~v.to!string~")";
}


abstract class ExprResult {
	Algebraic!(long, bool, string, ExprResult[]) value;
	
	/// string representation to give insight into the interpreter
	string repr() const
	{
		return reprTree.toString;
	}
	string repr(string s)
	{
		reprTree = Repr(s);
		return s;
	}
	
	Repr reprTree = Repr();
	
	
	/// whether this is the direct result of a dice roll
	bool isRoll=false;
	
	abstract ExprResult reduced();
	
	override string toString() const
	{
		if (value.type == typeid(ExprResult[]))
			return value.get!(ExprResult[]).map!(it=>it.to!string).join(",");
		else if (value.type == typeid(long))
			return value.get!long.to!string;
		else if (value.type == typeid(bool))
			return value.get!bool?"T":"F";
		else if (value.type == typeid(string))
			return value.get!string;
		else
			return value.to!string;
			// doesn't work well with const
			// because VariantN.coerce doesn't work on const objects
	}
	
	override bool opEquals(const Object o) const
	{
		if (typeid(o) == typeid(this))
		{
			auto oa = cast(ExprResult) o;
			return this.value == oa.value;
		}
		else
			return false;
	}
}

interface List {}
interface Roll {}

class Num : ExprResult
{
	this() {}
	this (long a) { this(a, a.to!string); }
	this (long a, string b) { this(a, Repr(b)); }
	this (long a, Repr b) { value = a; reprTree = b; }
	override ExprResult reduced() {return cast(ExprResult) new Num(value.get!long, reprTree);}
}
class NumList : Num, List
{
	
	/++
	 + the maximum possible value of the corresponding roll
	 + used for explosions
	 + not guaranteed to be there
	 +/
	long maxValue;
	
	this() {}
	this (long[] a) { this(a, 0); }
	this (long[] a, long max) {
		this(a.map!(it=>cast(ExprResult) new Num(it)).array, max);
	}
	
	this (ExprResult[] a) { this(a, 0); }
	this (ExprResult[] a, long max) {this(a, 0, genOutputRepr(a));}
	this (ExprResult[] a, long max, string outputRepr)
	{
		assert(a.all!(it=>it.isA!Num));
		
		value = a;
		reprTree = Repr(a.map!(it=>it.reprTree).array, "NumList", outputRepr, ReprOpt.list);
	}
	
	
	string genOutputRepr(T)(T a)
	{
		static assert(isArray!T);
		return "["~a.map!(it=>it.to!string).join(",")~"]";
	}
	
	override string toString() const
	{
		return reprTree.output;
	}
	
	override ExprResult reduced() {
		
		long[] val;
		foreach(e;value.get!(ExprResult[]))
		{
			if (e.isA!NumList)
				val~=e.reduced.value.get!long;
			else
				val~=e.value.get!long;
		}
		return cast(ExprResult) new Num(val.sum, reprTree);
	}
}

/++ 
 + represents a "true" NumRoll (ie the result of xdy)
 + as soon as they go through functions they become NumLists
 +/
class NumRoll : NumList, Roll
{
	
	this() {}
	this (long[] a, long max)
	{
		this(a, max, []);
	}
	this (ExprResult[] a, long max)
	{
		this(a, max, []);
	}
	this (long[] a, long max, Repr[] predecessor)
	{
		this(a.map!(it=>cast(ExprResult) new Num(it)).array, max, predecessor);
	}
	this (ExprResult[] a, long max, Repr[] predecessor)
	{
		maxValue = max;
		reprTree = Repr(predecessor, "d", genOutputRepr(a), ReprOpt.roll, ReprOpt.arithmetic);
		value = a;
	}
}

class Bool : Num
{
	this() {}
	this (bool a) { this(a, a?"T":"F");}
	this (bool a, string b) { this(a, Repr(b)); }
	this(bool a, Repr b) { value = a; reprTree = b;}
	override ExprResult reduced() {return cast(ExprResult) new Bool(value.get!bool, reprTree);}
	
}
class BoolList : Bool, List
{
	this() {}
	this (bool[] a) { this(a, genOutputRepr(a)); }
	this (bool[] a, string b) { this(a.map!(it=>cast(ExprResult) new Bool(it)).array, b); }
	this (ExprResult[] a) { this(a, genOutputRepr(a)); }
	this (ExprResult[] a, string outputRepr)
	{
		assert(a.all!(it=>it.isA!Bool));
		value = a;
		reprTree = Repr(a.map!(it=>it.reprTree).array, "BoolList", outputRepr, ReprOpt.list);
	}
	override string toString() const { return reprTree.output; }
	
	string genOutputRepr(T)(T a)
	{
		static assert(isArray!T);
		return "["~a.map!(it=>it.to!string).join(",")~"]";
	}
	
	override ExprResult reduced() { 
		auto l = value.get!(ExprResult[]);
		if (l.length == 1)
			return cast(ExprResult) new Bool(l[0].value.get!bool, reprTree);
		
		return cast(ExprResult) new Num(l.map!(it=>it.value.get!bool).sum, reprTree);
	}
}
class BoolRoll : BoolList, Roll
{
	this(bool[] a, string type, Repr[] predecessor)
	{
		this(a.map!(it=>cast(ExprResult) new Bool(it)).array, type, predecessor);
	}
	this (ExprResult[] a, string type, Repr[] predecessor)
	{
		assert(a.all!(it=>it.isA!Bool));
		value = a;
		reprTree = Repr(predecessor, type, genOutputRepr(a), ReprOpt.coinToss, ReprOpt.roll);
	}
}


class String : ExprResult
{
	this() {}
	this (string a) { value = a; repr = a; }
	this (string a, string b) { value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new String(value.get!string, repr);}
}
class StringList : String, List
{
	this() {}
	this (string[] a, string b) { value = a.map!(it=>cast(ExprResult) new String(it)).array; repr = b; }
	this (ExprResult[] a) { this(a, a.to!string); }
	this (ExprResult[] a, string b) { assert(a.all!(it=>it.isA!String)) ; value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new StringList(value.get!(ExprResult[]), repr);}
}
class MixedList : String, List
{
	this() {}
	this (ExprResult[] a) { value = a; repr = a.to!string; }
	this (ExprResult[] a, string b) { value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new MixedList(value.get!(ExprResult[]), repr);}
}
class Function : ExprResult
{
	string[] args;
	ParseTree code;
	
	this() {}
	this(string[] args, ParseTree code, string repr)
	{
		this.args=args;
		this.code=code;
		this.repr=repr;
	}
	
	ExprResult call(Context c)
	{
		return eval(code, c);
	}
	
	override ExprResult reduced()
	{
		return cast(ExprResult) new Function(args, code, repr);
	}
	override bool opEquals(const Object o) const
	{
		if (typeid(o) == typeid(this))
		{
			auto oa = cast(Function) o;
			return this.args == oa.args && this.code == oa.code;
		}
		else
			return false;
	}
	override string toString() const
	{
		return repr();
	}
	/+
	override size_t toHash() const
	{
		// Counting on the repr being about equal to code.input[code.begin..code.end]
		return typeid(repr()).getHash(&repr);
	}
	+/
}


ExprResult autoBuildList(ExprResult[] elements, long maxValue=0)
{
	if (elements.all!(it=>it.isA!Bool))
		return cast(ExprResult) new BoolList(elements);
	if (elements.all!(it=>it.isA!Num))
	{
		if (maxValue)
			return cast(ExprResult) new NumList(elements, maxValue);
		return cast(ExprResult) new NumList(elements);
	}
	if (elements.all!(it=>it.isA!String))
		return cast(ExprResult) new StringList(elements);
	return cast(ExprResult) new MixedList(elements);
}