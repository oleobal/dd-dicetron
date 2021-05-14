import json
import subprocess
import os

from . import util


def get_dice_help():
    p = subprocess.run([os.environ["DD_DICE_PATH"], "--help"], capture_output=True)
    if p.returncode == 0:
        return p.stdout.decode("utf-8")
    else:
        return "Error"


def roll_dice(expr:str, available_modules:dict, enabled_modules:list) -> tuple[bool, str]:
    modules_cmd=[]
    for m in enabled_modules:
        modules_cmd+=["--module", available_modules[m]["file"]]
    
    p = subprocess.run(
        [os.environ["DD_DICE_PATH"], "--json", expr]+modules_cmd, capture_output=True
    )
    if p.returncode == 0:
        result = json.loads(p.stdout.decode("utf-8"))
        if not result.get("successful", True):
            return (False, result.get("error", ""))
        repres = result.get("repr", "")
        if len(repres) > 100:
            repres = "[too long]"
        return (True, f"`{repres}`: **{result.get('output', '')}**")
    else:
        return (False, "Error")


def usage_help(global_prefix: str, prefixes: dict, guild_id=None) -> str:
    prefix = prefixes.get(guild_id, global_prefix)
    return (
        util.trim_indent(
            f"""
            Prefix all commands with `{prefix}` (eg `{prefix} 1d20`)
            ```
            """
        )
        + get_dice_help()
        + util.trim_indent(
            """
            
            Comments:                         2d4+1 # Great axe damage
            List last rolls:                  history
            Change prefix:                    prefix
            ``` _Source & doc at https://github.com/oleobal/dd-dicetron_
            """
        )
    )
