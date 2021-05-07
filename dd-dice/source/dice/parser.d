module dice.parser;

public import pegged.grammar;

mixin(grammar(`
DiceExpr:
	FullExpr   < Expr :EndOfInput
	Expr       < Comp / Term
	
	Comp       < Term (Eq / NEq / Inf / InfEq / Sup / SupEq)+
	
	Eq         < "==" Term
	NEq        < "!=" Term
	Inf        < "<"  Term
	InfEq      < "<=" Term
	Sup        < ">"  Term
	SupEq      < ">=" Term
	
	
	Term       < Factor (Add / Sub)*
	Add        < "+" Factor
	Sub        < "-" Factor
	Factor     < Primary (Mul / Div)*
	Mul        < "*" Primary
	Div        < "/" Primary
	Primary    < DotCall / FunCall / MulDie
	             / Parens / Not / Neg / Pos
	             / Die / PictDie / Coin / Number
	             / LambdaDef / Ident
	Parens     < "(" Expr ")"
	Not        < "!" Primary
	Neg        < "-" Primary
	Pos        < "+" Primary
	MulDie     < Primary (Die / PictDie / Coin)
	Die        < "d"i Number
	PictDie    < "d"i "[" UnqStr ("," UnqStr )* :(",")? "]"
	Coin       <- ( "coin"i / "true"i / "false"i ) :"s"?
	Number     <- ~([0-9]+)
	
	DotCall    < Primary "." Ident ( "(" ( Expr ("," Expr )* :(",")? )? ")" )?
	FunCall    < Ident "(" ( Expr ("," Expr )* :(",")? )? ")"
	LambdaDef  < Ident ("," Ident )* :(",")? "=>" Expr
	
	
	Ident      < identifier
	UnqStr     <~ String / [a-zA-Z0-9]+
	String     <~ :doublequote (!doublequote DQChar)* :doublequote / :quote (!quote SQChar)* :quote
	DQChar     <~ :backslash (doublequote / backslash) / .
	SQChar     <~ :backslash (quote / backslash) / .
	EndOfInput <- !.
`));


auto parse(string expr)
{
	return DiceExpr(expr);
}
