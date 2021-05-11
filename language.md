# Expression language

There is a formal grammar in `dd-dice/source/dice/parser.d` so I won't comment on it.
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
   - `NumList`
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

#### best/worst

`NumList best(NumList, Num nbToTake=1)`

`NumList worst(NumList, Num nbToTake=1)`

Return the `nbToTake` best or worst elements of the list.
`nbToTake` is optional and defaults to 1.

As a side of effect of implementation, the output is sorted, but there is no
guarantee of that.

#### min/max

`Num max(Num, Num,...)`

`Num min(Num, Num,...)`

Return the highest or lowest element of those supplied.

If you want the highest or lowest element **of a list** (eg the result of a
dice roll) use `best` or `worst`.

#### map

`List map(Function, List)`

Return the list with the function applied to each element

#### filter

`List filter(Function, List)`

Return the list, but with only elements for which the function returns `true`.
This can return an empty list.

#### get

`ExprResult get(List, Num index)`

Get the element at the given index (0-indexed). If the index is negative, count
from the end of the list.

#### sort/rsort

`List sort(List)`

Return a the list sorted, smallest element first in the case of `sort` and the
reverse for `rsort`.

## Arithmetic division

Division is currently implemented as `long/long` and therefore floors the result.
We'd need to sort that out somehow, because "divide, round up" is fairly common.

I'm not too keen on floats, I'd rather there'd be two types of division and each
returns an integer.

## Repr

The `ExprResult` class has a `repr` field which is supposedly to help the user
understand what happened in the interpreter (specifically, what their rolls were).

It immediatly gets derailed when a roll of dice gets used to parametrize another.

For example:
 - `2d20.map(d=>d+1d4)` giving `[10+6].map(d => d+1d4): 22`
 - `(1d4)d20` giving `[7+10+11]: 28`

In both cases we lose the immediate result of dice.
I'm not sure what the ideal display would be in these cases. I'm thinking of
splitting it into multiple lines:
 - `2d20.map(d=>d+1d4)`
   ```
   [10+6].map(d => d+1d4)
    -> 10+[4]
    -> 6+[2]
   ```
 - `(1d4)d20`
   ```
   [3]d20
    -> [7+10+11]
   28
   ```

No idea how I'd achieve like that precisely. Must think about it more.