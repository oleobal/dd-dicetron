import os
import json

from . import data

def load_prefixes() -> dict:
    path = os.path.join(data.get_data_dir(), "prefixes")
    if not os.path.isdir(path):
        return {}
    prefixes = {}
    _, _, files = next(os.walk(path))
    for name in files:
        if name.endswith(".json"):
            p = os.path.join(path, name)
            with open(p) as f:
                try:
                    t = json.load(f)
                    prefixes[int(name[: -len(".json")], base=16)] = t["prefix"]
                except JSONDecodeError as e:
                    print(f"Error decoding {p}: {e}")
                    pass
    return prefixes


def save_prefixes(prefixes: dict, only=None):
    path = os.path.join(data.get_data_dir(), "prefixes")
    if not os.path.isdir(path):
        os.makedirs(path, exist_ok=True)
    if only and only in prefixes:
        with open(os.path.join(path, ("%x" % only) + ".json"), "w") as f:
            json.dump({"prefix": prefixes[only]}, f)
    else:
        for k, v in prefixes:
            with open(os.path.join(path, ("%x" % k) + ".json"), "w") as f:
                json.dump({"prefix": v}, f)
