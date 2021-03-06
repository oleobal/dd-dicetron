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

### Discord features

These are on top of the features from `dd-dice`:

 - comments
 - per-user per-channel history of recent commands
 - persistent per-server prefix change.
 - persistent per-server module management


## Development

[Read the documentation](/doc/)

### DD-Dice

 - Install the D development suite (a D compiler + DUB)
 - `cd dd-dice`
 - `dub run -- '1d20'` runs the program
 - the source is in `source/`

### Dicetron

 - Install Python 3
 - `cd dicetron`
 - `./set-up` and follow the instructions
 - `export` these variable:
   - `DD_DICE_PATH` to the dd-dice executable
   - `DD_DISCORD_API_TOKEN` to your API key
 - `./dicetron` runs the program
 - the rest of the source is in `lib/`

## Production usage

### As a standalone program

Not sure why anyone would but you _can_ use dd-dice on its own, on the terminal.

### As a Discord bot

Can be run as in development but it's probably best to run `./build` and get
[a Docker image](https://hub.docker.com/r/oleobal/dd-dicetron).
Set your API token when running: `docker run --env DD_DISCORD_API_TOKEN='<..>' oleobal/dd-dicetron`

For persistence, set the `DD_DATA_DIR` variable and mount a volume or bind mount
a folder there.

Also of interest, `DD_MODULES_PATH` tells Dicetron where to look for available
modules. However, the image is packaged with a few by default already.

Example docker-compose configuration:
```yaml
services:
  dd-dicetron:
    image: "oleobal/dd-dicetron"
    environment:
      - 'DD_DISCORD_API_TOKEN=<your token>'
      - 'DD_DATA_DIR=/dd-data'
    volumes:
      - 'dd-data:/dd-data'
volumes:
  dd-data: {}
```