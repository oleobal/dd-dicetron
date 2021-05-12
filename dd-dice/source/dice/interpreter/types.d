/// Defines all types the interpreter manages, descending from ExprResult
module dice.interpreter.types;

import std.traits;
import std.string;
import std.variant;
import std.algorithm;
import std.conv;
import std.array;

import pegged.peg;

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

string indent(string s)
{
	return " "~s.replace("\n", "\n ");
}

struct ReprTree
{
	bool isLeaf;
	bool isRoll=false;
	string leaf;
	ReprTree[] children;
	
	this(string s)
	{
		isLeaf=true;
		leaf=s;
	}
	/+
	// result in errors I don't understand
	this(ReprTree[] p ...)
	{
		this(p);
	}
	+/
	this(ReprTree[] p)
	{
		isLeaf=false;
		children=p;
	}
	
	bool hasRoll() const
	{
		if (isLeaf)
			return isRoll;
		return isRoll || children.any!(it=>it.hasRoll);
	}
	
	string toString() const
	{
		if (isLeaf)
			return leaf;
		return reduce!((acc,it)=>acc~=it.toString)("", children);
	}
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
		reprTree = ReprTree(s);
		return s;
	}
	
	ReprTree reprTree = ReprTree();
	
	
	/// whether this is the direct result of a dice roll
	bool isRoll=false;
	
	abstract ExprResult reduced();
	
	override string toString() const
	{
		if (value.type == typeid(ExprResult[]))
			return value.get!(ExprResult[]).map!(it=>it.to!string).join(",");
		else if ( value.type == typeid(long))
			return value.get!long.to!string;
		else if ( value.type == typeid(bool))
			return value.get!bool.to!string;
		else if ( value.type == typeid(string))
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
	this (long a) { value = a ; repr = a.to!string; }
	this (long a, string b) { value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new Num(value.get!long, repr);}
}
class NumList : Num, List
{
	
	this() {}
	this (long[] a) { this(a, genRepr(a)); }
	this (long[] a, string b) { value = a.map!(it=>cast(ExprResult) new Num(it)).array; repr = b; }
	this (ExprResult[] a) { this(a, genRepr(a)); }
	this (ExprResult[] a, string b) { assert(a.all!(it=>it.isA!Num)) ; value = a; repr = b; }
	
	string genRepr(T)(T a)
	{
		static assert(isArray!T);
		return "["~a.map!(it=>it.to!string).join("+")~"]";
	}
	
	override ExprResult reduced() {
		return cast(ExprResult) new Num(value.get!(ExprResult[]).map!(it=>it.value.get!long).sum, repr);
	}
}

class NumRoll : NumList, Roll
{
	
	/++
	 + the maximum possible value of the corresponding roll
	 + used for explosions
	 +/
	long maxValue;
	
	this() {}
	this (long[] a, long max)
	{
		this(a, max, []);
	}
	this (ExprResult[] a, long max)
	{
		this(a, max, []);
	}
	this (long[] a, long max, ReprTree[] predecessor)
	{
		this(a.map!(it=>cast(ExprResult) new Num(it)).array, max, predecessor);
	}
	this (ExprResult[] a, long max, ReprTree[] predecessor)
	{
		maxValue = max;
		auto newRepr = ReprTree(genRepr(a));
		newRepr.isRoll=true;
		reprTree = ReprTree(predecessor~newRepr);
		value = a;
	}
}

class Bool : Num
{
	this() {}
	this (bool a) { value = a; repr = a?"T":"F";}
	this (bool a, string b) { value = a; repr = b; }
	override ExprResult reduced() {return cast(ExprResult) new Bool(value.get!bool, repr);}
}
class BoolList : Bool, List
{
	this() {}
	this (bool[] a) { this(a, genRepr(a)); }
	this (bool[] a, string b) { value = a.map!(it=>cast(ExprResult) new Bool(it)).array; repr = b; }
	this (ExprResult[] a) { this(a, genRepr(a)); }
	this (ExprResult[] a, string b) { assert(a.all!(it=>it.isA!Bool)) ; value = a; repr = b; }
	
	string genRepr(T)(T a)
	{
		static assert(isArray!T);
		return "["~a.map!(it=>it.to!string).join("+")~"]";
	}
	
	override ExprResult reduced() {
		auto l = value.get!(ExprResult[]);
		if (l.length == 1)
			return cast(ExprResult) new Bool(l[0].value.get!bool, repr);
		
		return cast(ExprResult) new Num(l.map!(it=>it.value.get!bool).sum, repr);
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
			return cast(ExprResult) new NumRoll(elements, maxValue);
		return cast(ExprResult) new NumList(elements);
	}
	if (elements.all!(it=>it.isA!String))
		return cast(ExprResult) new StringList(elements);
	return cast(ExprResult) new MixedList(elements);
}