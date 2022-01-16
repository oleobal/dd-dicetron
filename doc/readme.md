# DD-Dicetron documentation

DD-Dicetron is split in two: `DD-Dice` processes dice expressions, while
`Dicetron` communicates with Discord.

## DD-Dice

### Ethos

DD-Dice is Turing-complete but is not general-purpose: the vast majority
of programs should be the result of a single expression and as concise
as possible.

### Basics

DD-Dice is meant to return the result of an _expression_.

In DDD's case, the simplest and most common expression will be a dice
roll: `3d6` rolls three six-sided dice.

The data produced by this dice roll can then be operated on by functions.
For instance, `best(3d6)` to the best roll of the three. This can also
be written `3d6.best`, which allows for writing complex expressions more
conveniently (`3d6.best(2).filter(roll=>roll>3).worst`).

You can separate expressions with `;`. The result of such a chain of
expressions is the result of its last expression.

### Rundown for people with experience in programming languages

DDD is a Lisp with fairly restrictive scope, though I think it has fairly strong
foundations (respect dynamic dispatch, proper scoping, etc). Performance is
poor.

It has no pointers and very few data types (basically string, int and arrays).
There is little in the way of loops in the language so recursion is the only
way to do a lot of things. Syntax is inconvenient for complex operations.

Cool features:
 - UFCS (`g(f(a,b),c)` equals `a.f(b).g(c)`)
 - Short lambda syntax (`range.map(x=>x+1)` equals `range.map{it+1}`)
 - Both functions and closures can be created and bound to a symbol at any time.
   Closures have access to the context of their creation, Functions do not.

It uses "d" as an operator (for dice rolls) which can be confusing.


### Built-in functions

See [builtins](builtins.md)

### Modules

Modules are DD-Dice's equivalent of libraries.

They are YAML files with functions defined as DD-Dice expressions inside.
They can be loaded with `--module` in the DD-Dice CLI and are defined in the
uppermost (global) context. There is no reference to them in the lanaguage
proper (eg no `import` keyword or similar).

[Example](/dd-dice/modules/cyberpunkred.yaml)

### Interpreter internals

See [interpreter](interpreter.md)



## Dicetron

At present Dicetron is built on `discord.py`, and doesn't use the slash commands
API. Changing that looks like a bore which is why I haven't done it.

Dicetron translates Discord messages into DD-Dice process calls. DD-Dice itself
is stateless, but Dicetron manages state on top:
 - per-channel, per-user history
 - per-channel enabled modules
 - per-server prefix (default `!dddt` but it can be rebound to, say, `!r`)