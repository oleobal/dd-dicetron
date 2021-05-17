## Built-in functions

These functions are built in the interpeter and always available.

As a reminder, `f(x,y)` is equivalent to `x.f(y)`. In the second case, you don't
need to write the parentheses if there's nothing in them.


### Dice rolling

#### best, worst

`NumList best(NumList, Num nbToTake=1)`

`NumList worst(NumList, Num nbToTake=1)`

Return the `nbToTake` best or worst elements of the list.
`nbToTake` is optional and defaults to 1.

**Example:** `3d20.best(2).worst` yields `[7+12+19].best(2).worst: 12`

As a side of effect of implementation, the output is sorted, but there is no
guarantee of that.

#### explode

`NumList explode(NumList)`

`BoolList explode(BoolList)`

Roll an additional die for every die in the input list with the maximum possible
value, and do the same for those new dice too.

On `NumList`, this function requires a property called `maxValue` to be set,
which indicates what is the maximum possible size of an element. This property
is set by the dice rolling functions, but is stripped by arithmetic and many
other functions.


### List manipulation


#### map

`List map(Function, List)`

Return the list with the function applied to each element

**Example:** `2d20.map(x=>x+10)` yields `[3+2].map(x => x+10): 25`

#### filter

`List filter(Function, List)`

Return the list, but with only elements for which the function returns `true`.
This can return an empty list.

#### any & all

`Bool any(List, Function)`

Returns `true` if `Function` returns `true` for all elements in `List`

`Bool all(List, Function)`

Returns `true` if `Function` returns `true` for at least one element in `List`

Both return `false` if the list is empty.

### Plumbing

You probably won't need these.

#### min, max

`Num max(Num, Num,...)`

`Num min(Num, Num,...)`

Return the highest or lowest element of those supplied.

If you want the highest or lowest element **of a list** (eg the result of a
dice roll) use `best` or `worst`.

#### get

`ExprResult get(List, Num index)`

Get the element at the given index (0-indexed). If the index is negative, count
from the end of the list.

`List get(List, Num start, Num end)`

Same but returns a sub-list. For instance `[1,2,3,4].get(1,3)` returns `[2,3]`.

#### sort, rsort

`List sort(List)`

Return a the list sorted, smallest element first in the case of `sort` and the
reverse for `rsort`.


#### case

`ExprResult case(ExprResult, [List, ExprResult]..., ExprResult)`

Maybe handier with an example:
```
1d20.case(
	[[1..10], 1],
	[[11,13,15], 2],
	3
)
```
This returns `1` if the roll is from 1 to 10, `2` if the roll is 11, 13, or 15, 
and else 3.


#### def

`ExprResult def(String, ExprResult)`

Define the identifier `String` as the value `ExprResult`.