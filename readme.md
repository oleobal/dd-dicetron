# DD-Dicetron

DD-Dicetron is a (yet another) dice throwing bot for Discord.

I wrote it because I was frustrated with an available bot not having a
flexible enough syntax. And I wanted an excuse to try Dlang's Pegged library.

As it turns out, Dlang has, at the time of writing, no "solid" Discord libs.
Didn't want to debug one myself so I thought I'd just stick a Python server
in front of the D binary and ship it as a Docker container.

`dd-dice` has the D program that does the parsing and interpreting

`dicetron` has the Python bindings to the libs that do the heavy lifting of
connecting to Discord

Together they are.. ***DD-Dicetron!***

[Documentation here](/doc/)

## Features

### Dice expressions

Parsing of arbitrary comparisons, Python-style chaining
```
  $ dd-dice '20 <= 2d20+5 <= 35'
20<=[6+1]+5<=35: Failure
```
Filtering with function calls (and with UFCS, `f(x)` is equivalent to `x.f`)
```
  $ dd-dice '4d20.best(3).worst(2)'
[7+5+1+15].best(3).worst(2): 12
```
Some function use lambdas as predicates:
```
  $ dd-dice '4d20.filter(d=>d>10).map(it=>it+1d4)'
[2+19+9+16].filter(d => d>10).map(it => it+1d4): 42
```

Custom dice are supported instead of `d<number>`:
```
  $ dd-dice 'd[film, "board games"] + d["🍕", "🍔", "🥗"]'
[board games]+[🍔]: board games, 🍔
```

It attempts to tell you what your rolls were, but that gets complicated when
you feed results of a roll into another.


## Development

[Read the documentation](/doc/)

### DD-Dice

 - Install the D development suite (a D compiler + DUB)
 - `cd dd-dice`
 - `dub run -- '1d20'` runs the program
 - the source is in `source/`

### Dicetron

NodeJS application to handle connecting to Discord, based on https://github.com/discord/discord-example-app.

My usage is not advanced so I tried implementing it in vibe-d but D has no turnkey crypto library for verifying the calls from Discord.

You can test commands by running the server in dev mode:
```sh
DEV_MODE=true node src/app.js
```

.. and POSTing requests to it:
```sh
curl http://localhost:3000/interactions -H "Content-Type: application/json" --data '{"type": 2, "id": "0", "data": {"name": "roll", "options":[{"value": "3d4"}]}}'
```


To run the full discord app:
```sh
printf 'APP_ID=%s\nDISCORD_TOKEN=%s\nPUBLIC_KEY%s\n' YOUR_APP_ID YOUR_DISCORD_TOKEN YOUR_PUBLIC_KEY > .env
printf 'DD_DICE_PATH=%s\n' PATH_TO_DD_DICE_EXECUTABLE >> .env
npm run register
node src/app.js
```
