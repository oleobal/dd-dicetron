# Expression language

There is a formal grammar in `dd-dice/source/dice/parser.d` so I won't comment on it.
However I wrote the intepreter so here's a bit about how it works.

## Dice rolling rules


 - `0dy` returns `0`
 - `xd0` returns a list of `x` failures
 - `xd1` returns a list of `x` successes
 - `xd2` return a list of `x` random booleans (coin flips)
 - `xdy` returns `x` rolls of a `y`-sided die

_Where `x` and `y` are two non-negative integers._ (the grammar is supposed not to allow it)


## Type system

There are currently six types:
 - integers (as `long`)
 - booleans (`true` and `false` in the code, but `Success` and `Failure` in the output)
 - strings
 - list of integers
 - list of bools
 - list of strings

### Lists & ints

Lists represent the result of a roll:
 - booleans for d0, d1, d2
 - integers for anything else

Rolls are "reduced" to the sum of their parts when subject to arithmetic or
comparisons (a roll of 1 bool is reduced to that bool).
Also a roll of 0 dice returns `0`, not `[0]`.

The reason for preserving the rolls is that some functions
(like "roll 5 take the best 2") actually need the full list of rolls.

We could conceivably have two types of lists of numbers, ones that are silently
reducibles and ones that aren't. But I think it would be very obscure to the
point of uselessness.

### Bools

Bools are also the result of a comparison.

Bools are silently cast to ints when arithmetic is performed:
 - to allow silent arithmetic between coin flips (d2) and other dice
 - to allow for things like counting the number of successes.

### Strings

I'm also planning on:
 - strings
 - list of strings

Represent "Picture Dice", with symbols or words on their faces instead of numbers.
Can't be reduced.

Concatenation of strings make no sense (who concatenates DICE?). Concatenating
lists of dice however does, and we can use the `+` operator.

Question however: should lists of number dice be reduced beforehand? Right now,
they are.



## Functions

Two kind of function calls:
 - `FunCall` is prefix
 - `DotCall` is infix

There's a primitive kind of UFCS in that both are valid, but it's not in the
syntax, the interpreter does it. Functions themselves are written in D and have
to validate their input themselves. The whole thing is a bit messy but it works
well externally so I don't expect to actually clean it up ever.

The nice thing with functions is that everything else can be rewritten as a 
special case of them. `5d2` or `3*4` are just infix calls to the `d` and `*`
functions after all. I might do it later so all functions live in their own
little world (OK, it's unlikely to happen).

## Arithmetic division

Division is currently implemented as `long/long` and therefore floors the result.
We'd need to sort that out somehow, because "divide, round up" is fairly common.

I'm not too keen on floats, I'd rather there'd be two types of division and each
returns an integer.