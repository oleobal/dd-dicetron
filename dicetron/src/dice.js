import { spawnSync } from "child_process";

export class UserInputError extends Error {}

export function getHelp() {
  const p = spawnSync(process.env.DD_DICE_PATH, ["--help"]);
  if (p.status !== 0) throw new Error();
  return p.stdout.toString();
}

export function rollDice(expr) {
  const p = spawnSync(process.env.DD_DICE_PATH, ["--json", expr]);

  if (p.status !== 0) throw new Error();
  let r = JSON.parse(p.stdout);
  if (!r.successful) {
    throw new UserInputError(r.error);
  }
  return `\`${r.repr}\`: **${r.output}**`;
}
/*
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
*/
