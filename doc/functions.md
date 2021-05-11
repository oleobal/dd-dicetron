## Supplied functions

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


### List manipulation


#### map

`List map(Function, List)`

Return the list with the function applied to each element

**Example:** `2d20.map(x=>x+10)` yields `[3+2].map(x => x+10): 25`

#### filter

`List filter(Function, List)`

Return the list, but with only elements for which the function returns `true`.
This can return an empty list.

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