import os
import json

from . import data


def get_available_modules() -> dict:
    path = os.environ.get("DD_MODULES_PATH", "")
    if not path or not os.path.isdir(path):
        return {}

    modules = json.load(open(os.path.join(path, "modules.json")))
    for k in modules:
        fullpath = os.path.join(path, modules[k]["file"])
        assert(os.path.exists(fullpath))
        modules[k]["file"] = fullpath

    return modules


def load_modules(for_guild=None) -> dict:
    path = os.path.join(data.get_data_dir(), "modules")
    if not os.path.isdir(path):
        return {}
    modules = {}

    if for_guild:
        files = [os.path.join(path, ("%x" % for_guild) + ".json")]
        if not os.path.exists(files[0]):
            return {}
    else:
        _, _, files = next(os.walk(path))

    for name in files:
        if name.endswith(".json"):
            p = os.path.join(path, name)
            with open(p) as f:
                try:
                    t = json.load(f)
                    modules[int(name[: -len(".json")], base=16)] = t
                except JSONDecodeError as e:
                    print(f"Error decoding {p}: {e}")
                    pass
    return modules


def save_modules(modules: dict, for_guild=None):
    path = os.path.join(data.get_data_dir(), "modules")
    if not os.path.isdir(path):
        os.makedirs(path, exist_ok=True)
    if for_guild and for_guild in modules:
        with open(os.path.join(path, ("%x" % for_guild) + ".json"), "w") as f:
            json.dump(modules[for_guild], f)
    else:
        for k, v in modules:
            with open(os.path.join(path, ("%x" % k) + ".json"), "w") as f:
                json.dump(v, f)
