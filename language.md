# Expression language

There is a formal grammar in `dd-dice/source/dice.d` so I won't comment on it.
However I wrote the intepreter so here's a bit about how it works.

### Type system

There are currently two types:
 - integers (as `long`)
 - booleans

Ints represent the result of a roll and bools the result of a comparison.
However, bools are silently cast to ints when arithmetic is performed, to allow
for things like counting the number of successes.

I'm also planning on:
 - list of numbers
 - strings
 - list of strings

Lists of numbers are to represent a roll of multiple dice. At present, rolling
multiple dice gets you the addition immediately; I would like it to return
instead a list of numbers that is silently converted to a number by adding them
either when fed into arithmetic or it reaches the top node. The reason for this
is that some functions (like "roll 5 take the best 2") actually need the full
list of rolls.

We could conceivably have two types of lists of numbers, ones that are silently
reducibles and ones that aren't. But I think it would be very obscure to the
point of uselessness.

Strings would represent the result of rolling a dice with symbols or words on
its faces instead of numbers. List of strings for the same (and obviously they
can't be reducible). There would be a new syntax for this: `2d[head, tails]`

### Functions

The big one: what we need is obviously function composition.

Ideally either prefix (`abs(d10-7)` or infix `(d10-7).abs`)

The nice thing with function is that everything else can be rewritten as a 
special case of them.

### Arithmetic division

Division is currently implemented as `long/long` and therefore floors the result.
We'd need to sort that out somehow, because "divide, round up" is fairly common.

I'm not too keen on floats, I'd rather there'd be two types of division and each
returns an integer.