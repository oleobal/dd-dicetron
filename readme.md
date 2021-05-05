# DD-Dicetron

DD-Dicetron is a (yet another) dice throwing bot for Discord.

I wrote it because I was frustrated with an available bot not having a
flexible enough syntax. And I wanted an excuse to try Dlang's Pegged library.

As it turns out, Dlang has, at the time of writing, no "solid" Discord libs.
Didn't want to debug one myself so I thought I'd just stick a Python server
in front of the D binary and ship it as a Docker container.

`dd-dice` has the D program that does the parsing and interpreting.

`dicetron` has the Python bindings to the libs that do the heavy lifting of
connecting to Discord

Together they are.. ***DD-Dicetron!***

## Development

Read [my notes about the language](/language.md).

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
 - that file is the only source

## Production usage

### As a standalone program

Not sure why anyone would but you _can_ use dd-dice on its own, on the terminal.

### As a Discord bot

Can be run as in development but it's probably best to run `./build` and get
a Docker image. Run it with `--env DD_DISCORD_API_TOKEN=<..>`.