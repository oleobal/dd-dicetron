# Expression language

There is a [formal grammar](/dd-dice/source/dice/parser.d) so I won't comment on it.
However I wrote the intepreter so here's a bit about how it works.

## Dice rolling rules


 - `0dy` returns `0`
 - `xd0` returns a list of `x` zeroes
 - `xd1` returns a list of `x` ones
 - `xdy` returns `x` rolls of a `y`-sided die
 - `xfalse(s?)` returns a list of `x` falses
 - `xtrue(s?)` returns a list of `x` trues
 - `xcoin(s?)` return a list of `x` random booleans (coin flips)

_Where `x` and `y` are two non-negative integers._ (the grammar is supposed not to allow it)

### Custom dice

`[x,x,x,...]` generates a custom die

It is a list of any expressions, each only evaluated once regardless of how many
times the dice is rolled.


## Type system

There are currently:
 - `ExprResult`, the root of the type hierarchy (abstract, can't exist)
 - `Num`, integers (as `long`)
 - `Bool`, booleans (`true` and `false` in the code, but `Success` and `Failure` in the output)
 - `String`
 - and corresponding lists:
   - `MixedList` which don't provide any guarantee as to what they contain
   - `NumList` which has a `maxValue` (see corresponding section)
     - `NumRoll` which represent a "natural" roll (see corresponding section)
   - `BoolList`
   - `StringList`
   - `List` is used to mean "any of these" (abstract, can't exist)

### Lists & ints

Lists represent the result of a roll:
 - booleans for coin flips
 - integers for dice

Rolls are "reduced" to the sum of their parts when subject to arithmetic or
comparisons (a roll of 1 bool is reduced to that bool).
Also a roll of 0 dice returns `0`, not `[0]`.

The reason for preserving the rolls is that some functions
(like "roll 5 take the best 2") actually need the full list of rolls.

We could conceivably have two types of lists of numbers, ones that are silently
reducibles and ones that aren't. But I think it would be very obscure to the
point of uselessness.

#### NumList & NumRoll

`NumRoll` is simply a `NumList` with a different constructor, which represents
the result of a `xdy` expression (or a numeric custom die).

For features such as exploding dice, it is necessary to store the maximum possible
value of a roll along with the resulting list. This property is called `maxValue`.

I have been ping-ponging between giving this property to `NumRoll` or `NumList`.
Basically the reason `NumRoll` exists is to give them a special constructor that
makes it easier to give them a pretty Repr; this comes with a few assertions
like "there are always two inputs to a NumRoll (number & size of dice)", which
are not true anymore if the roll is fed to a function.

Ultimately I gave the property to `NumList`, so `NumRoll` solely represents the
direct result of a numeric dice roll and is replaced with a `NumList` when fed
to a function.

#### Empty lists

`filter` can create empty lists. No policy on them yet.

Empty lists evaluate to 0, which I think is OK,
although `[]` would be fine too or better.

As I'm writing this I don't actually understand _why_ empty lists (including
the StringList ones) evaluate to 0, but that's OK.

### Bools

Bools are also the result of a comparison, or a coin flip.
(`true` and `false` are special coin flips)

Bools are silently cast to ints when arithmetic is performed,
to allow for things like counting the number of successes.


### Strings

Represent "Picture Dice", with symbols or words on their faces instead of numbers.
Can't be reduced.

Concatenation of strings make no sense (who concatenates DICE?). Concatenating
lists of dice however does, and we can use the `+` operator.

Question however: should lists of number dice be reduced beforehand? Right now,
they are.

#### Unquoted strings

Identifiers with no match in context are treated as strings. 
Dangerous but convenient for custom dice.

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

### Lambdas

Lambdas (anonymous function definitions) are of the form `a => a+1`.

There's no way to call them beyond passing them as argument to a function that
takes one as input, like `map` or `filter`. 

There is a special syntax if:
 - You're using the Dot call form (`x.f` and not `f(x)`)
 - There are only two arguments, the list and the lambda

Then you can replace `2d20.map(x=>x+1)` with `2d20.map{it+1}`.
(`it` is the default argument name)


### Supplied functions

See [functions](functions.md)

## Arithmetic division

Division is currently implemented as `long/long` and therefore floors the result.
We'd need to sort that out somehow, because "divide, round up" is fairly common.

I'm not too keen on floats, I'd rather there'd be two types of division and each
returns an integer.

## Repr

The `ExprResult` class has a `repr` field which is supposedly to help the user
understand what happened in the interpreter (specifically, what their rolls were).

It is basically a tree that is silently converted to a string when called upon,
which enables most of the old code that expects a string to work still.