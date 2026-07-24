import json
import os
import secrets
import time


def _runtime_path() -> str | None:
    try:
        local_app_data = os.environ["LOCALAPPDATA"]
    except KeyError:
        return None
    zabmin_dir = os.path.join(local_app_data, "Zabmin")
    os.makedirs(zabmin_dir, exist_ok=True)
    return os.path.join(zabmin_dir, "runtime.json")


def generate_token() -> str:
    return secrets.token_urlsafe(32)


def write_runtime(pid: int, port: int, token: str) -> None:
    path = _runtime_path()
    if path is None:
        raise RuntimeError("LOCALAPPDATA is not set; cannot write runtime.json")
    tmp_path = path + ".tmp"
    data = {
        "pid": pid,
        "port": port,
        "token": token,
        "started_at": int(time.time()),
    }
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp_path, path)


def cleanup_runtime() -> None:
    path = _runtime_path()
    if path is None:
        return
    try:
        os.remove(path)
    except FileNotFoundError:
        pass
    except OSError:
        pass
