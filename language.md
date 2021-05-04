# Expression language

There is a formal grammar in `dd-dice/source/dice.d` so I won't comment on it.
However I wrote the intepreter so here's a bit about how it works.

## Dice rolling rules


 - `0dy` returns `0`
 - `xd0` returns a list of `x` failures
 - `xd1` returns a list of `x` successes
 - `xd2` return a list of `x` random booleans (coin flips)
 - `xdy` returns `x` rolls of a `y`-sided die

_Where `x` and `y` are two non-negative integers._ (the grammar is supposed not to allow it)


## Type system

There are currently four types:
 - integers (as `long`)
 - booleans (`true` and `false` in the code, but `Success` and `Failure` in the output)
 - list of integers
 - list of bools

### Lists & ints

Lists represent the result of a roll:
 - booleans for d0, d1, d2
 - integers for anything else

Rolls are "reduced" to the sum of their parts when subject to arithmetic or
comparisons (a roll of 1 bool is reduced to that bool).
Also a roll of 0 dice returns `0`, not `[0]`.

The reason for preserving the rolls is that some planned functions
(like "roll 5 take the best 2") actually need the full list of rolls.

We could conceivably have two types of lists of numbers, ones that are silently
reducibles and ones that aren't. But I think it would be very obscure to the
point of uselessness.

### Bools

Bools are also the result of a comparison.

Bools are silently cast to ints when arithmetic is performed:
 - to allow silent arithmetic between coin flips (d2) and other dice
 - to allow for things like counting the number of successes.

### Planned

I'm also planning on:
 - strings
 - list of strings


Strings would represent the result of rolling a dice with symbols or words on
its faces instead of numbers. List of strings for the same (and obviously they
can't be reducible). There would be a new syntax for this: `2d[head, tails]`

## Functions

The big one: what we need is obviously function composition.

Ideally either prefix (`abs(d10-7)` or infix `(d10-7).abs`)

The nice thing with function is that everything else can be rewritten as a 
special case of them.

## Arithmetic division

Division is currently implemented as `long/long` and therefore floors the result.
We'd need to sort that out somehow, because "divide, round up" is fairly common.

I'm not too keen on floats, I'd rather there'd be two types of division and each
returns an integer.