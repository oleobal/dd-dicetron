import os


def get_data_dir():
    path = os.environ.get("DD_DATA_DIR", "")
    if not path:
        path = os.path.join(os.path.dirname(__file__), ".dd-data")
    if not os.path.isdir(path):
        os.makedirs(path, exist_ok=True)
    return path

