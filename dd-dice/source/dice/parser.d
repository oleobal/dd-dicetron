module dice.parser;

public import pegged.grammar;

mixin(grammar(`
DiceExpr:
	Expr     < Comp / Term
	
	Comp     < Term (Eq / NEq / Inf / InfEq / Sup / SupEq)+
	
	Eq       < "==" Term
	NEq      < "!=" Term
	Inf      < "<"  Term
	InfEq    < "<=" Term
	Sup      < ">"  Term
	SupEq    < ">=" Term
	
	
	Term     < Factor (Add / Sub)*
	Add      < "+" Factor
	Sub      < "-" Factor
	Factor   < Primary (Mul / Div)*
	Mul      < "*" Primary
	Div      < "/" Primary
	Primary  < DotCall / FunCall / MulDie / Parens / Not / Neg / Pos / Die / Number 
	Parens   < "(" Expr ")"
	Not      < "!" Primary
	Neg      < "-" Primary
	Pos      < "+" Primary
	MulDie   < Primary Die
	Die      < "d" Number
	Number   < ~([0-9]+)
	
	DotCall  < Primary "." Variable ( "(" ( Expr ("," Expr )* )? ")" )?
	FunCall  < Variable "(" ( Expr ("," Expr )* )? ")"
	
	Variable < identifier
`));


auto parse(string expr)
{
	return DiceExpr(expr);
}
