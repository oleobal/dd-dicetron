from . import modules as mod
from . import prefixes as prf
from . import dice
from . import util


def set_guild_prefix(context, guild: int, prefix: str):
    context.prefixes[guild] = prefix
    prf.save_prefixes(context.prefixes, for_guild=guild)


def enable_module(context, guild: int, module_id: str):
    if guild in context.modules:
        context.modules[guild].append(module_id)
    else:
        modules[guild] = [module_id]
    mod.save_modules(context.modules, for_guild=guild)


def disable_module(context, guild: int, module_id: str):
    if guild in context.modules:
        context.modules[guild].remove(module_id)
    mod.save_modules(context.modules, for_guild=guild)


def cmd_help(context, command, prefix, author, channel, guild) -> str:
    return (
        util.trim_indent(
            f"""
            Prefix all commands with `{prefix}` (eg `{prefix} 1d20`)
            ```
            """
        )
        + dice.get_help()
        + util.trim_indent(
            """
            
            Comments:                         2d4+1 # Great axe damage
            Replay rolls:                     history
            Change prefix:                    prefix
            Enable modules:                   module
            Explain a roll:                   explain d10d10d10
            ``` _Source & doc at https://github.com/oleobal/dd-dicetron_
            """
        )
    )


def cmd_prefix(context, command, prefix, author, channel, guild) -> str:
    if not guild:
        return
    words = command.strip().casefold().split()
    if len(words) == 0:
        if guild.id in context.prefixes:
            return f"The current prefix on this server is `{prefix}`. Set it with `{prefix} prefix <prefix>`"
        else:
            return f"No custom prefix on this server. Set it with `{prefix} prefix <prefix>`"
    set_guild_prefix(guild.id, words[0])
    return f"Prefix updated to `{words[0]}`"


def cmd_module(context, command, prefix, author, channel, guild) -> str:
    words = command.strip().casefold().split()
    if len(words) == 0:
        if len(context.available_modules) == 0:
            return "No modules available for this server"
        row = "{:<2} {:<10} {}\n"
        msg = row.format("On", "ID", "Name")
        for i, m in context.available_modules.items():
            msg += row.format(
                "✓"
                if (guild.id in context.modules and i in context.modules[guild.id])
                else "",
                i,
                m["name"],
            )
        return (
            "Available modules:\n```"
            + msg
            + f"``` Use one with `{prefix} module enable <id>`"
        )

    elif len(words) == 2:
        if words[0] not in context.available_modules:
            return "Unknown module: " + words[1]
        if words[0] == "enable":
            enable_module(guild.id, words[1])
            return "Module enabled: " + context.available_modules[words[1]]["name"]
        elif words[0] == "disable":
            try:
                disable_module(guild.id, words[1])
                return "Module disabled: " + context.available_modules[words[1]]["name"]
            except ValueError:
                return (
                    "Module wasn't enabled: "
                    + context.available_modules[words[1]]["name"],
                )
        else:
            return "Unknown command: " + " ".join(words)
    return "Unknown command: " + " ".join(words)


def cmd_history(context, command, prefix, author, channel, guild) -> str:
    author_id = b"%x%x" % (author.id, channel.id)
    if h := context.history.get_pretty_history(author_id):
        return f"History for {author.display_name}:\n```\n{h}\n```_(`{prefix} !!` or `{prefix} !<index>` to use)_"
    return f"You have no rolling history on this channel"
