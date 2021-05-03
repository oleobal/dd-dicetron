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