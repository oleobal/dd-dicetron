import os
import json

def list_available_modules() -> dict:
    path = os.environ.get("DD_MODULES_PATH", "")
    if not path or not os.path.isdir(path):
        return {}
    
    modules = json.load(open(os.path.join(path, "module-list.json")))
    
    return modules
