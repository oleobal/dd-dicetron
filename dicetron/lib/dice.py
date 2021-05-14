import json
import subprocess
import os

from . import util


def get_help():
    p = subprocess.run([os.environ["DD_DICE_PATH"], "--help"], capture_output=True)
    if p.returncode == 0:
        return p.stdout.decode("utf-8")
    else:
        return "Error"


def roll_dice(
    expr: str, available_modules: dict, enabled_modules: list, explain=False
) -> tuple[bool, str]:
    modules_cmd = []
    for m in enabled_modules:
        modules_cmd += ["--module", available_modules[m]["file"]]
    
    additional_args=[]
    if explain:
        additional_args.append("--explain")
    
    p = subprocess.run(
        [os.environ["DD_DICE_PATH"], "--json", expr] + modules_cmd + additional_args,
        capture_output=True,
    )
    if p.returncode == 0:
        result = json.loads(p.stdout.decode("utf-8"))
        if not result.get("successful", True):
            return (False, result.get("error", ""))
        repres = result.get("repr", "")
        if not explain and len(repres) > 100:
            repres = "[too long]"
        if "\n" in repres:
            return (True, f"```\n{repres}\n``` **{result.get('output', '')}**")
        return (True, f"`{repres}`: **{result.get('output', '')}**")

    else:
        return (False, "Error")
